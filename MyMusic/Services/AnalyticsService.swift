import Foundation

struct AnalyticsSnapshot {
    struct TrackItem: Identifiable {
        let track: Track
        let playCount: Int
        let firstPlayedAt: Date?
        let lastPlayedAt: Date?
        let playbackPreference: Int
        let boredomLevel: Int
        let boredomHiddenUntil: Date?
        let isPermanentlyHiddenFromShuffle: Bool
        let manualPlayCount: Int
        let automaticPlayCount: Int
        let playsLast7Days: Int
        let playsLast30Days: Int
        let sourceCounts: [String: Int]
        var id: Track.ID { track.id }
    }

    struct PlaybackEvent: Identifiable {
        let id = UUID()
        let track: Track
        let playedAt: Date
    }

    struct DayGroup: Identifiable {
        let date: Date
        let events: [PlaybackEvent]
        var id: Date { date }
    }

    struct MonthGroup: Identifiable {
        let date: Date
        let days: [DayGroup]
        var id: Date { date }
        var eventCount: Int { days.reduce(0) { $0 + $1.events.count } }
    }

    let totalPlayCount: Int
    let totalManualPlayCount: Int
    let totalAutomaticPlayCount: Int
    let playedTrackCount: Int
    let favoriteCount: Int
    let playlistCount: Int
    let mostPlayedTrack: TrackItem?
    let mostPlayedTracks: [TrackItem]
    let preferenceRatedTracks: [TrackItem]
    let currentlyHiddenTracks: [TrackItem]
    let previouslyHiddenTracks: [TrackItem]
    let permanentlyHiddenTracks: [TrackItem]
    let playbackMonths: [MonthGroup]
}

@MainActor
final class AnalyticsService {
    func makeSnapshot(
        tracks: [Track],
        historyEntries: [Track.ID: PlaybackHistory],
        playlists: [Playlist]
    ) -> AnalyticsSnapshot {
        let tracksByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        let trackItems = tracks.map { track in
            let history = historyEntries[track.id]
            return AnalyticsSnapshot.TrackItem(
                track: track,
                playCount: history?.playCount ?? 0,
                firstPlayedAt: history?.firstPlayedAt,
                lastPlayedAt: history?.lastPlayedAt,
                playbackPreference: history?.playbackPreference ?? 0,
                boredomLevel: history.map { $0.isPermanentlyHiddenFromShuffle ? 3 : min($0.boredomCount, 2) } ?? 0,
                boredomHiddenUntil: history?.boredomHiddenUntil,
                isPermanentlyHiddenFromShuffle: history?.isPermanentlyHiddenFromShuffle ?? false,
                manualPlayCount: history?.manualPlayCount ?? 0,
                automaticPlayCount: history?.automaticPlayCount ?? 0,
                playsLast7Days: history.map { playbackCount(inLastDays: 7, of: $0) } ?? 0,
                playsLast30Days: history.map { playbackCount(inLastDays: 30, of: $0) } ?? 0,
                sourceCounts: history?.playbackSourceCounts ?? [:]
            )
        }
        let playCounts = trackItems.filter { $0.playCount > 0 }.sorted(by: playCountSort)
        let events = historyEntries.values.flatMap { history in
            guard let track = tracksByID[history.trackID] else { return [AnalyticsSnapshot.PlaybackEvent]() }
            return history.playbackEvents.map {
                AnalyticsSnapshot.PlaybackEvent(track: track, playedAt: $0)
            }
        }
        .sorted { $0.playedAt > $1.playedAt }

        return AnalyticsSnapshot(
            totalPlayCount: historyEntries.values.reduce(0) { $0 + $1.playCount },
            totalManualPlayCount: historyEntries.values.reduce(0) { $0 + $1.manualPlayCount },
            totalAutomaticPlayCount: historyEntries.values.reduce(0) { $0 + $1.automaticPlayCount },
            playedTrackCount: historyEntries.values.filter { $0.lastPlayedAt != nil }.count,
            favoriteCount: historyEntries.values.filter(\.isFavorite).count,
            playlistCount: playlists.count,
            mostPlayedTrack: playCounts.first,
            mostPlayedTracks: playCounts,
            preferenceRatedTracks: trackItems
                .filter { $0.playbackPreference != 0 }
                .sorted(by: titleSort),
            currentlyHiddenTracks: trackItems
                .filter { !$0.isPermanentlyHiddenFromShuffle && ($0.boredomHiddenUntil.map { $0 > Date() } ?? false) }
                .sorted(by: titleSort),
            previouslyHiddenTracks: trackItems
                .filter { $0.boredomLevel > 0 && !$0.isPermanentlyHiddenFromShuffle && !($0.boredomHiddenUntil.map { $0 > Date() } ?? false) }
                .sorted(by: titleSort),
            permanentlyHiddenTracks: trackItems
                .filter(\.isPermanentlyHiddenFromShuffle)
                .sorted(by: titleSort),
            playbackMonths: groupedEvents(events)
        )
    }

