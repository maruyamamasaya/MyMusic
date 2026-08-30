import Foundation

/// Selection uses imported features only; it never reads or changes the audio source.
nonisolated struct MoodStationService: Sendable {
    func hasUsableFeatures(_ values: TrackFeatureValues) -> Bool {
        ["energy", "calm", "aggressive", "bright", "dark", "ambient", "electronic",
         "drumAndBass", "vocal", "instrumental"].contains { validScore($0, in: values) != nil }
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

    func availableDecades(in candidates: [StationCandidate]) -> [StationDecade] {
        Array(Set(candidates.compactMap { candidate in
            candidate.year.flatMap(StationDecade.init(year:))
        })).sorted { $0.startYear > $1.startYear }
    }

    func followUp(for answers: StationAnswers, candidates: [StationCandidate]) -> StationRefinement? {
        guard answers.mood != .surprise else { return nil }
        // Ask only when the relevant pool actually has a measurable difference.
        let pool = candidates.filter { (score($0.values, for: answers) ?? 0) >= 0.6 }
        let preferred: [StationRefinement]
        switch answers.mood {
        case .focus, .immerse: preferred = [.vocals, .texture, .intensity]
        case .uplift, .stimulate: preferred = [.intensity, .texture, .vocals]
        case .relax: preferred = answers.sound == .heavy || answers.sound == .rhythmic
            ? [.intensity, .vocals, .texture] : [.texture, .vocals, .intensity]
        case .surprise: return nil
        }
        return preferred.first { refinement in
            let values = pool.compactMap { candidate -> Double? in
                switch refinement {
                case .vocals: return validScore("vocal", in: candidate.values)
                case .texture: return validScore("electronic", in: candidate.values)
                case .intensity: return validScore("aggressive", in: candidate.values)
                }
            }
            guard values.count >= 2, values.count * 2 >= pool.count,
                  let low = values.min(), let high = values.max() else { return false }
            return high - low >= 0.15
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
        let periodCandidates = unique.filter { candidate in
            answers.decade?.contains(candidate.year) ?? true
        }
        let ranked = periodCandidates.compactMap { candidate -> (candidate: StationCandidate, score: Double)? in
            guard let score = score(candidate.values, for: answers), score >= 0.6 else { return nil }
            return (candidate, score)
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
            analyzedTrackCount: periodCandidates.count, matchingTrackCount: ranked.count
        )

        func adjusted(_ item: (StationCandidate, Double)) -> Double {
            guard !item.0.artist.isEmpty else { return item.1 }
            return item.1 - Double(artistCounts[item.0.artist, default: 0]) * 0.035
                - (previousArtist == item.0.artist ? 0.12 : 0)
        }
    }

    func score(_ values: TrackFeatureValues, for answers: StationAnswers) -> Double? {
        let targets = targets(for: answers)
        let totalWeight = targets.reduce(0) { $0 + $1.weight }
        var availableWeight = 0.0
        var similarity = 0.0
        for target in targets {
            guard let value = validScore(target.key, in: values) else { continue }
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

    private func targets(for answers: StationAnswers) -> [Target] {
        var result: [Target]
        switch answers.mood {
        case .relax: result = [Target("calm", 0.9, 2), Target("energy", 0.2), Target("aggressive", 0.1)]
        case .uplift: result = [Target("energy", 0.8, 2), Target("bright", 0.8), Target("dark", 0.2)]
        case .focus: result = [Target("calm", 0.8, 2), Target("instrumental", 0.85), Target("energy", 0.35)]
        case .immerse: result = [Target("ambient", 0.75), Target("dark", 0.7), Target("energy", 0.35)]
        case .stimulate: result = [Target("energy", 0.9, 2), Target("aggressive", 0.8), Target("electronic", 0.7)]
        case .surprise: result = []
        }
        switch answers.sound {
        case .soft: result += [Target("calm", 0.9, 2), Target("energy", 0.15, 2), Target("aggressive", 0.1)]
        case .light: result += [Target("energy", 0.4, 2), Target("calm", 0.65), Target("bright", 0.65)]
        case .rhythmic: result += [Target("energy", 0.7, 2), Target("electronic", 0.65), Target("drumAndBass", 0.65)]
        case .heavy: result += [Target("aggressive", 0.9, 2), Target("energy", 0.85, 2), Target("dark", 0.65)]
        case .bright: result += [Target("bright", 0.9, 2), Target("dark", 0.1), Target("energy", 0.65, 2)]
        case .dark: result += [Target("dark", 0.9, 2), Target("bright", 0.15), Target("ambient", 0.65)]
        }
        if let refinement = answers.refinement, let direction = answers.direction {
            let first = direction == .first
            switch refinement {
            case .vocals:
                // An explicit final answer takes precedence over the focus default.
                result.removeAll { $0.key == "vocal" || $0.key == "instrumental" }
                result += [Target("vocal", first ? 0.9 : 0.1, 3), Target("instrumental", first ? 0.1 : 0.9, 3)]
            case .texture:
                result.removeAll { $0.key == "electronic" }
                result += [Target("electronic", first ? 0.1 : 0.9, 3)]
            case .intensity:
                result.removeAll { $0.key == "aggressive" || $0.key == "calm" }
                result += [Target("calm", first ? 0.9 : 0.1, 3), Target("aggressive", first ? 0.1 : 0.9, 3)]
            }
        }
        return result
    }
}
