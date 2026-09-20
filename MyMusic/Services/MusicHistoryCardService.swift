import Foundation

enum MusicHistoryCardType: String, CaseIterable, Sendable {
    case yearAgo, monthTrack, newTrack, newArtist, rediscovered, longTerm
    case recurring, night, shuffleDiscovery, busiestDay, monthSound, monthAlbum
}

struct MusicHistoryCardCandidate: Identifiable, Sendable {
    let type: MusicHistoryCardType
    let title: String
    let subtitle: String
    let priority: Int
    let score: Double
    /// Artwork and copy remain tied to one representative track.
    let tracks: [Track]
    /// Ordered candidates. Resolve against the current library at playback time.
    let playbackTrackIDs: [Track.ID]
    let artistNames: [String]
    let albumTitle: String?
    let date: Date?
    let validUntil: Date

    var id: String { "\(type.rawValue)-\(tracks.first?.id.uuidString ?? title)" }
    var mainTrack: Track? { tracks.first }
}

/// Read-only, per-refresh index. All date buckets use the caller's calendar.
final class MusicHistoryCardService {
    private let playbackCandidateLimit = 30
    private struct Entry {
        let track: Track
        let event: PlaybackEvent
    }

    private struct Index {
        var byTrack: [Track.ID: [Entry]] = [:]
        var byArtist: [String: [Entry]] = [:]
        var byDay: [Date: [Entry]] = [:]
        var byMonth: [Date: [Entry]] = [:]
    }

    func makeCards(
        tracks: [Track],
        historyEntries: [Track.ID: PlaybackHistory],
        preferences: [Track.ID: TrackPreference],
        features: [Track.ID: TrackFeature] = [:],
        now: Date = Date(),
        calendar: Calendar = .current,
        limit: Int = 8
    ) -> [MusicHistoryCardCandidate] {
        let available = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        var index = Index()
        for history in historyEntries.values {
            guard let track = available[history.trackID] else { continue }
            for event in history.playbackEvents where event.endedAt <= now {
                let entry = Entry(track: track, event: event)
                let day = calendar.startOfDay(for: event.endedAt)
                let month = calendar.date(from: calendar.dateComponents([.year, .month], from: day)) ?? day
                index.byTrack[track.id, default: []].append(entry)
                index.byArtist[track.artistName, default: []].append(entry)
                index.byDay[day, default: []].append(entry)
                index.byMonth[month, default: []].append(entry)
            }
        }
        guard !index.byTrack.isEmpty else { return [] }
        let today = calendar.startOfDay(for: now)
        let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today
        let nextDay = calendar.date(byAdding: .day, value: 1, to: today) ?? now
        let nextMonth = calendar.date(byAdding: .month, value: 1, to: monthStart) ?? nextDay
        let monthEntries = index.byMonth[monthStart] ?? []
        var candidates: [MusicHistoryCardCandidate] = []
        candidates += yearAgo(index, today: today, nextDay: nextDay, calendar: calendar)
        candidates += monthTrack(monthEntries, nextMonth: nextMonth, calendar: calendar)
        candidates += newTracks(index, monthEntries: monthEntries, monthStart: monthStart, nextMonth: nextMonth, preferences: preferences)
        candidates += newArtists(index, monthEntries: monthEntries, monthStart: monthStart, nextMonth: nextMonth)
        candidates += rediscovered(index, today: today, nextDay: nextDay, calendar: calendar)
        candidates += longTerm(index, today: today, nextDay: nextDay, calendar: calendar)
        candidates += recurring(index, today: today, nextDay: nextDay, calendar: calendar)
        candidates += night(index, nextDay: nextDay, calendar: calendar)
        candidates += shuffleDiscovery(index, preferences: preferences, nextDay: nextDay)
        candidates += busiestDay(index, today: today, nextDay: nextDay, calendar: calendar)
        candidates += monthSound(monthEntries, tracks: tracks, features: features, nextMonth: nextMonth)
        candidates += monthAlbum(monthEntries: monthEntries, tracks: tracks, nextMonth: nextMonth)
        return select(candidates, limit: limit)
    }

