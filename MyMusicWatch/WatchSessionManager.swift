import Foundation
import ImageIO
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
    private var artworkRequestAttemptCount = 0
    private var artworkRequestTimeoutTask: Task<Void, Never>?
    private static let maximumArtworkRequestAttempts = 3

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
            album: "A Long Album Title for Apple Watch",
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

    private(set) var pendingShuffle: WatchShuffleKind?
    private(set) var shuffleError: String?
    private(set) var completedShuffleCount = 0

    func shuffle(_ kind: WatchShuffleKind) {
        guard pendingShuffle == nil else { return }
        guard let session, session.activationState == .activated, session.isReachable else {
            shuffleError = "iPhoneに接続できません"
            return
        }
        pendingShuffle = kind
        shuffleError = nil
        session.sendMessage(kind.message, replyHandler: { [weak self] message in
            Task { @MainActor in
                guard let self else { return }
                self.apply(message)
                self.pendingShuffle = nil
                if message["shuffleSucceeded"] as? Bool == true {
                    self.completedShuffleCount += 1
                } else {
                    self.shuffleError = message["shuffleError"] as? String ?? "iPhoneでMyMusicを確認してください"
                }
            }
        }, errorHandler: { [weak self] _ in
            Task { @MainActor in
                self?.pendingShuffle = nil
                self?.shuffleError = "iPhoneに接続できません"
            }
        })
    }

    private func apply(_ message: [String: Any]) {
        guard let state = WatchPlaybackState(message: message) else { return }
        if state.trackID != playbackState.trackID {
            artworkData = nil
            requestedArtworkTrackID = nil
            artworkRequestAttemptCount = 0
            artworkRequestTimeoutTask?.cancel()
        }
        playbackState = state
        errorMessage = nil
        requestArtworkIfNeeded()
    }

    private func applyArtwork(_ data: Data, trackID: UUID) {
        guard playbackState.trackID == trackID,
              playbackState.hasArtwork,
              CGImageSourceCreateWithData(data as CFData, nil) != nil else {
            artworkRequestFailed(for: trackID)
            return
        }
        artworkRequestTimeoutTask?.cancel()
        artworkData = data
    }

    private func requestArtworkIfNeeded() {
        guard let trackID = playbackState.trackID,
              playbackState.hasArtwork,
              artworkData == nil,
              requestedArtworkTrackID != trackID,
              artworkRequestAttemptCount < Self.maximumArtworkRequestAttempts,
              let session,
              session.activationState == .activated,
              session.isReachable else { return }
        requestedArtworkTrackID = trackID
        artworkRequestAttemptCount += 1
        session.sendMessage(
            WatchPlaybackState.commandMessage(.requestArtwork),
            replyHandler: { [weak self] message in
                Task { @MainActor in self?.apply(message) }
            },
            errorHandler: { [weak self] _ in
                Task { @MainActor in self?.artworkRequestFailed(for: trackID) }
            }
        )
        artworkRequestTimeoutTask?.cancel()
        artworkRequestTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(6))
            guard !Task.isCancelled else { return }
            self?.artworkRequestFailed(for: trackID)
        }
    }

    private func artworkRequestFailed(for trackID: UUID) {
        guard playbackState.trackID == trackID, artworkData == nil else { return }
        requestedArtworkTrackID = nil
        artworkRequestTimeoutTask?.cancel()
        artworkRequestTimeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            self?.requestArtworkIfNeeded()
        }
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
            if canSend {
                self?.requestedArtworkTrackID = nil
                self?.artworkRequestAttemptCount = 0
                self?.send(.requestState)
            }
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
