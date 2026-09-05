import Foundation

enum HighlightSelectionMode: String, CaseIterable, Identifiable, Sendable {
    case shuffle
    case upbeat
    case calm
    case discovery

    var id: Self { self }

    var title: String {
        switch self {
        case .shuffle: "シャッフル"
        case .upbeat: "アガる"
        case .calm: "穏やか"
        case .discovery: "発掘"
        }
    }
}

/// Highlight-only adjustments layered on top of regular shuffle's Preference and Overplay weight.
enum HighlightSelectionPolicy {
    private static let modeBandWidth = 0.05
    private static let randomJitterRange = 0.01

    struct Ranking: Equatable {
        let modeBand: Int
        let adjustedWeight: Double
    }

    static func recentHighlightRanks(
        histories: [Track.ID: PlaybackHistory]
    ) -> [Track.ID: Int] {
        let events = histories.values
            .flatMap(\.playbackEvents)
            .filter { $0.startSource == .highlight }
            .sorted { $0.startedAt > $1.startedAt }

        var ranks: [Track.ID: Int] = [:]
        for (offset, event) in events.prefix(50).enumerated() where ranks[event.trackID] == nil {
            ranks[event.trackID] = offset + 1
        }
        return ranks
    }

    static func recentHighlightPenalty(rank: Int?) -> Double {
        guard let rank, rank > 0 else { return 1 }
        if rank <= 20 { return 0.20 }
        if rank <= 50 { return 0.60 }
        return 1
    }

    static func modeWeight(
        mode: HighlightSelectionMode,
        feature: TrackFeatureValues?,
        history: PlaybackHistory?,
        now: Date
    ) -> Double {
        switch mode {
        case .shuffle:
            return 1
        case .upbeat:
            return featureMultiplier(feature, values: [
                (\.energy, 1), (\.aggressive, 1), (\.bright, 1), (\.drumAndBass, 0.5)
            ])
        case .calm:
            return featureMultiplier(feature, values: [
                (\.calm, 1), (\.ambient, 1), (\.piano, 1)
            ])
        case .discovery:
            return discoveryWeight(history: history, now: now)
        }
    }

    /// Returns a 0...1 priority used before Preference, Overplay, and recency.
    /// Shuffle intentionally has no feature direction and therefore returns nil.
    static func modeAffinity(
        mode: HighlightSelectionMode,
        feature: TrackFeatureValues?,
        history: PlaybackHistory?,
        now: Date
    ) -> Double? {
        switch mode {
        case .shuffle:
            return nil
        case .upbeat:
            return featureAffinity(feature, values: [
                (\.energy, 1), (\.aggressive, 1), (\.bright, 1), (\.drumAndBass, 0.5)
            ])
        case .calm:
            return featureAffinity(feature, values: [
                (\.calm, 1), (\.ambient, 1), (\.piano, 1)
            ])
        case .discovery:
            return discoveryWeight(history: history, now: now) - 1
        }
    }

    static func rankings(
        tracks: [Track],
        mode: HighlightSelectionMode,
        baseWeights: [Track.ID: Double],
        histories: [Track.ID: PlaybackHistory],
        features: [Track.ID: TrackFeatureValues],
        now: Date
    ) -> [Track.ID: Ranking] {
        let ranks = recentHighlightRanks(histories: histories)
        return Dictionary(tracks.map { track in
            let affinity = modeAffinity(
                mode: mode, feature: features[track.id], history: histories[track.id], now: now
            )
            let modeBand = affinity.map { Int(floor($0 / modeBandWidth)) } ?? 0
            let adjustedWeight = max(
                (baseWeights[track.id] ?? 1) * recentHighlightPenalty(rank: ranks[track.id]),
                Double.leastNonzeroMagnitude
            )
            return (track.id, Ranking(modeBand: modeBand, adjustedWeight: adjustedWeight))
        }, uniquingKeysWith: { first, _ in first })
    }