    private func card(_ type: MusicHistoryCardType, _ title: String, _ subtitle: String,
                      _ track: Track, priority: Int, score: Double, until: Date,
                      tracks: [Track]? = nil, playbackTracks: [Track] = [],
                      artistNames: [String] = [], album: String? = nil,
                      date: Date? = nil) -> MusicHistoryCardCandidate {
        var seen: Set<Track.ID> = [track.id]
        var playbackTrackIDs = [track.id]
        for candidate in playbackTracks {
            if playbackTrackIDs.count == playbackCandidateLimit { break }
            if seen.insert(candidate.id).inserted { playbackTrackIDs.append(candidate.id) }
        }
        return MusicHistoryCardCandidate(type: type, title: title, subtitle: subtitle,
                                  priority: priority, score: score, tracks: tracks ?? [track],
                                  playbackTrackIDs: playbackTrackIDs, artistNames: artistNames, albumTitle: album, date: date,
                                  validUntil: until)
    }

    /// The same source and ordering are used by every Music History card playback.
    static let playbackStartContext = PlaybackStartContext(kind: .manual, source: .history)

    func tracksForPlayback(
        _ card: MusicHistoryCardCandidate,
        availableTracks: [Track],
        isPlayable: (Track) -> Bool
    ) -> [Track] {
        let available = Dictionary(uniqueKeysWithValues: availableTracks.map { ($0.id, $0) })
        var seen: Set<Track.ID> = []
        var resolved: [Track] = []
        for id in card.playbackTrackIDs {
            guard seen.insert(id).inserted, let track = available[id], isPlayable(track) else { continue }
            resolved.append(track)
            if resolved.count == 10 { break }
        }
        return resolved
    }

    private func withSharedQueue(_ candidates: [MusicHistoryCardCandidate]) -> [MusicHistoryCardCandidate] {
        let ranked = candidates.sorted {
            $0.score == $1.score ? $0.id < $1.id : $0.score > $1.score
        }.compactMap(\.mainTrack).prefix(playbackCandidateLimit).map { $0 }
        return candidates.map { candidate in
            var seen: Set<Track.ID> = []
            let ids = ([candidate.mainTrack].compactMap { $0 } + ranked).compactMap { track in
                seen.insert(track.id).inserted ? track.id : nil
            }.prefix(playbackCandidateLimit).map { $0 }
            return MusicHistoryCardCandidate(
                type: candidate.type, title: candidate.title, subtitle: candidate.subtitle,
                priority: candidate.priority, score: candidate.score, tracks: candidate.tracks,
                playbackTrackIDs: ids, artistNames: candidate.artistNames,
                albumTitle: candidate.albumTitle, date: candidate.date, validUntil: candidate.validUntil
            )
        }
    }

    private func rankedTracks(_ entries: [Entry]) -> [(track: Track, count: Int)] {
        Dictionary(grouping: entries, by: { $0.track.id }).values.compactMap { group in
            group.first.map { (track: $0.track, count: group.count) }
        }.sorted { $0.count == $1.count ? $0.track.id.uuidString < $1.track.id.uuidString : $0.count > $1.count }
    }

    private func yearAgo(_ index: Index, today: Date, nextDay: Date, calendar: Calendar) -> [MusicHistoryCardCandidate] {
        guard let target = calendar.date(byAdding: .year, value: -1, to: today) else { return [] }
        let rings = [[0], [-1, 1], [-2, 2, -3, 3]]
        let rankedByRing = rings.map { offsets in
            rankedTracks(offsets.compactMap { calendar.date(byAdding: .day, value: $0, to: target) }
                .flatMap { index.byDay[$0] ?? [] })
        }
        guard let first = rankedByRing.firstIndex(where: { !$0.isEmpty }),
              let top = rankedByRing[first].first else { return [] }
        var seen: Set<Track.ID> = []
        let playbackTracks = rankedByRing.flatMap { $0.map(\.track) }.filter { seen.insert($0.id).inserted }
        let subtitle = first == 0 ? "ちょうど1年前に聴いていた曲" : "1年前のこの頃に聴いていた曲"
        return [card(.yearAgo, "1年前の今日", subtitle, top.track, priority: 100,
                     score: Double(top.count) - Double(first), until: nextDay,
                     tracks: Array(playbackTracks.prefix(3)), playbackTracks: playbackTracks, date: target)]
    }

