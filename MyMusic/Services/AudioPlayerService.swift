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
final class AudioPlayerService: AudioPlayerServicing {
    var eventHandler: ((AudioPlaybackEvent) -> Void)?

    private let fileImportService: FileImportServicing
    private var player: AVPlayer?
    private var currentTrack: Track?
    private var timeObserver: Any?
    private var itemNotificationTokens: [NSObjectProtocol] = []
    private var audioSessionNotificationTokens: [NSObjectProtocol] = []
    private var accessedURL: URL?
    private var isAccessingSecurityScope = false

    init(fileImportService: FileImportServicing? = nil) {
        self.fileImportService = fileImportService ?? FileImportService()
        observeAudioSession()
    }

    deinit {
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        itemNotificationTokens.forEach(NotificationCenter.default.removeObserver)
        audioSessionNotificationTokens.forEach(NotificationCenter.default.removeObserver)
        if isAccessingSecurityScope { accessedURL?.stopAccessingSecurityScopedResource() }
    }

    func play(_ track: Track) async throws {
        stopPlayback(clearTrack: false)
        currentTrack = track
        try beginFileAccess(for: track.fileURL)

        do {
            guard FileManager.default.fileExists(atPath: track.fileURL.path) else {
                throw AudioPlayerServiceError.fileUnavailable
            }

            let asset = AVURLAsset(url: track.fileURL)
            let (isPlayable, duration) = try await asset.load(.isPlayable, .duration)
            guard isPlayable else { throw AudioPlayerServiceError.unsupportedFormat }

            try configureAudioSession()
            let item = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: item)
            self.player = player
            observe(player: player, item: item)

            let seconds = duration.seconds
            eventHandler?(.ready(duration: seconds.isFinite ? seconds : track.duration))
            player.play()
            eventHandler?(.playingChanged(true))
        } catch {
            stopPlayback(clearTrack: false)
            throw error
        }
    }

    func pause() {
        player?.pause()
        eventHandler?(.playingChanged(false))
    }

    func resume() async throws {
        guard let player, let currentTrack else { return }
        if !isAccessingSecurityScope { try beginFileAccess(for: currentTrack.fileURL) }

        let duration = player.currentItem?.duration.seconds ?? 0
        if duration.isFinite, duration > 0, player.currentTime().seconds >= duration - 0.05 {
            await player.seek(to: .zero)
            eventHandler?(.timeChanged(0))
        }
        player.play()
        eventHandler?(.playingChanged(true))
    }

    func seek(to time: TimeInterval) {
        guard let player else { return }
        let duration = player.currentItem?.duration.seconds ?? time
        let clampedTime = min(max(time, 0), duration.isFinite ? duration : time)
        player.seek(to: CMTime(seconds: clampedTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
        eventHandler?(.timeChanged(clampedTime))
    }

    func stop() {
        stopPlayback(clearTrack: true)
        eventHandler?(.playingChanged(false))
        eventHandler?(.timeChanged(0))
    }

    private func observe(player: AVPlayer, item: AVPlayerItem) {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated { self?.eventHandler?(.timeChanged(max(time.seconds, 0))) }
        }

        let center = NotificationCenter.default
        itemNotificationTokens.append(center.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.eventHandler?(.ended)
                self?.endFileAccess()
            }
        })
        itemNotificationTokens.append(center.addObserver(forName: .AVPlayerItemFailedToPlayToEndTime, object: item, queue: .main) { [weak self] notification in
            MainActor.assumeIsolated {
                let error = notification.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
                self?.eventHandler?(.failed(error?.localizedDescription ?? "Playback failed."))
                self?.endFileAccess()
            }
        })
    }

    private func beginFileAccess(for fileURL: URL) throws {
        endFileAccess()
        let libraryFolder = try fileImportService.restoreLibraryFolder()
        let scopeURL = libraryFolder ?? fileURL
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
        player?.pause()
        if let timeObserver { player?.removeTimeObserver(timeObserver) }
        timeObserver = nil
        itemNotificationTokens.forEach(NotificationCenter.default.removeObserver)
        itemNotificationTokens.removeAll()
        player = nil
        if clearTrack { currentTrack = nil }
        endFileAccess()
    }

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
            MainActor.assumeIsolated { self?.handleInterruption(notification) }
        })
        audioSessionNotificationTokens.append(center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            MainActor.assumeIsolated { self?.handleRouteChange(notification) }
        })
    }

    private func handleInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else { return }
        switch type {
        case .began:
            eventHandler?(.interruptionBegan)
        case .ended:
            let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
            eventHandler?(.interruptionEnded(shouldResume: AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)))
        @unknown default:
            break
        }
    }

    private func handleRouteChange(_ notification: Notification) {
        guard let rawReason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
              AVAudioSession.RouteChangeReason(rawValue: rawReason) == .oldDeviceUnavailable else { return }
        eventHandler?(.oldAudioDeviceUnavailable)
    }
}
