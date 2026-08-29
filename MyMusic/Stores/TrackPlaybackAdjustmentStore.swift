import Foundation
import Observation

@MainActor
@Observable
final class TrackPlaybackAdjustmentStore {
    private(set) var errorMessage: String?

    private var adjustments: [Track.ID: TrackPlaybackAdjustment] = [:]
    private var loadedTrackIDs: Set<Track.ID> = []
    private let persistence: TrackPlaybackAdjustmentPersistenceServicing

    init(persistence: TrackPlaybackAdjustmentPersistenceServicing? = nil) {
        self.persistence = persistence ?? TrackPlaybackAdjustmentPersistenceService()
    }

    func adjustment(for trackID: Track.ID) -> TrackPlaybackAdjustment {
        adjustments[trackID] ?? TrackPlaybackAdjustment(trackID: trackID)
    }

    @discardableResult
    func load(for trackID: Track.ID, duration: TimeInterval) async -> TrackPlaybackAdjustment {
        if loadedTrackIDs.contains(trackID) {
            let current = adjustment(for: trackID)
            let sanitized = current.sanitized(for: duration)
            if sanitized != current {
                adjustments[trackID] = sanitized
                do {
                    try await persistence.save(sanitized)
                } catch {
                    errorMessage = "曲別の再生設定を保存できませんでした: \(error.localizedDescription)"
                }
            }
            return sanitized
        }

        do {
            let loaded = try await persistence.load(trackID: trackID)
            let sanitized = (loaded ?? TrackPlaybackAdjustment(trackID: trackID)).sanitized(for: duration)
            adjustments[trackID] = sanitized
            loadedTrackIDs.insert(trackID)
            if let loaded, sanitized != loaded {
                try await persistence.save(sanitized)
            }
            return sanitized
        } catch {
            loadedTrackIDs.insert(trackID)
            errorMessage = "曲別の再生設定を読み込めませんでした: \(error.localizedDescription)"
            return adjustment(for: trackID).sanitized(for: duration)
        }
    }

    @discardableResult
    func setCustomStart(
        trackID: Track.ID,
        position: TimeInterval?,
        duration: TimeInterval
    ) async -> Bool {
        var value = await load(for: trackID, duration: duration)
        if let position {
            guard position.isFinite, position >= 0, position < duration,
                  value.customEndPosition.map({ position < $0 }) ?? true else { return false }
            value.customStartPosition = position
        } else {
            value.customStartPosition = nil
        }
        await update(value)
        return true
    }

    @discardableResult
    func setCustomEnd(
        trackID: Track.ID,
        position: TimeInterval?,
        duration: TimeInterval
    ) async -> Bool {
        var value = await load(for: trackID, duration: duration)
        if let position {
            guard position.isFinite, position > 0, position <= duration,
                  value.customStartPosition.map({ $0 < position }) ?? true else { return false }
            value.customEndPosition = position
        } else {
            value.customEndPosition = nil
        }
        await update(value)
        return true
    }

    func setManualNormalizationAdjustment(
        trackID: Track.ID,
        decibels: Double,
        duration: TimeInterval
    ) async {
        var value = await load(for: trackID, duration: duration)
        value.manualNormalizationAdjustmentDB = TrackPlaybackAdjustment.normalizedManualAdjustment(decibels)
        await update(value)
    }

    func setLastPlaybackPosition(
        trackID: Track.ID,
        position: TimeInterval,
        duration: TimeInterval
    ) async {
        var value = await load(for: trackID, duration: duration)
        value.lastPlaybackPosition = min(max(position.isFinite ? position : 0, 0), max(duration, 0))
        await update(value)
    }

    func dismissError() {
        errorMessage = nil
    }

    private func update(_ adjustment: TrackPlaybackAdjustment) async {
        var value = adjustment
        value.updatedAt = Date()
        adjustments[value.trackID] = value
        do {
            try await persistence.save(value)
        } catch {
            errorMessage = "曲別の再生設定を保存できませんでした: \(error.localizedDescription)"
        }
    }
}
