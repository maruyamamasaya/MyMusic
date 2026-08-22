import AVFoundation
import Foundation

enum AudioPlaybackEvent {
    case ready(duration: TimeInterval)
    case timeChanged(TimeInterval)
    case playingChanged(Bool)
    case ended
    case failed(String)
    case interruptionBegan
    case interruptionEnded(shouldResume: Bool)
    case oldAudioDeviceUnavailable
}

enum AudioPlayerServiceError: LocalizedError {
    case fileUnavailable
    case accessDenied
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .fileUnavailable: "The audio file is unavailable. It may not be downloaded from iCloud."
        case .accessDenied: "MyMusic no longer has permission to access this audio file."
        case .unsupportedFormat: "This audio file cannot be played by AVFoundation."
        }
    }
}

@MainActor
protocol AudioPlayerServicing: AnyObject {
    var eventHandler: ((AudioPlaybackEvent) -> Void)? { get set }
    func play(_ track: Track) async throws
    func pause()
    func resume() async throws
    func seek(to time: TimeInterval)
    func stop()
}

@MainActor
protocol PlaybackTransitionAudioControlling: AnyObject {
    func play(_ track: Track, transition: PlaybackTransitionReason) async throws
    func play(
        _ track: Track,
        startingAt playbackTime: TimeInterval,
        endingAt playbackEndTime: TimeInterval?,
        transition: PlaybackTransitionReason
    ) async throws
    func seek(to time: TimeInterval, transition: PlaybackTransitionReason) async throws
    func seek(
        to time: TimeInterval,
        endingAt playbackEndTime: TimeInterval?,
        transition: PlaybackTransitionReason
    ) async throws
    func scheduleFadeOut(endingAt playbackTime: TimeInterval, reason: PlaybackTransitionReason)
}

@MainActor
protocol PlaybackTransitionControlling: AnyObject {
    func applyPlaybackTransition(_ settings: PlaybackTransitionSettings)
}

@MainActor
protocol EqualizerControlling: AnyObject {
    var spectrumHandler: (([Float]) -> Void)? { get set }
    func applyEqualizer(_ settings: EqualizerSettings)
}

@MainActor
final class AudioPlayerService: AudioPlayerServicing, PlaybackTransitionAudioControlling, PlaybackTransitionControlling, EqualizerControlling {
    var eventHandler: ((AudioPlaybackEvent) -> Void)?
    var spectrumHandler: (([Float]) -> Void)?

    private let fileImportService: FileImportServicing
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private let transitionMixer = AVAudioMixerNode()
    private let equalizer = AVAudioUnitEQ(numberOfBands: EqualizerSettings.frequencies.count)
    private var audioFile: AVAudioFile?
    private var currentTrack: Track?
    private var playbackTimer: Timer?
    private var scheduledFadeOutTask: Task<Void, Never>?
    private var fadeOutBoundary: (endTime: TimeInterval, reason: PlaybackTransitionReason)?
    private var audioSessionNotificationTokens: [NSObjectProtocol] = []
    private var accessedURL: URL?
    private var isAccessingSecurityScope = false
    private var scheduledStartFrame: AVAudioFramePosition = 0
    private var scheduledLength: AVAudioFramePosition = 0
    private var pausedFrame: AVAudioFramePosition = 0
    private var scheduleID = UUID()
    private var equalizerSettings = EqualizerSettings.flat
    private var isSpectrumTapInstalled = false
    private lazy var playbackTransitionService = PlaybackTransitionService { [weak self] volume in
        self?.transitionMixer.outputVolume = volume
    }

    init(fileImportService: FileImportServicing? = nil) {
        self.fileImportService = fileImportService ?? FileImportService()
        engine.attach(playerNode)
        engine.attach(transitionMixer)
        engine.attach(equalizer)
        configureEqualizerBands()
        applyEqualizer(equalizerSettings)
        observeAudioSession()
    }

    isolated deinit {
        playbackTimer?.invalidate()
        scheduledFadeOutTask?.cancel()
        if isSpectrumTapInstalled { engine.mainMixerNode.removeTap(onBus: 0) }
        audioSessionNotificationTokens.forEach(NotificationCenter.default.removeObserver)
        if isAccessingSecurityScope { accessedURL?.stopAccessingSecurityScopedResource() }
    }

    func play(_ track: Track) async throws {
        try await play(track, transition: .initialPlayback)
    }

    func play(_ track: Track, transition reason: PlaybackTransitionReason) async throws {
        try await play(track, startingAt: 0, endingAt: nil, transition: reason)
    }

