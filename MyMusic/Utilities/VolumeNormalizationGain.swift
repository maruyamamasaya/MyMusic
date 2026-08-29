import Foundation

nonisolated enum VolumeNormalizationGain {
    static let allowedDecibels: ClosedRange<Double> = -4 ... 4
    static let truePeakCeilingDBTP = -1.0

    static func clampedDecibels(_ decibels: Double?) -> Double {
        guard let decibels, decibels.isFinite else { return 0 }
        return min(max(decibels, allowedDecibels.lowerBound), allowedDecibels.upperBound)
    }

    static func linear(fromDecibels decibels: Double?) -> Double {
        pow(10, clampedDecibels(decibels) / 20)
    }

    static func finalDecibels(
        automaticGainDB: Double?,
        manualAdjustmentDB: Double,
        truePeakDBTP: Double?
    ) -> Double {
        let automatic = automaticGainDB.flatMap { $0.isFinite ? $0 : nil } ?? 0
        let manual = TrackPlaybackAdjustment.normalizedManualAdjustment(manualAdjustmentDB)
        var result = min(
            max(automatic + manual, allowedDecibels.lowerBound),
            allowedDecibels.upperBound
        )
        if let truePeakDBTP, truePeakDBTP.isFinite {
            result = min(result, truePeakCeilingDBTP - truePeakDBTP)
        }
        return min(max(result, allowedDecibels.lowerBound), allowedDecibels.upperBound)
    }
}

nonisolated struct TrackNormalizationMetadata: Sendable, Equatable {
    let automaticGainDB: Double?
    let truePeakDBTP: Double?
}
