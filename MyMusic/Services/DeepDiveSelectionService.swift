import Foundation

enum DeepDiveKind: String, CaseIterable, Identifiable {
    case artist
    case album

    var id: Self { self }
    var title: String { self == .artist ? "Artist" : "Album" }
    var systemImage: String { self == .artist ? "music.mic" : "square.stack" }
}

struct DeepDiveOption: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String?
    let recentPlayCount: Int
    let tracks: [Track]
    let artworkIdentifier: String?
}

struct DeepDiveSelectionService {
    static let maximumOptionCount = 8
    static let minimumRecentPlays = 15
    static let recentDays = 30

    func options(
        from candidates: [Track],
        histories: [Track.ID: PlaybackHistory],
        weights: [Track.ID: Double],
        now: Date = Date(),
        calendar: Calendar = .playbackHistory
    ) -> [DeepDiveKind: [DeepDiveOption]] {
        let ranked = MixSelectionService().ranked(candidates, weights: weights, now: now, calendar: calendar)
        let rankByID = Dictionary(uniqueKeysWithValues: ranked.enumerated().map { ($0.element.id, $0.offset) })
        let recentDayKeys = Set((0..<Self.recentDays).compactMap { offset -> String? in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: now) else { return nil }
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        })
        let recentPlays = Dictionary(uniqueKeysWithValues: candidates.map { track in
            let summaries = histories[track.id]?.dailySummaries ?? [:]
            let count = recentDayKeys.reduce(0) { $0 + (summaries[$1]?.playCount ?? 0) }
            return (track.id, count)
        })
        return Dictionary(uniqueKeysWithValues: DeepDiveKind.allCases.map { kind in
            let groups = Dictionary(grouping: candidates.compactMap { track -> (String, Track)? in
                guard let key = key(for: track, kind: kind) else { return nil }
                return (key, track)
            }, by: \.0)
            let options = groups.compactMap { key, members -> DeepDiveOption? in
                let recentCount = members.reduce(0) { total, member in
                    total + (recentPlays[member.1.id] ?? 0)
                }
                let lowPlay = members.map { $0.1 }.filter { (histories[$0.id]?.playCount ?? 0) <= 1 }
                guard recentCount >= Self.minimumRecentPlays, !lowPlay.isEmpty,
                      let representative = members.first?.1 else { return nil }
                let queue = Array(lowPlay.sorted {
                    let leftCount = histories[$0.id]?.playCount ?? 0
                    let rightCount = histories[$1.id]?.playCount ?? 0
                    if leftCount != rightCount { return leftCount < rightCount }
                    return (rankByID[$0.id] ?? .max) < (rankByID[$1.id] ?? .max)
                }.prefix(MixSelectionService.maximumCount))
                return DeepDiveOption(
                    id: key,
                    title: (kind == .artist ? representative.artistName : representative.albumTitle ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                    detail: kind == .album
                        ? (representative.albumArtistName ?? representative.artistName)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        : nil,
                    recentPlayCount: recentCount,
                    tracks: queue,
                    artworkIdentifier: queue.first?.artworkIdentifier
                )
            }
            return (kind, Array(options.shuffled().prefix(Self.maximumOptionCount)))
        })
    }

    private func key(for track: Track, kind: DeepDiveKind) -> String? {
        let artist = normalized(track.artistName)
        if kind == .artist { return artist.isEmpty ? nil : artist }
        guard let album = track.albumTitle.map(normalized), !album.isEmpty else { return nil }
        let albumArtist = track.albumArtistName.map(normalized).flatMap { $0.isEmpty ? nil : $0 } ?? artist
        guard !albumArtist.isEmpty else { return nil }
        return "\(albumArtist)\u{1F}\(album)"
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
}
