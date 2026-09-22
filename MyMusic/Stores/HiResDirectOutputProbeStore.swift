import Foundation
import Observation

@MainActor
@Observable
final class HiResDirectOutputProbeStore {
    enum State: Equatable {
        case idle
        case playing
        case reachedEnd
        case failed(String)
    }

    private let service: HiResAudioQueueProbeServicing
    var state: State = .idle
    var snapshot: HiResAudioQueueProbeSnapshot?

    init(service: HiResAudioQueueProbeServicing? = nil) {
        let resolvedService = service ?? HiResAudioQueueProbeService()
        self.service = resolvedService
        resolvedService.eventHandler = { [weak self] event in
            self?.handle(event)
        }
    }

    var isPlaying: Bool { state == .playing }

    func play(url: URL) {
        do {
            try service.play(url: url)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func stop() {
        service.stop()
        state = .idle
    }

    private func handle(_ event: HiResAudioQueueProbeEvent) {
        switch event {
        case let .started(snapshot), let .updated(snapshot):
            self.snapshot = snapshot
            state = .playing
        case .reachedEnd:
            state = .reachedEnd
        case let .failed(message):
            state = .failed(message)
        }
    }
}
