import Foundation

/// Centralizes derived behavior adjustments used only by automatic selection.
/// Eligibility remains the responsibility of the caller (including boredom and permanent hiding).
enum PlaybackSelectionPolicy {
    static func shuffleOverplayFactor(overplayScore: Double) -> Double {
        1 - 0.50 * bounded(overplayScore)
    }

    static func stationOverplayFactor(overplayScore: Double) -> Double {
        1 - 0.20 * bounded(overplayScore)
    }

    static func shuffleWeight(playbackPreference: Int, overplayScore: Double) -> Double {
        PlaybackPreferenceWeightPolicy.weight(for: playbackPreference)
            * shuffleOverplayFactor(overplayScore: overplayScore)
    }

    private static func bounded(_ score: Double) -> Double {
        guard score.isFinite else { return 0 }
        return min(max(score, 0), 1)
    }
}
