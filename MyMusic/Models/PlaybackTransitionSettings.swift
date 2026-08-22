import Foundation

enum PlaybackTransitionType: String, Codable, Sendable {
    case none
    case fade
    case crossfade
}

enum ManualTrackTransitionPolicy: String, Codable, Sendable {
    case allTrackChanges
    case automaticOnly
}

enum PlaybackTransitionReason: Equatable, Sendable {
    case initialPlayback
    case automaticTrackChange
    case manualTrackChange
    case highlightAutomatic
    case highlightUserInitiated
}

struct PlaybackTransitionSettings: Codable, Equatable, Sendable {
    nonisolated static let selectableDurations: [TimeInterval] = [0.5, 1, 1.5, 2, 3, 5]

    var type: PlaybackTransitionType
    var fadeInEnabled: Bool
    var fadeInDuration: TimeInterval
    var fadeOutEnabled: Bool
    var fadeOutDuration: TimeInterval
    var manualTrackTransitionPolicy: ManualTrackTransitionPolicy

    nonisolated static let preservingExistingPlayback = PlaybackTransitionSettings(
        type: .fade,
        fadeInEnabled: false,
        fadeInDuration: 1,
        fadeOutEnabled: false,
        fadeOutDuration: 1.5,
        manualTrackTransitionPolicy: .allTrackChanges
    )

    mutating func normalize() {
        fadeInDuration = Self.normalizedDuration(fadeInDuration, fallback: 1)
        fadeOutDuration = Self.normalizedDuration(fadeOutDuration, fallback: 1.5)
    }

    func fadeInDuration(for reason: PlaybackTransitionReason) -> TimeInterval {
        guard type != .none, fadeInEnabled else { return 0 }
        switch reason {
        case .highlightUserInitiated:
            return min(fadeInDuration, 0.35)
        case .initialPlayback, .automaticTrackChange, .manualTrackChange, .highlightAutomatic:
            return fadeInDuration
        }
    }

    func fadeOutDuration(for reason: PlaybackTransitionReason) -> TimeInterval {
        guard type != .none, fadeOutEnabled else { return 0 }
        if reason == .manualTrackChange, manualTrackTransitionPolicy == .automaticOnly {
            return 0
        }
        if reason == .highlightUserInitiated {
            return min(fadeOutDuration, 0.35)
        }
        return fadeOutDuration
    }

    private static func normalizedDuration(_ duration: TimeInterval, fallback: TimeInterval) -> TimeInterval {
        guard duration.isFinite else { return fallback }
        return min(max(duration, 0), 10)
    }
}
