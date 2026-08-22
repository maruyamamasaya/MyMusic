import Foundation

@MainActor
final class PlaybackTransitionService {
    private(set) var settings: PlaybackTransitionSettings

    private let setOutputVolume: (Float) -> Void
    private var currentVolume: Float = 1
    private var activeRampID = UUID()

    init(
        settings: PlaybackTransitionSettings = .preservingExistingPlayback,
        setOutputVolume: @escaping (Float) -> Void
    ) {
        var normalizedSettings = settings
        normalizedSettings.normalize()
        self.settings = normalizedSettings
        self.setOutputVolume = setOutputVolume
    }

    func apply(_ settings: PlaybackTransitionSettings) {
        var normalizedSettings = settings
        normalizedSettings.normalize()
        self.settings = normalizedSettings
        cancelActiveRamp(resetVolume: true)
    }

    func prepareFadeIn(for reason: PlaybackTransitionReason) {
        cancelActiveRamp(resetVolume: false)
        setVolume(settings.fadeInDuration(for: reason) > 0 ? 0 : 1)
    }

    func fadeIn(for reason: PlaybackTransitionReason) async throws {
        try await ramp(to: 1, duration: settings.fadeInDuration(for: reason))
    }

    func fadeOut(for reason: PlaybackTransitionReason) async throws {
        let duration = settings.fadeOutDuration(for: reason)
        guard duration > 0 else { return }
        try await ramp(to: 0, duration: duration)
    }

    /// Silences the current render path before a node is stopped or rescheduled.
    /// Even with fade-out disabled, a very short ramp avoids cutting a waveform
    /// at full amplitude while keeping user-initiated transitions responsive.
    func silenceBeforeDiscontinuity(for reason: PlaybackTransitionReason) async throws {
        let configuredDuration = settings.fadeOutDuration(for: reason)
        let duration = configuredDuration > 0 ? configuredDuration : 0.03
        try await ramp(to: 0, duration: duration)
    }

    func cancelActiveRamp(resetVolume: Bool) {
        activeRampID = UUID()
        if resetVolume { setVolume(1) }
    }

    private func ramp(to targetVolume: Float, duration: TimeInterval) async throws {
        activeRampID = UUID()
        let rampID = activeRampID
        let startVolume = currentVolume

        guard duration > 0, startVolume != targetVolume else {
            setVolume(targetVolume)
            return
        }

        let startTime = ProcessInfo.processInfo.systemUptime
        while true {
            try Task.checkCancellation()
            guard activeRampID == rampID else { return }

            let elapsed = ProcessInfo.processInfo.systemUptime - startTime
            let progress = min(max(elapsed / duration, 0), 1)
            // Smoothstep eases the gain slope at both ends and the shorter
            // cadence keeps short highlight transitions from sounding stepped.
            let easedProgress = progress * progress * (3 - (2 * progress))
            let value = startVolume + ((targetVolume - startVolume) * Float(easedProgress))
            setVolume(value)

            if progress >= 1 { return }
            try await Task.sleep(for: .milliseconds(5))
        }
    }

    private func setVolume(_ volume: Float) {
        let clampedVolume = min(max(volume, 0), 1)
        currentVolume = clampedVolume
        setOutputVolume(clampedVolume)
    }
}
