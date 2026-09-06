import Foundation
@preconcurrency import WatchConnectivity

@MainActor
protocol WatchConnectivityServicing: AnyObject {
    var commandHandler: ((WatchPlaybackCommand) -> Void)? { get set }
    var stateProvider: (() -> WatchPlaybackState)? { get set }
    func activate()
    func publish(_ state: WatchPlaybackState)
}

@MainActor
final class WatchConnectivityService: NSObject, WatchConnectivityServicing {
    var commandHandler: ((WatchPlaybackCommand) -> Void)?
    var stateProvider: (() -> WatchPlaybackState)?

    private let session: WCSession?
    private var pendingState: WatchPlaybackState?
    private var lastPublishedState: WatchPlaybackState?
    private var lastPublishDate = Date.distantPast

    init(session: WCSession? = WCSession.isSupported() ? .default : nil) {
        self.session = session
        super.init()
    }

    func activate() {
        session?.delegate = self
        session?.activate()
    }

    func publish(_ state: WatchPlaybackState) {
        pendingState = state
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

    private func receive(_ message: [String: Any], replyHandler: (([String: Any]) -> Void)?) {
        Task { @MainActor [weak self] in
            guard let self, let command = WatchPlaybackState.command(from: message) else {
                replyHandler?([:])
                return
            }
            if command != .requestState { commandHandler?(command) }
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
}
