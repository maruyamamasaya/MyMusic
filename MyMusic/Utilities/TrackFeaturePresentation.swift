import Foundation

nonisolated struct TrackFeatureDisplayItem: Identifiable, Hashable, Sendable {
    let id: String
    let label: String
    let score: Double
    fileprivate let sortOrder: Int
}

nonisolated enum TrackFeaturePresentation {
    static let badgeThreshold = 0.68
    static let maximumBadgeCount = 3

    static func categoryItems(for values: TrackFeatureValues) -> [TrackFeatureDisplayItem] {
        let candidates: [TrackFeatureDisplayItem?] = [
            item("piano", "ピアノ", values.piano, 0),
            item("ambient", "アンビエント", values.ambient, 1),
            item("electronic", "エレクトロ", values.electronic, 2),
            item("drumAndBass", "DnB", values.drumAndBass, 3),
            item("aggressive", "力強い", values.aggressive, 4),
            item("calm", "穏やか", values.calm, 5),
            item("bright", "明るい", values.bright, 6),
            item("dark", "ダーク", values.dark, 7),
            item("vocal", "ボーカル", values.vocal, 8),
            item("instrumental", "インスト", values.instrumental, 9)
        ]
        return candidates.compactMap { $0 }.sorted {
            if $0.score == $1.score { return $0.sortOrder < $1.sortOrder }
            return $0.score > $1.score
        }
    }

    static func badgeItems(for values: TrackFeatureValues) -> [TrackFeatureDisplayItem] {
        Array(
            categoryItems(for: values)
                .filter { $0.score >= badgeThreshold }
                .prefix(maximumBadgeCount)
        )
    }

    private static func item(
        _ id: String,
        _ label: String,
        _ score: Double?,
        _ sortOrder: Int
    ) -> TrackFeatureDisplayItem? {
        guard let score, score.isFinite, (0...1).contains(score) else { return nil }
        return TrackFeatureDisplayItem(id: id, label: label, score: score, sortOrder: sortOrder)
    }
}
