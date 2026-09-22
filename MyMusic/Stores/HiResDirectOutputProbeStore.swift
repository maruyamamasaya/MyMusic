import Foundation
import Observation

@MainActor
@Observable
final class HiResDirectOutputProbeStore {
    enum State: Equatable {
        case idle
        case switching
        case playing
        case prepared
        case reachedEnd
        case failed(String)
    }

    private let service: HiResAudioQueueProbeServicing
    private var playbackTask: Task<Void, Never>?
    var state: State = .idle
    var snapshot: HiResAudioQueueProbeSnapshot?

    init(service: HiResAudioQueueProbeServicing? = nil) {
        let resolvedService = service ?? HiResAudioQueueProbeService()
        self.service = resolvedService
        resolvedService.eventHandler = { [weak self] event in
            self?.handle(event)
        }
    }

    var hasActiveSession: Bool {
        state == .playing || state == .switching || state == .reachedEnd
    }

    func play(url: URL) {
        guard !hasActiveSession else { return }
        let previousTask = playbackTask
        previousTask?.cancel()
        service.stop()
        state = .switching
        playbackTask = Task { [weak self] in
            // Let the cancelled request finish closing its AudioFile and
            // security scope before a replacement request opens the next one.
            _ = await previousTask?.result
            guard !Task.isCancelled else { return }
            guard let self else { return }
            do {
                try await service.play(url: url)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed(error.localizedDescription)
            }
        }
    }

    func prepare(sampleRate: Double) {
        guard !hasActiveSession else { return }
        playbackTask?.cancel()
        service.stop()
        state = .switching
        playbackTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await service.prepare(sampleRate: sampleRate)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                state = .failed(error.localizedDescription)
            }
        }
    }

    func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        service.stop()
        state = .idle
    }

    private func handle(_ event: HiResAudioQueueProbeEvent) {
        switch event {
        case let .started(snapshot), let .updated(snapshot):
            self.snapshot = snapshot
            state = .playing
        case let .prepared(snapshot):
            self.snapshot = snapshot
            state = .prepared
        case .reachedEnd:
            state = .reachedEnd
        case let .failed(message):
            service.stop()
            state = .failed(message)
        }
    }
}