    func play(
        _ track: Track,
        startingAt playbackTime: TimeInterval,
        endingAt playbackEndTime: TimeInterval?,
        transition reason: PlaybackTransitionReason
    ) async throws {
        cancelScheduledFadeOut(clearBoundary: false)
        if playerNode.isPlaying {
            try await playbackTransitionService.silenceBeforeDiscontinuity(for: reason)
            try await waitForSilentRenderCycle()
        }
        try Task.checkCancellation()

        stopPlayback(clearTrack: false)
        currentTrack = track
        try beginFileAccess(for: track.fileURL)

        do {
            guard FileManager.default.fileExists(atPath: track.fileURL.path) else {
                throw AudioPlayerServiceError.fileUnavailable
            }

            try configureAudioSession()
            let file: AVAudioFile
            do {
                file = try AVAudioFile(forReading: track.fileURL)
            } catch {
                throw AudioPlayerServiceError.unsupportedFormat
            }
            audioFile = file
            try configureGraph(for: file.processingFormat)
            let seconds = Double(file.length) / file.processingFormat.sampleRate
            let resolvedDuration = seconds.isFinite ? seconds : max(track.duration, 0)
            let clampedStartTime = min(max(playbackTime, 0), resolvedDuration)
            let startFrame = AVAudioFramePosition(clampedStartTime * file.processingFormat.sampleRate)
            schedule(from: startFrame)
            installSpectrumTapIfNeeded()
            // Establish a silent gain before the engine renders the first
            // buffer. Starting at unity and lowering it after engine.start()
            // can expose a transient at a track boundary.
            playbackTransitionService.prepareFadeIn(for: reason)
            engine.prepare()
            if !engine.isRunning { try engine.start() }

            eventHandler?(.ready(duration: resolvedDuration))
            eventHandler?(.timeChanged(clampedStartTime))
            if let playbackEndTime {
                fadeOutBoundary = (
                    min(max(playbackEndTime, clampedStartTime), resolvedDuration),
                    .highlightAutomatic
                )
            } else {
                fadeOutBoundary = (resolvedDuration, .automaticTrackChange)
            }
            playerNode.play()
            startPlaybackTimer()
            rescheduleFadeOut()
            eventHandler?(.playingChanged(true))
            try await playbackTransitionService.fadeIn(for: reason)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            stopPlayback(clearTrack: false)
            throw error
        }
    }

    func pause() {
        guard playerNode.isPlaying else { return }
        cancelScheduledFadeOut(clearBoundary: false)
        playbackTransitionService.cancelActiveRamp(resetVolume: false)
        pausedFrame = currentFrame()
        playerNode.pause()
        playbackTransitionService.cancelActiveRamp(resetVolume: true)
        spectrumHandler?(Self.silentSpectrum)
        eventHandler?(.playingChanged(false))
    }

    func resume() async throws {
        guard audioFile != nil, let currentTrack else { return }
        if !isAccessingSecurityScope { try beginFileAccess(for: currentTrack.fileURL) }
        if pausedFrame >= scheduledLength {
            schedule(from: 0)
            eventHandler?(.timeChanged(0))
        }
        if !engine.isRunning { try engine.start() }
        playbackTransitionService.cancelActiveRamp(resetVolume: true)
        playerNode.play()
        startPlaybackTimer()
        rescheduleFadeOut()
        eventHandler?(.playingChanged(true))
    }

    func seek(to time: TimeInterval) {
        cancelScheduledFadeOut(clearBoundary: false)
        playbackTransitionService.cancelActiveRamp(resetVolume: true)
        seekImmediately(to: time)
        rescheduleFadeOut()
    }

    func seek(to time: TimeInterval, transition reason: PlaybackTransitionReason) async throws {
        try await seek(to: time, endingAt: nil, transition: reason)
    }

    func seek(
        to time: TimeInterval,
        endingAt playbackEndTime: TimeInterval?,
        transition reason: PlaybackTransitionReason
    ) async throws {
        guard audioFile != nil else { return }
        cancelScheduledFadeOut(clearBoundary: false)
        let wasPlaying = playerNode.isPlaying
        if wasPlaying {
            try await playbackTransitionService.silenceBeforeDiscontinuity(for: reason)
            try await waitForSilentRenderCycle()
        }
        try Task.checkCancellation()

        if wasPlaying { playbackTransitionService.prepareFadeIn(for: reason) }
        seekImmediately(to: time)
        if let playbackEndTime, let audioFile {
            let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
            fadeOutBoundary = (min(max(playbackEndTime, time), duration), .highlightAutomatic)
        }
        rescheduleFadeOut()
        if wasPlaying, playerNode.isPlaying {
            try await playbackTransitionService.fadeIn(for: reason)
        }
    }

