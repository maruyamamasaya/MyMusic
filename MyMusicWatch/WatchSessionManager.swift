import Foundation
import Observation
@preconcurrency import WatchConnectivity

@MainActor
@Observable
final class WatchSessionManager: NSObject {
    private(set) var playbackState = WatchPlaybackState.empty
    private(set) var isPhoneReachable = false
    private(set) var errorMessage: String?

    private let session: WCSession?

    override init() {
        session = WCSession.isSupported() ? .default : nil
        super.init()
        session?.delegate = self
        session?.activate()
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
        playbackState = state
        errorMessage = nil
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
}