    private func monthTrack(_ entries: [Entry], nextMonth: Date, calendar: Calendar) -> [MusicHistoryCardCandidate] {
        guard let top = rankedTracks(entries).first, top.count >= 2 else { return [] }
        let month = calendar.component(.month, from: entries[0].event.endedAt)
        return [card(.monthTrack, "\(month)月の1曲", "今月いちばん聴いている曲・\(top.count)回", top.track,
                     priority: 80, score: Double(top.count), until: nextMonth,
                     playbackTracks: rankedTracks(entries).map(\.track))]
    }

    private func newTracks(_ index: Index, monthEntries: [Entry], monthStart: Date, nextMonth: Date,
                           preferences: [Track.ID: TrackPreference]) -> [MusicHistoryCardCandidate] {
        let eligible = rankedTracks(monthEntries).filter { item in
            guard let first = index.byTrack[item.track.id]?.map(\.event.endedAt).min(), first >= monthStart,
                  item.count >= 2 || preferences[item.track.id]?.favorite == true || (preferences[item.track.id]?.playbackPreference ?? 0) > 0
            else { return false }
            return true
        }
        return eligible.prefix(8).map { item in
            return card(.newTrack, "今月の新しい出会い", "今月初めて聴き、また戻ってきた曲", item.track,
                        priority: 72, score: Double(item.count), until: nextMonth,
                        playbackTracks: eligible.map(\.track))
        }
    }

    private func newArtists(_ index: Index, monthEntries: [Entry], monthStart: Date, nextMonth: Date) -> [MusicHistoryCardCandidate] {
        Dictionary(grouping: monthEntries, by: { $0.track.artistName }).compactMap { name, entries -> [MusicHistoryCardCandidate]? in
            guard let first = index.byArtist[name]?.map(\.event.endedAt).min(), first >= monthStart,
                  entries.count >= 3, Set(entries.map(\.track.id)).count >= 2 else { return nil }
            let unique = Set(entries.map(\.track.id)).count
            let ranked = rankedTracks(entries)
            return ranked.prefix(4).enumerated().map { offset, item in
                card(.newArtist, "今月出会ったアーティスト", "\(name)の\(unique)曲を今月聴いています", item.track,
                        priority: 68, score: Double(entries.count + unique * 2) - Double(offset) * 0.01, until: nextMonth,
                        playbackTracks: ranked.map(\.track), artistNames: [name])
            }
        }.flatMap { $0 }
    }

    private func rediscovered(_ index: Index, today: Date, nextDay: Date, calendar: Calendar) -> [MusicHistoryCardCandidate] {
        let candidates = index.byTrack.values.compactMap { entries -> MusicHistoryCardCandidate? in
            let dates = entries.map(\.event.endedAt).sorted()
            guard dates.count >= 5, let last = dates.last,
                  let recentStart = calendar.date(byAdding: .day, value: -30, to: today), last >= recentStart,
                  let recentIndex = dates.firstIndex(where: { $0 >= recentStart }), recentIndex >= 3
            else { return nil }
            let previous = dates[recentIndex - 1]
            let gap = calendar.dateComponents([.day], from: previous, to: dates[recentIndex]).day ?? 0
            guard gap >= 60, entries.first != nil else { return nil }
            return card(.rediscovered, "また戻ってきた曲", "\(gap)日ぶりに再生しました", entries[0].track,
                        priority: 92, score: Double(gap) / 30 + Double(recentIndex), until: nextDay)
        }
        return withSharedQueue(candidates)
    }

    private func longTerm(_ index: Index, today: Date, nextDay: Date, calendar: Calendar) -> [MusicHistoryCardCandidate] {
        let candidates = index.byTrack.values.compactMap { entries -> MusicHistoryCardCandidate? in
            let dates = entries.map(\.event.endedAt)
            guard let first = dates.min(), let last = dates.max() else { return nil }
            let days = calendar.dateComponents([.day], from: first, to: today).day ?? 0
            let months = Set(dates.map { calendar.dateComponents([.year, .month], from: $0) }).count
            guard days >= 180, months >= 4, entries.count >= 6,
                  let recentStart = calendar.date(byAdding: .day, value: -30, to: today), last >= recentStart else { return nil }
            return card(.longTerm, "長い付き合いの1曲", "初めて聴いてから\(days)日。今も聴いています", entries[0].track,
                        priority: 63, score: Double(months * 4) + Double(days) / 365, until: nextDay)
        }
        return withSharedQueue(candidates)
    }

