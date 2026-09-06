import Foundation
import Observation
@preconcurrency import WatchConnectivity

@MainActor
@Observable
final class WatchSessionManager: NSObject {
    private(set) var playbackState = WatchPlaybackState.empty
    private(set) var artworkData: Data?
    private(set) var isPhoneReachable = false
    private(set) var errorMessage: String?

    private let session: WCSession?
    private var requestedArtworkTrackID: UUID?

    override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
        session?.delegate = self
        session?.activate()
    }

#if DEBUG
    static var preview: WatchSessionManager {
        let manager = WatchSessionManager(session: nil)
        manager.playbackState = WatchPlaybackState(
            trackID: UUID(),
            title: "A Long Song Title for Apple Watch",
            artist: "MyMusic Artist",
            isPlaying: true,
            currentTime: 72,
            duration: 245,
            isFavorite: true,
            playbackPreference: 4,
            hasArtwork: false
        )
        manager.isPhoneReachable = true
        return manager
    }
#endif

    private init(session: WCSession?) {
        self.session = session
        super.init()
    }

    func send(_ command: WatchPlaybackCommand) {
        guard let session, session.activationState == .activated, session.isReachable else {
            isPhoneReachable = false
            errorMessage = "iPhoneに接続できません"
            return
        }
        errorMessage = nil
        session.sendMessage(
            WatchPlaybackState.commandMessage(command),
            replyHandler: { [weak self] message in
                Task { @MainActor in self?.apply(message) }
            },
            errorHandler: { [weak self] _ in
                Task { @MainActor in
                    self?.isPhoneReachable = false
                    self?.errorMessage = "MyMusicと通信できません"
                }
            }
        )
    }

    private func apply(_ message: [String: Any]) {
        guard let state = WatchPlaybackState(message: message) else { return }
        if state.trackID != playbackState.trackID {
            artworkData = nil
            requestedArtworkTrackID = nil
        }
        playbackState = state
        errorMessage = nil
        if state.hasArtwork,
           let trackID = state.trackID,
           artworkData == nil,
           requestedArtworkTrackID != trackID,
           session?.activationState == .activated,
           session?.isReachable == true {
            requestedArtworkTrackID = trackID
            send(.requestArtwork)
        }
    }

    private func applyArtwork(_ data: Data, trackID: UUID) {
        guard playbackState.trackID == trackID, playbackState.hasArtwork else { return }
        artworkData = data
    }
}

extension WatchSessionManager: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        Task { @MainActor [weak self] in
            self?.isPhoneReachable = activationState == .activated && session.isReachable
            if activationState == .activated {
                self?.send(.requestState)
            }
        }
    }

    nonisolated func sessionReachabilityDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            let canSend = session.activationState == .activated && session.isReachable
            self?.isPhoneReachable = canSend
            if canSend { self?.send(.requestState) }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor [weak self] in self?.apply(applicationContext) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor [weak self] in self?.apply(message) }
    }

    nonisolated func session(_ session: WCSession, didReceive file: WCSessionFile) {
        guard let trackID = WatchArtworkFileMetadata.trackID(from: file.metadata) else { return }
        Task.detached(priority: .utility) { [weak self] in
            guard let data = try? Data(contentsOf: file.fileURL) else { return }
            await self?.applyArtwork(data, trackID: trackID)
        }
    }
}