    func scheduleFadeOut(endingAt playbackTime: TimeInterval, reason: PlaybackTransitionReason) {
        guard playbackTime.isFinite else { return }
        fadeOutBoundary = (max(playbackTime, 0), reason)
        rescheduleFadeOut()
    }

    func applyPlaybackTransition(_ settings: PlaybackTransitionSettings) {
        cancelScheduledFadeOut(clearBoundary: false)
        playbackTransitionService.apply(settings)
        rescheduleFadeOut()
    }

    private func seekImmediately(to time: TimeInterval) {
        guard let audioFile else { return }
        let wasPlaying = playerNode.isPlaying
        let duration = Double(audioFile.length) / audioFile.processingFormat.sampleRate
        let clampedTime = min(max(time, 0), duration)
        let frame = AVAudioFramePosition(clampedTime * audioFile.processingFormat.sampleRate)
        schedule(from: frame)
        eventHandler?(.timeChanged(clampedTime))
        if wasPlaying, frame < audioFile.length {
            playerNode.play()
        } else if wasPlaying {
            spectrumHandler?(Self.silentSpectrum)
            eventHandler?(.ended)
            endFileAccess()
        }
    }

    func stop() {
        stopPlayback(clearTrack: true)
        eventHandler?(.playingChanged(false))
        eventHandler?(.timeChanged(0))
    }

    func applyEqualizer(_ settings: EqualizerSettings) {
        var normalized = settings
        normalized.normalize()
        equalizerSettings = normalized
        equalizer.bypass = !normalized.isEnabled
        equalizer.globalGain = normalized.preamp
        for (parameters, band) in zip(equalizer.bands, normalized.bands) {
            parameters.gain = band.gain
            parameters.bypass = false
        }
    }

    private func beginFileAccess(for fileURL: URL) throws {
        endFileAccess()
        let libraryFolders = try fileImportService.restoreLibraryFolders()
        let scopeURL = libraryFolders.first {
            fileURL.standardizedFileURL.pathComponents.starts(with: $0.standardizedFileURL.pathComponents)
        } ?? fileURL
        let hasAccess = scopeURL.startAccessingSecurityScopedResource()
        guard hasAccess || FileManager.default.isReadableFile(atPath: fileURL.path) else {
            throw AudioPlayerServiceError.accessDenied
        }
        accessedURL = scopeURL
        isAccessingSecurityScope = hasAccess
    }

    private func endFileAccess() {
        if isAccessingSecurityScope { accessedURL?.stopAccessingSecurityScopedResource() }
        accessedURL = nil
        isAccessingSecurityScope = false
    }

    private func stopPlayback(clearTrack: Bool) {
        scheduleID = UUID()
        cancelScheduledFadeOut(clearBoundary: true)
        playbackTransitionService.cancelActiveRamp(resetVolume: false)
        playerNode.stop()
        engine.stop()
        // Reset only after the old render path is silent. Restoring the gain
        // before stopping can briefly expose full-volume samples after a fade.
        playbackTransitionService.cancelActiveRamp(resetVolume: true)
        playbackTimer?.invalidate()
        playbackTimer = nil
        audioFile = nil
        scheduledStartFrame = 0
        scheduledLength = 0
        pausedFrame = 0
        spectrumHandler?(Self.silentSpectrum)
        if clearTrack { currentTrack = nil }
        endFileAccess()
    }

    private func cancelScheduledFadeOut(clearBoundary: Bool) {
        scheduledFadeOutTask?.cancel()
        scheduledFadeOutTask = nil
        if clearBoundary { fadeOutBoundary = nil }
    }

    /// Allows the zero-gain value to reach the render thread before a player
    /// node is stopped. The small silence is preferable to a discontinuity pop.
    private func waitForSilentRenderCycle() async throws {
        try await Task.sleep(for: .milliseconds(20))
    }

    private func rescheduleFadeOut() {
        scheduledFadeOutTask?.cancel()
        scheduledFadeOutTask = nil
        guard playerNode.isPlaying,
              let audioFile,
              let fadeOutBoundary else { return }

        let fadeDuration = playbackTransitionService.settings.fadeOutDuration(for: fadeOutBoundary.reason)
        guard fadeDuration > 0 else { return }

        let currentTime = Double(currentFrame()) / audioFile.processingFormat.sampleRate
        let delay = max(fadeOutBoundary.endTime - currentTime - fadeDuration, 0)
        let activeScheduleID = scheduleID
        scheduledFadeOutTask = Task { @MainActor [weak self] in
            do {
                if delay > 0 { try await Task.sleep(for: .seconds(delay)) }
                guard let self,
                      self.scheduleID == activeScheduleID,
                      self.playerNode.isPlaying else { return }
                try await self.playbackTransitionService.fadeOut(for: fadeOutBoundary.reason)
            } catch {
                // A new playback action or settings change superseded this transition.
            }
        }
    }

