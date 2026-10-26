import Foundation

nonisolated enum ArtistRankingDivision: String, CaseIterable, Codable, Sendable {
    case instrumental, vocal
    var title: String { self == .instrumental ? "インスト部門" : "ボーカル部門" }
}

nonisolated struct ArtistRankingGenreRule: Codable, Equatable, Sendable {
    var genres: Set<String>
    var includesUnassigned: Bool
    init(genres: Set<String> = [], includesUnassigned: Bool = false) {
        self.genres = genres; self.includesUnassigned = includesUnassigned
    }
    func matches(_ genres: Set<String>) -> Bool {
        genres.isEmpty ? includesUnassigned : !self.genres.isDisjoint(with: genres)
    }
}

nonisolated struct ArtistRankingSettings: Codable, Equatable, Sendable {
    var instrumental = ArtistRankingGenreRule()
    var vocal = ArtistRankingGenreRule()
    init() {}
    subscript(_ division: ArtistRankingDivision) -> ArtistRankingGenreRule {
        get { division == .instrumental ? instrumental : vocal }
        set { if division == .instrumental { instrumental = newValue } else { vocal = newValue } }
    }
}

nonisolated enum ArtistRankingMetric: String, CaseIterable, Sendable {
    case score, count, time
    var title: String {
        switch self { case .score: "総合評価"; case .count: "再生回数"; case .time: "実聴時間" }
    }
}

nonisolated struct ArtistRankingRow: Identifiable, Equatable, Sendable {
    let id: String
    var title: String { id.isEmpty ? "アーティスト未設定" : id }
    let trackIDs: [Track.ID]
    let artworkTrackID: Track.ID?
    let artworkIdentifier: String?
    let totalTrackCount: Int
    let playCount: Int
    let seconds: Double
    let good: Int
    let favorites: Int
    var divisor: Double { sqrt(Double(max(totalTrackCount, 4))) }
    var adjustedCount: Double { Double(playCount) / divisor }
    var adjustedTime: Double { seconds / divisor }
    var countPoints: Double = 0
    var timePoints: Double = 0
    var goodPoints: Double = 0
    var favoritePoints: Double = 0
    var score: Double { countPoints * 0.4 + timePoints * 0.1 + goodPoints * 0.3 + favoritePoints * 0.2 }
    func value(for metric: ArtistRankingMetric) -> Double {
        switch metric { case .score: score; case .count: Double(playCount); case .time: seconds }
    }
}

nonisolated struct ArtistRankingPage: Equatable, Sendable {
    let byScore: [ArtistRankingRow]
    let byCount: [ArtistRankingRow]
    let byTime: [ArtistRankingRow]
    static let empty = ArtistRankingPage(byScore: [], byCount: [], byTime: [])
    subscript(_ metric: ArtistRankingMetric) -> [ArtistRankingRow] {
        switch metric { case .score: byScore; case .count: byCount; case .time: byTime }
    }
}

nonisolated enum ArtistRankingService {
    /// One library traversal supplies the all-genre denominator and both divisions.
    /// Ranking switches reuse the three pre-sorted top-100 lists.
    static func pages(tracks: [Track], histories: [Track.ID: PlaybackHistory], preferences: [Track.ID: TrackPreference], settings: ArtistRankingSettings)
        -> [ArtistRankingDivision: ArtistRankingPage] {
        var totals: [String: Int] = [:]
        var groups: [ArtistRankingDivision: [String: [Track]]] = [:]
        for track in tracks {
            if Task.isCancelled { return [:] }
            let artist = track.artistName.trimmingCharacters(in: .whitespacesAndNewlines)
            totals[artist, default: 0] += 1
            guard track.isEligibleForRegularPlayback else { continue }
            let genres = track.normalizedGenreNames
            for division in ArtistRankingDivision.allCases where settings[division].matches(genres) {
                groups[division, default: [:]][artist, default: []].append(track)
            }
        }
        var result: [ArtistRankingDivision: ArtistRankingPage] = [:]
        for division in ArtistRankingDivision.allCases {
            if Task.isCancelled { return [:] }
            var rows = (groups[division] ?? [:]).map { artist, members in
                let ordered = members.sorted { $0.id.uuidString < $1.id.uuidString }
                var count = 0, good = 0, favorites = 0
                var seconds = 0.0
                for track in members {
                    count += max(0, histories[track.id]?.playCount ?? 0)
                    // Match HomeStereo's detailed-event time; do not infer legacy listening time.
                    for event in histories[track.id]?.playbackEvents ?? [] {
                        if event.listenedSeconds.isFinite { seconds += max(0, event.listenedSeconds) }
                    }
                    good += max(0, preferences[track.id]?.playbackPreference ?? 0)
                    if preferences[track.id]?.favorite == true { favorites += 1 }
                }
                return ArtistRankingRow(id: artist, trackIDs: ordered.map(\.id),
                    artworkTrackID: ordered.first(where: { $0.artworkIdentifier != nil })?.id ?? ordered.first?.id,
                    artworkIdentifier: ordered.first(where: { $0.artworkIdentifier != nil })?.artworkIdentifier,
                    totalTrackCount: totals[artist] ?? members.count, playCount: count,
                    seconds: seconds, good: good, favorites: favorites)
            }
            let maxCount = rows.map(\.adjustedCount).max() ?? 0
            let maxTime = rows.map(\.adjustedTime).max() ?? 0
            let maxGood = Double(rows.map(\.good).max() ?? 0)
            let maxFavorites = Double(rows.map(\.favorites).max() ?? 0)
            func points(_ value: Double, _ maximum: Double) -> Double {
                maximum > 0 ? min(100, max(0, value / maximum * 100)) : 0
            }
            for index in rows.indices {
                rows[index].countPoints = points(rows[index].adjustedCount, maxCount)
                rows[index].timePoints = points(rows[index].adjustedTime, maxTime)
                rows[index].goodPoints = points(Double(rows[index].good), maxGood)
                rows[index].favoritePoints = points(Double(rows[index].favorites), maxFavorites)
            }
            func ranked(_ metric: ArtistRankingMetric) -> [ArtistRankingRow] {
                Array(rows.filter { $0.value(for: metric) > 0 }.sorted {
                    let left = $0.value(for: metric), right = $1.value(for: metric)
                    if left != right { return left > right }
                    let comparison = $0.title.localizedStandardCompare($1.title)
                    return comparison == .orderedSame ? $0.id < $1.id : comparison == .orderedAscending
                }.prefix(100))
            }
            result[division] = ArtistRankingPage(byScore: ranked(.score), byCount: ranked(.count), byTime: ranked(.time))
        }
        return result
    }
}
