import Foundation

/// Converts the user's durable Good / Bad value into a selection weight.
/// Boredom and permanent hiding remain separate eligibility decisions.
enum PlaybackPreferenceWeightPolicy {
    static let minimumPreference = -10
    static let maximumPreference = 10

    private static let weights: [Double] = [
        0.01, 0.015, 0.02, 0.03, 0.05, 0.08, 0.12, 0.20, 0.35, 0.60,
        1.00,
        1.8, 3.2, 5.5, 8.5, 12, 16, 21, 27, 34, 42
    ]

    static func weight(for preference: Int) -> Double {
        let boundedPreference = min(max(preference, minimumPreference), maximumPreference)
        return weights[boundedPreference - minimumPreference]
    }
}
