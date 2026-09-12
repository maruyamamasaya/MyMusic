import Foundation

/// Selection uses imported features only; it never reads or changes the audio source.
nonisolated struct MoodStationService: Sendable {
    private static let selectionThreshold = 0.72

    func hasUsableFeatures(_ values: TrackFeatureValues) -> Bool {
        ["energy", "calm", "aggressive", "dark", "ambient", "electronic",
         "vocal", "instrumental", "piano"].contains { validScore($0, in: values) != nil }
    }

    private struct Target {
        let key: String
        let value: Double
        let weight: Double
        init(_ key: String, _ value: Double, _ weight: Double = 1) {
            self.key = key
            self.value = value
            self.weight = weight
        }
    }

    func availableMoods(in candidates: [StationCandidate]) -> [StationMood] {
        let distributions = distributions(for: candidates)
        return StationMood.allCases.filter { mood in
            mood == .surprise || candidates.contains { candidate in
                (score(candidate.values, for: StationAnswers(mood: mood, sound: .any),
                       distributions: distributions) ?? 0) >= Self.selectionThreshold
            }
        }
    }

    func availableSounds(in candidates: [StationCandidate]) -> [StationSound] {
        [.any] + StationSound.allCases.dropFirst().filter { sound in
            guard let key = sound.featureKey else { return false }
            let values = candidates.compactMap { validScore(key, in: $0.values) }
            guard values.count >= 2, values.count * 2 >= candidates.count,
                  let low = values.min(), let high = values.max() else { return false }
            return high - low >= sound.minimumUsefulRange
        }
    }

    func makeStation<R: RandomNumberGenerator>(
        answers: StationAnswers,
        candidates: [StationCandidate],
        limit: Int = 25,
        using generator: inout R
    ) -> MoodStation {
        var seen: Set<Track.ID> = []
        let unique = candidates.filter { seen.insert($0.trackID).inserted }
        let distributions = distributions(for: unique)
        let ranked = unique.compactMap { candidate -> (candidate: StationCandidate, score: Double)? in
            guard let score = score(candidate.values, for: answers, distributions: distributions),
                  score >= Self.selectionThreshold else { return nil }
            return (candidate, score * candidate.overplayFactor)
        }
        // Small jitter varies close matches without allowing unrelated tracks into the pool.
        var remaining = ranked.map { ($0.candidate, $0.score + Double.random(in: 0...0.08, using: &generator)) }
            .sorted { $0.1 > $1.1 }
        var selected: [Track.ID] = []
        var artistCounts: [String: Int] = [:]
        var previousArtist: String?
        while !remaining.isEmpty && selected.count < max(0, limit) {
            let index = remaining.indices.max { lhs, rhs in
                adjusted(remaining[lhs]) < adjusted(remaining[rhs])
            }!
            let candidate = remaining.remove(at: index).0
            selected.append(candidate.trackID)
            artistCounts[candidate.artist, default: 0] += 1
            previousArtist = candidate.artist
        }
        return MoodStation(
            id: UUID(), answers: answers, trackIDs: selected,
            analyzedTrackCount: unique.count, matchingTrackCount: ranked.count
        )

        func adjusted(_ item: (StationCandidate, Double)) -> Double {
            guard !item.0.artist.isEmpty else { return item.1 }
            return item.1 - Double(artistCounts[item.0.artist, default: 0]) * 0.035
                - (previousArtist == item.0.artist ? 0.12 : 0)
        }
    }

    func score(_ candidate: StationCandidate, for answers: StationAnswers,
               among candidates: [StationCandidate]) -> Double? {
        score(candidate.values, for: answers, distributions: distributions(for: candidates))
    }

    private func score(_ values: TrackFeatureValues, for answers: StationAnswers,
                       distributions: [String: [Double]]) -> Double? {
        if let soundKey = answers.sound.featureKey,
           validScore(soundKey, in: values) == nil { return nil }
        let targets = targets(for: answers)
        // 「おまかせ」は特徴量を条件にせず、通常再生対象の解析済み曲を均等に候補化する。
        if targets.isEmpty { return 0.75 }
        let totalWeight = targets.reduce(0) { $0 + $1.weight }
        var availableWeight = 0.0
        var similarity = 0.0
        for target in targets {
            guard let rawValue = validScore(target.key, in: values),
                  let distribution = distributions[target.key],
                  let value = percentile(of: rawValue, in: distribution) else { continue }
            availableWeight += target.weight
            similarity += (1 - abs(value - target.value)) * target.weight
        }
        // A missing feature is unknown, never a zero or evidence for the opposite label.
        guard totalWeight > 0, availableWeight >= totalWeight * 0.5 else { return nil }
        let coverage = availableWeight / totalWeight
        return similarity / availableWeight - (1 - coverage) * 0.1
    }

    private func validScore(_ key: String, in values: TrackFeatureValues) -> Double? {
        guard let score = values.score(named: key), score.isFinite, (0...1).contains(score) else { return nil }
        return score
    }

    private func distributions(for candidates: [StationCandidate]) -> [String: [Double]] {
        let keys = ["energy", "calm", "aggressive", "dark", "ambient", "electronic",
                    "vocal", "instrumental", "piano"]
        return Dictionary(uniqueKeysWithValues: keys.compactMap { key in
            let values = candidates.compactMap { validScore(key, in: $0.values) }.sorted()
            guard values.count >= 2, let first = values.first, let last = values.last,
                  last - first >= minimumUsefulRange(for: key) else { return nil }
            return (key, values)
        })
    }

    private func minimumUsefulRange(for key: String) -> Double {
        switch key {
        case "vocal", "instrumental": 0.1
        case "aggressive", "ambient": 0.03
        case "dark": 0.02
        default: 0.05
        }
    }

    /// Raw semantic heads are not calibrated probabilities and have very different ranges.
    /// Mid-rank percentiles preserve their ordering while tuning selection to the imported library.
    private func percentile(of value: Double, in sorted: [Double]) -> Double? {
        guard !sorted.isEmpty else { return nil }
        guard sorted.count > 1 else { return 0.5 }
        let lower = sorted.partitioningIndex { $0 >= value }
        let upper = sorted.partitioningIndex { $0 > value }
        return Double(lower + upper - 1) / 2 / Double(sorted.count - 1)
    }

    private func targets(for answers: StationAnswers) -> [Target] {
        var result: [Target]
        switch answers.mood {
        case .relax: result = [Target("calm", 0.85, 2), Target("aggressive", 0.15, 2), Target("energy", 0.25)]
        case .uplift: result = [Target("calm", 0.65), Target("aggressive", 0.35), Target("energy", 0.75, 2)]
        case .focus: result = [Target("calm", 0.8, 2), Target("aggressive", 0.2), Target("ambient", 0.55)]
        case .immerse: result = [Target("ambient", 0.85, 2), Target("calm", 0.7), Target("dark", 0.75)]
        case .stimulate: result = [Target("aggressive", 0.85, 2), Target("calm", 0.15, 2), Target("energy", 0.85)]
        case .surprise: result = []
        }
        switch answers.sound {
        case .any: break
        case .vocals: result += [Target("vocal", 0.85, 3)]
        case .instrumental: result += [Target("instrumental", 0.85, 3)]
        case .electronic: result += [Target("electronic", 0.85, 3)]
        case .ambient: result += [Target("ambient", 0.85, 3)]
        case .piano: result += [Target("piano", 0.85, 3)]
        }
        return result
    }
}

private extension Array where Element == Double {
    nonisolated func partitioningIndex(where predicate: (Double) -> Bool) -> Int {
        var low = startIndex
        var high = endIndex
        while low < high {
            let middle = low + (high - low) / 2
            if predicate(self[middle]) { high = middle } else { low = middle + 1 }
        }
        return low
    }
}

private extension StationSound {
    nonisolated var featureKey: String? {
        switch self {
        case .any: nil
        case .vocals: "vocal"
        case .instrumental: "instrumental"
        case .electronic: "electronic"
        case .ambient: "ambient"
        case .piano: "piano"
        }
    }

    nonisolated var minimumUsefulRange: Double {
        switch self {
        case .any: 0
        case .vocals, .instrumental: 0.1
        case .electronic, .piano: 0.05
        case .ambient: 0.03
        }
    }
}
