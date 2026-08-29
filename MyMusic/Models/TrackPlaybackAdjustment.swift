import Foundation

nonisolated struct TrackPlaybackAdjustment: Codable, Equatable, Sendable {
    static let manualAdjustmentRange: ClosedRange<Double> = -2 ... 2
    static let manualAdjustmentStep = 0.5

    let trackID: Track.ID
    var lastPlaybackPosition: TimeInterval
    var customStartPosition: TimeInterval?
    var customEndPosition: TimeInterval?
    var manualNormalizationAdjustmentDB: Double
    var updatedAt: Date

    init(
        trackID: Track.ID,
        lastPlaybackPosition: TimeInterval = 0,
        customStartPosition: TimeInterval? = nil,
        customEndPosition: TimeInterval? = nil,
        manualNormalizationAdjustmentDB: Double = 0,
        updatedAt: Date = Date()
    ) {
        self.trackID = trackID
        self.lastPlaybackPosition = lastPlaybackPosition
        self.customStartPosition = customStartPosition
        self.customEndPosition = customEndPosition
        self.manualNormalizationAdjustmentDB = Self.normalizedManualAdjustment(manualNormalizationAdjustmentDB)
        self.updatedAt = updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trackID = try container.decode(Track.ID.self, forKey: .trackID)
        lastPlaybackPosition = try container.decodeIfPresent(TimeInterval.self, forKey: .lastPlaybackPosition) ?? 0
        customStartPosition = try container.decodeIfPresent(TimeInterval.self, forKey: .customStartPosition)
        customEndPosition = try container.decodeIfPresent(TimeInterval.self, forKey: .customEndPosition)
        manualNormalizationAdjustmentDB = Self.normalizedManualAdjustment(
            try container.decodeIfPresent(Double.self, forKey: .manualNormalizationAdjustmentDB) ?? 0
        )
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? .distantPast
    }

    func sanitized(for duration: TimeInterval) -> TrackPlaybackAdjustment {
        guard duration.isFinite, duration > 0 else {
            return TrackPlaybackAdjustment(
                trackID: trackID,
                manualNormalizationAdjustmentDB: manualNormalizationAdjustmentDB,
                updatedAt: updatedAt
            )
        }

        var result = self
        result.lastPlaybackPosition = Self.validPosition(lastPlaybackPosition, duration: duration) ?? 0
        result.customStartPosition = Self.validStart(customStartPosition, duration: duration)
        result.customEndPosition = Self.validEnd(customEndPosition, duration: duration)
        if let start = result.customStartPosition,
           let end = result.customEndPosition,
           start >= end {
            result.customStartPosition = nil
            result.customEndPosition = nil
        }
        result.manualNormalizationAdjustmentDB = Self.normalizedManualAdjustment(manualNormalizationAdjustmentDB)
        return result
    }

    static func normalizedManualAdjustment(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        let stepped = (value / manualAdjustmentStep).rounded() * manualAdjustmentStep
        return min(max(stepped, manualAdjustmentRange.lowerBound), manualAdjustmentRange.upperBound)
    }

    private static func validPosition(_ value: TimeInterval?, duration: TimeInterval) -> TimeInterval? {
        guard let value, value.isFinite, value >= 0, value <= duration else { return nil }
        return value
    }

    private static func validStart(_ value: TimeInterval?, duration: TimeInterval) -> TimeInterval? {
        guard let value = validPosition(value, duration: duration), value < duration else { return nil }
        return value
    }

    private static func validEnd(_ value: TimeInterval?, duration: TimeInterval) -> TimeInterval? {
        guard let value = validPosition(value, duration: duration), value > 0 else { return nil }
        return value
    }
}