    private func playbackCount(inLastDays days: Int, of entry: PlaybackHistory, now: Date = Date()) -> Int {
        guard days > 0 else { return 0 }
        return Self.dayKeys(inLastDays: days, now: now)
            .reduce(0) { total, key in
                total + (entry.dailySummaries[key]?.playCount ?? 0)
            }
    }

    private static func dayKeys(inLastDays days: Int, now: Date) -> [String] {
        var calendar = Calendar.current
        calendar.timeZone = .current
        return (0..<days).compactMap { offset in
            let day = calendar.date(byAdding: .day, value: -offset, to: now)
            guard let day else { return nil }
            let components = calendar.dateComponents([.year, .month, .day], from: day)
            return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
        }
    }

    func csv(
        snapshot: AnalyticsSnapshot,
        playlists: [Playlist],
        equalizer: EqualizerSettings? = nil,
        customEqualizerPresets: [EqualizerPreset] = []
    ) -> String {
        var rows = ["種類,日時,曲名,アーティスト,再生回数,値,詳細"]
        for month in snapshot.playbackMonths {
            for day in month.days {
                for event in day.events {
                    rows.append(["再生履歴", Self.dateTimeFormatter.string(from: event.playedAt), event.track.title, event.track.artistName, "", "", ""].map(csvField).joined(separator: ","))
                }
            }
        }
        for item in snapshot.mostPlayedTracks {
            rows.append(["楽曲別再生回数", "", item.track.title, item.track.artistName, "\(item.playCount)", "", ""].map(csvField).joined(separator: ","))
            let firstPlayedText = item.firstPlayedAt.map(Self.dateTimeFormatter.string) ?? ""
            let lastPlayedText = item.lastPlayedAt.map(Self.dateTimeFormatter.string) ?? ""
            let behaviorText = "manual:\(item.manualPlayCount), automatic:\(item.automaticPlayCount), 7日:\(item.playsLast7Days), 30日:\(item.playsLast30Days), 初回:\(firstPlayedText), 最終:\(lastPlayedText)"
            rows.append(["楽曲別再生行動", "", item.track.title, item.track.artistName, "\(item.playCount)", "", behaviorText].map(csvField).joined(separator: ","))
            rows.append(["楽曲別再生入口", "", item.track.title, item.track.artistName, "", "", playbackSourceText(from: item.sourceCounts)].map(csvField).joined(separator: ","))
        }
        for item in snapshot.preferenceRatedTracks {
            rows.append([
                "再生傾向評価",
                "",
                item.track.title,
                item.track.artistName,
                "",
                String(format: "%+d", item.playbackPreference),
                ""
            ].map(csvField).joined(separator: ","))
        }
        for item in snapshot.currentlyHiddenTracks {
            rows.append(["飽きた・現在非表示", item.boredomHiddenUntil.map(Self.dateTimeFormatter.string) ?? "", item.track.title, item.track.artistName, "", "飽き度\(item.boredomLevel)", ""].map(csvField).joined(separator: ","))
        }
        for item in snapshot.previouslyHiddenTracks {
            rows.append(["飽きた・解除済み", "", item.track.title, item.track.artistName, "", "飽き度\(item.boredomLevel)", ""].map(csvField).joined(separator: ","))
        }
        for item in snapshot.permanentlyHiddenTracks {
            rows.append(["飽きた・永久非表示", "", item.track.title, item.track.artistName, "", "飽き度3", ""].map(csvField).joined(separator: ","))
        }
        rows.append(["集計", "", "総再生", "", "\(snapshot.totalPlayCount)", "", ""].map(csvField).joined(separator: ","))
        rows.append(["集計", "", "手動再生", "", "\(snapshot.totalManualPlayCount)", "", ""].map(csvField).joined(separator: ","))
        rows.append(["集計", "", "自動再生", "", "\(snapshot.totalAutomaticPlayCount)", "", ""].map(csvField).joined(separator: ","))
        rows.append(["集計", "", "お気に入り", "", "\(snapshot.favoriteCount)", "", ""].map(csvField).joined(separator: ","))
        rows.append(["集計", "", "プレイリスト", "", "\(snapshot.playlistCount)", "", ""].map(csvField).joined(separator: ","))
        for playlist in playlists {
            rows.append(["プレイリスト", Self.dateTimeFormatter.string(from: playlist.updatedAt), playlist.name, "", "", "\(playlist.trackIDs.count)曲", ""].map(csvField).joined(separator: ","))
        }
        if let equalizer {
            rows.append(["EQ設定", "", "現在の設定", "", "", equalizer.isEnabled ? "ON" : "OFF", ""].map(csvField).joined(separator: ","))
            rows.append(["EQ設定", "", "現在の設定", "プリアンプ", "", Self.gainString(equalizer.preamp), ""].map(csvField).joined(separator: ","))
            appendEqualizerBands(equalizer.bands, type: "EQ設定", name: "現在の設定", to: &rows)
        }
        for preset in customEqualizerPresets {
            rows.append(["EQプリセット", "", preset.name, "プリアンプ", "", Self.gainString(preset.preamp), ""].map(csvField).joined(separator: ","))
            appendEqualizerBands(preset.settings().bands, type: "EQプリセット", name: preset.name, to: &rows)
        }
        return rows.joined(separator: "\n")
    }

