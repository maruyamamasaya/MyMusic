import Foundation

enum PlaybackHistoryScoring {
    static let fullPlaybackRatio: Double = 0.94
    static let minimumListenedSecondsForCompletion: TimeInterval = 3
    static let skipThresholdRatio: Double = 0.92
    static let minimumSkippableSeconds: TimeInterval = 5

    static func isFullPlayback(
        duration: TimeInterval,
        listenedSeconds: TimeInterval
    ) -> Bool {
        guard duration > 0 else { return false }
        let minimumSeconds = max(minimumListenedSecondsForCompletion, duration * fullPlaybackRatio)
        return listenedSeconds >= minimumSeconds
    }

    static func isSkip(
        duration: TimeInterval,
        listenedSeconds: TimeInterval,
        isNaturallyCompleted: Bool
    ) -> Bool {
        guard !isNaturallyCompleted else { return false }
        guard duration > 0 else { return false }
        guard listenedSeconds >= minimumSkippableSeconds else { return false }
        let skipThreshold = duration * skipThresholdRatio
        return listenedSeconds < skipThreshold
    }

    static func skipRate(fullPlaybackCount: Int, skipCount: Int) -> Double {
        let total = fullPlaybackCount + skipCount
        guard total > 0 else { return 0 }
        return Double(skipCount) / Double(total)
    }

    static func completionRate(fullPlaybackCount: Int, skipCount: Int) -> Double {
        let total = fullPlaybackCount + skipCount
        guard total > 0 else { return 0 }
        return Double(fullPlaybackCount) / Double(total)
    }
}