    private func recurring(_ index: Index, today: Date, nextDay: Date, calendar: Calendar) -> [MusicHistoryCardCandidate] {
        guard let start = calendar.date(byAdding: .month, value: -11,
                                        to: calendar.date(from: calendar.dateComponents([.year, .month], from: today)) ?? today) else { return [] }
        let candidates = index.byTrack.values.compactMap { entries -> MusicHistoryCardCandidate? in
            let recent = entries.filter { $0.event.endedAt >= start }
            let months = Set(recent.map { calendar.dateComponents([.year, .month], from: $0.event.endedAt) }).count
            guard months >= 4, recent.count >= 6 else { return nil }
            return card(.recurring, "何度も戻ってくる曲", "この1年で\(months)か月、この曲を聴いています", entries[0].track,
                        priority: 58, score: Double(months * 5 + min(recent.count, 12)), until: nextDay)
        }
        return withSharedQueue(candidates)
    }

    private func night(_ index: Index, nextDay: Date, calendar: Calendar) -> [MusicHistoryCardCandidate] {
        let candidates = index.byTrack.values.compactMap { entries -> MusicHistoryCardCandidate? in
            let count = entries.count { entry in
                let hour = calendar.component(.hour, from: entry.event.endedAt)
                return hour >= 22 || hour < 5
            }
            guard count >= 4, entries.count >= 5 else { return nil }
            let ratio = Double(count) / Double(entries.count)
            guard ratio >= 0.6 else { return nil }
            return card(.night, "夜のあなたの1曲", "22時から朝5時前によく聴いています", entries[0].track,
                        priority: 55, score: ratio * 20 + Double(count), until: nextDay)
        }
        return withSharedQueue(candidates)
    }

    private func shuffleDiscovery(_ index: Index, preferences: [Track.ID: TrackPreference], nextDay: Date) -> [MusicHistoryCardCandidate] {
        let automaticSources: Set<PlaybackStartSource> = [.shuffle, .station, .highlight]
        let candidates = index.byTrack.values.compactMap { entries -> MusicHistoryCardCandidate? in
            let sorted = entries.sorted { $0.event.startedAt < $1.event.startedAt }
            guard let first = sorted.first,
                  first.event.startKind == .automatic,
                  automaticSources.contains(first.event.startSource) else { return nil }
            let manual = sorted.dropFirst().count { $0.event.startKind == .manual }
            guard manual >= 2, sorted.count >= 4 else { return nil }
            let preference = preferences[first.track.id]
            guard preference?.favorite == true || (preference?.playbackPreference ?? 0) > 0 || sorted.count >= 6 else { return nil }
            return card(.shuffleDiscovery, "Shuffleが教えてくれた曲", "最初は自動再生。今は自分で選んで聴いています", first.track,
                        priority: 73, score: Double(manual * 3 + sorted.count), until: nextDay)
        }
        return withSharedQueue(candidates)
    }

    private func busiestDay(_ index: Index, today: Date, nextDay: Date, calendar: Calendar) -> [MusicHistoryCardCandidate] {
        let year = calendar.component(.year, from: today)
        guard let peak = index.byDay.filter({ calendar.component(.year, from: $0.key) == year })
            .sorted(by: { $0.value.count == $1.value.count ? $0.key > $1.key : $0.value.count > $1.value.count }).first,
              peak.value.count >= 5 else { return [] }
        let unique = Set(peak.value.map(\.track.id)).count
        guard unique >= 3 else { return [] }
        let label = peak.key.formatted(.dateTime.year().month().day().locale(Locale(identifier: "ja_JP")))
        let ranked = rankedTracks(peak.value)
        return ranked.prefix(4).enumerated().map { offset, item in
            card(.busiestDay, "一番音楽を聴いた日", "\(label)・\(peak.value.count)回・\(unique)曲", item.track,
                 priority: 48, score: Double(peak.value.count) - Double(offset) * 0.01, until: nextDay,
                 playbackTracks: ranked.map(\.track), date: peak.key)
        }
    }

