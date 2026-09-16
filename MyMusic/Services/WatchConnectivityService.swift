import Foundation
@preconcurrency import WatchConnectivity

@MainActor
protocol WatchConnectivityServicing: AnyObject {
    var commandHandler: ((WatchPlaybackCommand) -> Void)? { get set }
    var shuffleHandler: ((WatchShuffleKind) async -> String?)? { get set }
    var stateProvider: (() -> WatchPlaybackState)? { get set }
    func activate()
    func publish(_ state: WatchPlaybackState, artworkIdentifier: String?)
}

@MainActor
final class WatchConnectivityService: NSObject, WatchConnectivityServicing {
    private struct ArtworkTransferKey: Equatable {
        let trackID: UUID
        let identifier: String
    }

    var commandHandler: ((WatchPlaybackCommand) -> Void)?
    var shuffleHandler: ((WatchShuffleKind) async -> String?)?
    var stateProvider: (() -> WatchPlaybackState)?

    private let session: WCSession?
    private let artworkPreparationService: WatchArtworkPreparing
    private var pendingState: WatchPlaybackState?
    private var currentArtworkIdentifier: String?
    private var lastPublishedState: WatchPlaybackState?
    private var lastPublishDate = Date.distantPast
    private var artworkTransferKeyInFlightOrSent: ArtworkTransferKey?
    private var activeArtworkTransfer: WCSessionFileTransfer?
    private var artworkTask: Task<Void, Never>?

    init(
        session: WCSession? = WCSession.isSupported() ? .default : nil,
        artworkPreparationService: WatchArtworkPreparing = WatchArtworkPreparationService()
    ) {
        self.session = session
        self.artworkPreparationService = artworkPreparationService
        super.init()
    }

    func activate() {
        session?.delegate = self
        session?.activate()
    }

    func publish(_ state: WatchPlaybackState, artworkIdentifier: String?) {
        pendingState = state
        currentArtworkIdentifier = artworkIdentifier
        let transferKey = state.trackID.flatMap { trackID in
            artworkIdentifier.map { ArtworkTransferKey(trackID: trackID, identifier: $0) }
        }
        if artworkTransferKeyInFlightOrSent != transferKey {
            artworkTask?.cancel()
            activeArtworkTransfer?.cancel()
            activeArtworkTransfer = nil
            artworkTransferKeyInFlightOrSent = nil
        }
        synchronizeLatestState()
    }

    private func synchronizeLatestState(force: Bool = false) {
        guard let session,
              session.activationState == .activated,
              session.isPaired,
              session.isWatchAppInstalled,
              let state = pendingState ?? stateProvider?() else { return }
        let now = Date()
        let materiallyChanged = lastPublishedState?.trackID != state.trackID
            || lastPublishedState?.isPlaying != state.isPlaying
            || lastPublishedState?.duration != state.duration
        // Playback ticks can be frequent. One state per second is enough for the MVP progress UI.
        guard force || materiallyChanged || now.timeIntervalSince(lastPublishDate) >= 1 else { return }
        do {
            try session.updateApplicationContext(state.message)
        } catch {
            return
        }
        pendingState = nil
        lastPublishedState = state
        lastPublishDate = now
        if session.isReachable {
            session.sendMessage(state.message, replyHandler: nil, errorHandler: { _ in })
        }
    }

    private func transferArtworkIfNeeded(
        for state: WatchPlaybackState,
        artworkIdentifier: String?,
        session: WCSession
    ) {
        guard state.hasArtwork,
              let trackID = state.trackID,
              let artworkIdentifier else { return }
        let transferKey = ArtworkTransferKey(trackID: trackID, identifier: artworkIdentifier)
        guard artworkTransferKeyInFlightOrSent != transferKey else { return }
        artworkTransferKeyInFlightOrSent = transferKey
        artworkTask = Task { @MainActor [weak self] in
            guard let self else { return }
            guard let fileURL = await artworkPreparationService.prepareArtworkFile(
                    identifier: artworkIdentifier,
                    trackID: trackID
                  ) else {
                artworkPreparationFailed(for: transferKey)
                return
            }
            guard !Task.isCancelled,
                  lastPublishedState?.trackID == trackID,
                  currentArtworkIdentifier == artworkIdentifier,
                  session.activationState == .activated,
                  session.isPaired,
                  session.isWatchAppInstalled else {
                await WatchArtworkPreparationService.removePreparedFile(fileURL)
                artworkPreparationFailed(for: transferKey)
                return
            }
            activeArtworkTransfer = session.transferFile(
                fileURL,
                metadata: WatchArtworkFileMetadata.message(trackID: trackID, identifier: artworkIdentifier)
            )
            artworkTask = nil
        }
    }

    private func artworkPreparationFailed(for transferKey: ArtworkTransferKey) {
        guard artworkTransferKeyInFlightOrSent == transferKey else { return }
        artworkTask = nil
        artworkTransferKeyInFlightOrSent = nil
    }

    private func receive(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        Task { @MainActor [weak self] in
            if let self, let kind = WatchShuffleKind(message: message) {
                let error: String?
                if let handler = shuffleHandler {
                    error = await handler(kind)
                } else {
                    error = "iPhoneでMyMusicを開いてください"
                }
                var reply = stateProvider?().message ?? WatchPlaybackState.empty.message
                reply["shuffleSucceeded"] = error == nil
                reply["shuffleError"] = error
                replyHandler?(reply)
                return
            }
            guard let self, let command = WatchPlaybackState.command(from: message) else {
                replyHandler?([:])
                return
            }
            if command == .requestArtwork {
                if let state = stateProvider?(), let session {
                    if activeArtworkTransfer == nil && artworkTask == nil {
                        artworkTransferKeyInFlightOrSent = nil
                    }
                    // An in-progress request keeps its key, so duplicate requests share one transfer.
                    transferArtworkIfNeeded(
                        for: state,
                        artworkIdentifier: currentArtworkIdentifier,
                        session: session
                    )
                }
            } else if command != .requestState {
                commandHandler?(command)
            }
            replyHandler?(stateProvider?().message ?? WatchPlaybackState.empty.message)
        }
    }
}

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        guard activationState == .activated else { return }
        Task { @MainActor [weak self] in
            self?.synchronizeLatestState(force: true)
        }
    }

    nonisolated func sessionWatchStateDidChange(_ session: WCSession) {
        Task { @MainActor [weak self] in
            guard session.activationState == .activated,
                  session.isPaired,
                  session.isWatchAppInstalled else { return }
            self?.synchronizeLatestState(force: true)
        }
    }

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    nonisolated func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        Task { @MainActor [weak self] in self?.receive(message, replyHandler: replyHandler) }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor [weak self] in self?.receive(message, replyHandler: nil) }
    }

    nonisolated func session(
        _ session: WCSession,
        didFinish fileTransfer: WCSessionFileTransfer,
        error: Error?
    ) {
        Task { await WatchArtworkPreparationService.removePreparedFile(fileTransfer.file.fileURL) }
        Task { @MainActor [weak self] in
            guard let self, activeArtworkTransfer === fileTransfer else { return }
            activeArtworkTransfer = nil
            artworkTransferKeyInFlightOrSent = nil
        }
    }
}