    private func playbackSourceText(from sourceCounts: [String: Int]) -> String {
        if sourceCounts.isEmpty { return "記録なし" }

        let ordered = sourceCounts
            .compactMap { (key: String, value: Int) -> (String, Int)? in
                PlaybackStartSource(rawValue: key).map { ($0.rawValue, value) }
            }
            .sorted { lhs, rhs in
                if lhs.1 == rhs.1 { return lhs.0 < rhs.0 }
                return lhs.1 > rhs.1
            }
        guard !ordered.isEmpty else {
            return "記録なし"
        }
        return ordered
            .map { "\($0.0):\($0.1)" }
            .joined(separator: " ")
    }

    static let dateTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter
    }()

    private func groupedEvents(_ events: [AnalyticsSnapshot.PlaybackEvent]) -> [AnalyticsSnapshot.MonthGroup] {
        let calendar = Calendar.current
        let months = Dictionary(grouping: events) { event in
            calendar.date(from: calendar.dateComponents([.year, .month], from: event.playedAt))!
        }
        return months.map { month, monthEvents in
            let days = Dictionary(grouping: monthEvents) { calendar.startOfDay(for: $0.playedAt) }
                .map { AnalyticsSnapshot.DayGroup(date: $0.key, events: $0.value.sorted { $0.playedAt > $1.playedAt }) }
                .sorted { $0.date > $1.date }
            return AnalyticsSnapshot.MonthGroup(date: month, days: days)
        }
        .sorted { $0.date > $1.date }
    }

    private func playCountSort(_ lhs: AnalyticsSnapshot.TrackItem, _ rhs: AnalyticsSnapshot.TrackItem) -> Bool {
        if lhs.playCount != rhs.playCount { return lhs.playCount > rhs.playCount }
        return lhs.track.title.localizedStandardCompare(rhs.track.title) == .orderedAscending
    }

    private func titleSort(_ lhs: AnalyticsSnapshot.TrackItem, _ rhs: AnalyticsSnapshot.TrackItem) -> Bool {
        let titleComparison = lhs.track.title.localizedStandardCompare(rhs.track.title)
        if titleComparison != .orderedSame { return titleComparison == .orderedAscending }
        return lhs.track.artistName.localizedStandardCompare(rhs.track.artistName) == .orderedAscending
    }

    private func csvField(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func appendEqualizerBands(_ bands: [EqualizerBand], type: String, name: String, to rows: inout [String]) {
        for band in bands {
            rows.append([type, "", name, "\(Int(band.frequency)) Hz", "", Self.gainString(band.gain), ""].map(csvField).joined(separator: ","))
        }
    }

    private static func gainString(_ gain: Float) -> String {
        String(format: "%+.1f dB", gain)
    }
}
