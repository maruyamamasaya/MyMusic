import Foundation

nonisolated enum VolumeNormalizationGain {
    static let allowedDecibels: ClosedRange<Double> = -4 ... 4

    static func clampedDecibels(_ decibels: Double?) -> Double {
        guard let decibels, decibels.isFinite else { return 0 }
        return min(max(decibels, allowedDecibels.lowerBound), allowedDecibels.upperBound)
    }

    static func linear(fromDecibels decibels: Double?) -> Double {
        pow(10, clampedDecibels(decibels) / 20)
    }
}
