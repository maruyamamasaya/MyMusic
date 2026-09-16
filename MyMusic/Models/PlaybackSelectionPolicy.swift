import Foundation

/// Centralizes derived behavior adjustments used only by automatic selection.
/// Eligibility remains the responsibility of the caller (including boredom and permanent hiding).
enum PlaybackSelectionPolicy {
    /// Keeps mild recent repetition close to neutral, then increasingly suppresses
    /// genuinely overplayed tracks without ever excluding them.
    static func overplayFactor(overplayScore: Double) -> Double {
        let score = bounded(overplayScore)
        return 1 - 0.875 * score * score
    }

    static func shuffleOverplayFactor(overplayScore: Double) -> Double {
        overplayFactor(overplayScore: overplayScore)
    }

    static func stationOverplayFactor(overplayScore: Double) -> Double {
        overplayFactor(overplayScore: overplayScore)
    }

    static func shuffleWeight(playbackPreference: Int, overplayScore: Double) -> Double {
        PlaybackPreferenceWeightPolicy.weight(for: playbackPreference)
            * shuffleOverplayFactor(overplayScore: overplayScore)
    }

    /// Quick Play alone favors less-played tracks, while keeping every track eligible.
    /// Use the stronger of this long-term adjustment and the temporary Overplay
    /// adjustment so a track is not suppressed twice for the same listening.
    static func quickPlayWeight(playbackPreference: Int, overplayScore: Double, playCount: Int) -> Double {
        PlaybackPreferenceWeightPolicy.weight(for: playbackPreference)
            * min(quickPlayCountFactor(playCount: playCount), shuffleOverplayFactor(overplayScore: overplayScore))
    }

    static func quickPlayCountFactor(playCount: Int) -> Double {
        switch playCount {
        case ...2: 1
        case 3...5: 0.7
        case 6...9: 0.4
        default: 0.1
        }
    }

    private static func bounded(_ score: Double) -> Double {
        guard score.isFinite else { return 0 }
        return min(max(score, 0), 1)
    }
}