    private func monthSound(_ entries: [Entry], tracks: [Track], features: [Track.ID: TrackFeature], nextMonth: Date) -> [MusicHistoryCardCandidate] {
        let names = ["energy": "Energy", "calm": "Calm", "bright": "Bright", "dark": "Dark", "ambient": "Ambient",
                     "electronic": "Electronic", "vocal": "Vocal", "instrumental": "Instrumental", "piano": "Piano", "aggressive": "Aggressive"]
        let featured = entries.compactMap { entry -> (Track, TrackFeatureValues)? in
            features[entry.track.id].map { (entry.track, $0.values) }
        }
        guard featured.count >= 5, Set(featured.map { $0.0.id }).count >= 3 else { return [] }
        let libraryValues = tracks.compactMap { features[$0.id]?.values }
        guard libraryValues.count >= 5 else { return [] }
        let trends = names.compactMap { key, label -> (key: String, label: String, difference: Double)? in
            let current = featured.compactMap { $0.1.score(named: key) }.filter(\.isFinite)
            let baseline = libraryValues.compactMap { $0.score(named: key) }.filter(\.isFinite)
            guard current.count >= 5, baseline.count >= 5 else { return nil }
            let difference = current.reduce(0, +) / Double(current.count) - baseline.reduce(0, +) / Double(baseline.count)
            return difference >= 0.08 ? (key, label, difference) : nil
        }.sorted { $0.difference == $1.difference ? $0.key < $1.key : $0.difference > $1.difference }
        guard !trends.isEmpty else { return [] }
        let labels = trends.prefix(3).map(\.label)
        let monthlyRanked = rankedTracks(entries.filter { features[$0.track.id] != nil })
        var scored: [(track: Track, score: Double)] = []
        for item in monthlyRanked {
            var fit = 0.0
            for trend in trends.prefix(3) {
                let rawValue = features[item.track.id]?.values.score(named: trend.key) ?? 0
                let value = rawValue.isFinite ? rawValue : 0
                fit += value * trend.difference
            }
            scored.append((item.track, fit + Double(item.count) * 0.001))
        }
        scored.sort { $0.score == $1.score ? $0.track.id.uuidString < $1.track.id.uuidString : $0.score > $1.score }
        let playbackTracks = scored.map { $0.track }
        return monthlyRanked.prefix(6).enumerated().map { offset, item in
            card(.monthSound, "今月の音", "今月は\(labels.joined(separator: "・"))寄りの曲を聴いています", item.track,
                 priority: 52, score: trends[0].difference * 100 - Double(offset) * 0.01, until: nextMonth,
                 playbackTracks: playbackTracks)
        }
    }

    private func monthAlbum(monthEntries: [Entry], tracks: [Track], nextMonth: Date) -> [MusicHistoryCardCandidate] {
        Dictionary(grouping: monthEntries.compactMap { entry -> (String, Entry)? in
            albumKey(entry.track).map { ($0, entry) }
        }, by: { $0.0 }).compactMap { key, pairs -> [MusicHistoryCardCandidate]? in
            let entries = pairs.map(\.1)
            let unique = Set(entries.map(\.track.id)).count
            guard unique >= 2, entries.count >= 4,
                  let album = entries.first?.track.albumTitle else { return nil }
            let libraryCount = tracks.count { albumKey($0) == key }
            let spread = Double(unique) / Double(max(libraryCount, 1))
            let ranked = rankedTracks(entries)
            return ranked.prefix(4).enumerated().map { offset, item in
                card(.monthAlbum, "今月のAlbum", "\(album)から\(unique)曲を聴いています", item.track,
                     priority: 62, score: Double(entries.count + unique * 3) + spread * 5 - Double(offset) * 0.01,
                     until: nextMonth, playbackTracks: ranked.map(\.track), album: album)
            }
        }.flatMap { $0 }
    }

    private func albumKey(_ track: Track) -> String? {
        guard let title = track.albumTitle?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty else { return nil }
        return title + "\u{001F}" + (track.albumArtistName ?? track.artistName)
    }

    private func select(_ candidates: [MusicHistoryCardCandidate], limit: Int) -> [MusicHistoryCardCandidate] {
        guard limit > 0 else { return [] }
        var types: Set<MusicHistoryCardType> = []
        var featured: Set<Track.ID> = []
        var result: [MusicHistoryCardCandidate] = []
        for candidate in candidates.sorted(by: {
            if $0.priority != $1.priority { return $0.priority > $1.priority }
            if $0.score != $1.score { return $0.score > $1.score }
            return $0.id < $1.id
        }) {
            guard !types.contains(candidate.type),
                  let track = candidate.mainTrack, !featured.contains(track.id) else { continue }
            result.append(candidate)
            types.insert(candidate.type)
            featured.insert(track.id)
            if result.count >= max(0, limit) { break }
        }
        return result
    }
}
