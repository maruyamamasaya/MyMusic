import Foundation

/// Beta cutoff on the raw ambient tag score, not a calibrated probability.
nonisolated enum AmbientSelectionPolicy {
    static let minimumScore = 0.5

    static func includes(_ score: Double?) -> Bool {
        guard let score, score.isFinite, (0...1).contains(score) else { return false }
        return score >= minimumScore
    }

    static func candidates(from tracks: [Track], features: [Track.ID: TrackFeature]) -> [Track] {
        var seen = Set<Track.ID>()
        return tracks.filter {
            seen.insert($0.id).inserted && includes(features[$0.id]?.values.ambient)
        }
    }
}