    private func configureEqualizerBands() {
        for (parameters, frequency) in zip(equalizer.bands, EqualizerSettings.frequencies) {
            parameters.filterType = .parametric
            parameters.frequency = Float(frequency)
            parameters.bandwidth = 1
        }
    }

    private func configureGraph(for format: AVAudioFormat) throws {
        playerNode.stop()
        if engine.isRunning { engine.stop() }
        engine.disconnectNodeOutput(playerNode)
        engine.disconnectNodeOutput(transitionMixer)
        engine.disconnectNodeOutput(equalizer)
        engine.connect(playerNode, to: transitionMixer, format: format)
        engine.connect(transitionMixer, to: equalizer, format: format)
        engine.connect(equalizer, to: engine.mainMixerNode, format: format)
    }

    private func schedule(from requestedFrame: AVAudioFramePosition) {
        guard let audioFile else { return }
        scheduleID = UUID()
        let activeScheduleID = scheduleID
        playerNode.stop()
        let startFrame = min(max(requestedFrame, 0), audioFile.length)
        let remaining = max(audioFile.length - startFrame, 0)
        scheduledStartFrame = startFrame
        scheduledLength = audioFile.length
        pausedFrame = startFrame
        guard remaining > 0 else { return }
        playerNode.scheduleSegment(
            audioFile,
            startingFrame: startFrame,
            frameCount: AVAudioFrameCount(min(remaining, AVAudioFramePosition(UInt32.max))),
            at: nil,
            completionCallbackType: .dataPlayedBack
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, scheduleID == activeScheduleID else { return }
                pausedFrame = scheduledLength
                playbackTimer?.invalidate()
                playbackTimer = nil
                spectrumHandler?(Self.silentSpectrum)
                eventHandler?(.ended)
                endFileAccess()
            }
        }
    }

    private func currentFrame() -> AVAudioFramePosition {
        guard playerNode.isPlaying,
              let renderTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: renderTime) else {
            return pausedFrame
        }
        return min(scheduledStartFrame + playerTime.sampleTime, scheduledLength)
    }

    private func startPlaybackTimer() {
        guard playbackTimer == nil else { return }
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, let audioFile = self.audioFile else { return }
                let time = Double(self.currentFrame()) / audioFile.processingFormat.sampleRate
                self.eventHandler?(.timeChanged(max(time, 0)))
            }
        }
    }

    private func installSpectrumTapIfNeeded() {
        let mixer = engine.mainMixerNode
        if isSpectrumTapInstalled { mixer.removeTap(onBus: 0) }
        mixer.installTap(onBus: 0, bufferSize: 2_048, format: nil) { [weak self] buffer, _ in
            guard let channel = buffer.floatChannelData?.pointee else { return }
            let frameCount = Int(buffer.frameLength)
            guard frameCount > 0 else { return }
            let barCount = 32
            let framesPerBar = max(frameCount / barCount, 1)
            var levels = [Float](repeating: 0, count: barCount)
            for bar in levels.indices {
                let start = bar * framesPerBar
                guard start < frameCount else { break }
                let end = min(start + framesPerBar, frameCount)
                var peak: Float = 0
                for index in start..<end { peak = max(peak, abs(channel[index])) }
                levels[bar] = min(sqrt(peak), 1)
            }
            Task { @MainActor [weak self] in self?.spectrumHandler?(levels) }
        }
        isSpectrumTapInstalled = true
    }

    private static let silentSpectrum = Array(repeating: Float.zero, count: 32)

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default)
        try session.setActive(true)
    }

    private func observeAudioSession() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()
        audioSessionNotificationTokens.append(center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
            let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            MainActor.assumeIsolated { self?.handleInterruption(type: type, options: options) }
        })
        audioSessionNotificationTokens.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt
            MainActor.assumeIsolated { self?.handleRouteChange(reason: reason) }
        })
    }

    private func handleInterruption(type rawType: UInt?, options rawOptions: UInt) {
        guard let rawType,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            eventHandler?(.interruptionBegan)
        case .ended:
            eventHandler?(.interruptionEnded(shouldResume: AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)))
        @unknown default:
            break
        }
    }

    private func handleRouteChange(reason rawReason: UInt?) {
        guard let rawReason,
              AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable else { return }
        eventHandler?(.oldAudioDeviceUnavailable)
    }
}