    static func finalWeights(
        tracks: [Track],
        mode: HighlightSelectionMode,
        baseWeights: [Track.ID: Double],
        histories: [Track.ID: PlaybackHistory],
        features: [Track.ID: TrackFeatureValues],
        now: Date
    ) -> [Track.ID: Double] {
        let ranks = recentHighlightRanks(histories: histories)
        return Dictionary(tracks.map { track in
            let weight = (baseWeights[track.id] ?? 1)
                * recentHighlightPenalty(rank: ranks[track.id])
                * modeWeight(mode: mode, feature: features[track.id], history: histories[track.id], now: now)
            return (track.id, max(weight, Double.leastNonzeroMagnitude))
        }, uniquingKeysWith: { first, _ in first })
    }

    static func orderedTracks(
        _ tracks: [Track],
        mode: HighlightSelectionMode,
        baseWeights: [Track.ID: Double],
        histories: [Track.ID: PlaybackHistory],
        features: [Track.ID: TrackFeatureValues],
        now: Date = Date(),
        randomValues: [Track.ID: Double] = [:]
    ) -> [Track] {
        let rankings = rankings(
            tracks: tracks, mode: mode, baseWeights: baseWeights,
            histories: histories, features: features, now: now
        )
        return tracks.map { track in
            let ranking = rankings[track.id] ?? Ranking(modeBand: 0, adjustedWeight: 1)
            let random = min(max(randomValues[track.id] ?? Double.random(in: 0...1), 0), 1)
            let jitter = 1 - randomJitterRange / 2 + randomJitterRange * random
            return (track, ranking.modeBand, ranking.adjustedWeight * jitter)
        }
        .sorted {
            if $0.1 != $1.1 { return $0.1 > $1.1 }
            if $0.2 != $1.2 { return $0.2 > $1.2 }
            return $0.0.id.uuidString < $1.0.id.uuidString
        }
        .map(\.0)
    }

    private static func featureMultiplier(
        _ feature: TrackFeatureValues?,
        values: [(KeyPath<TrackFeatureValues, Double?>, Double)]
    ) -> Double {
        guard let feature else { return 1 }
        let valid = values.compactMap { keyPath, importance -> (Double, Double)? in
            guard let value = feature[keyPath: keyPath], value.isFinite, (0...1).contains(value) else { return nil }
            return (value, importance)
        }
        guard !valid.isEmpty else { return 1 }
        let totalImportance = valid.reduce(0) { $0 + $1.1 }
        let score = valid.reduce(0) { $0 + $1.0 * $1.1 } / totalImportance
        return 0.6 + 1.4 * score
    }

    private static func featureAffinity(
        _ feature: TrackFeatureValues?,
        values: [(KeyPath<TrackFeatureValues, Double?>, Double)]
    ) -> Double {
        guard let feature else { return 0.5 }
        let valid = values.compactMap { keyPath, importance -> (Double, Double)? in
            guard let value = feature[keyPath: keyPath], value.isFinite, (0...1).contains(value) else { return nil }
            return (value, importance)
        }
        guard !valid.isEmpty else { return 0.5 }
        let totalImportance = valid.reduce(0) { $0 + $1.1 }
        return valid.reduce(0) { $0 + $1.0 * $1.1 } / totalImportance
    }

    private static func discoveryWeight(history: PlaybackHistory?, now: Date) -> Double {
        guard let history, history.playCount > 0 else { return 2 }
        let countWeight: Double = switch history.playCount {
        case 1: 1.7
        case 2...3: 1.45
        case 4...9: 1.2
        default: 1
        }
        guard let lastPlayedAt = history.lastPlayedAt else { return min(2, countWeight * 1.4) }
        let days = max(0, now.timeIntervalSince(lastPlayedAt) / 86_400)
        let recencyWeight: Double = if days >= 365 { 1.6 }
            else if days >= 90 { 1.4 }
            else if days >= 30 { 1.2 }
            else { 1 }
        return min(2, countWeight * recencyWeight)
    }
}
