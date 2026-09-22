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
    private let now: () -> Date
    private var playbackTask: Task<Void, Never>?
    private var historySession: HistorySession?
    var state: State = .idle
    var snapshot: HiResAudioQueueProbeSnapshot?

    init(
        service: HiResAudioQueueProbeServicing? = nil,
        now: @escaping () -> Date = Date.init
    ) {
        let resolvedService = service ?? HiResAudioQueueProbeService()
        self.service = resolvedService
        self.now = now
        resolvedService.eventHandler = { [weak self] event in
            self?.handle(event)
        }
    }

    var hasActiveSession: Bool {
        state == .playing || state == .switching || state == .reachedEnd
    }

    func play(url: URL) {
        startPlayback(url: url, historySession: nil)
    }

    func play(track: Track, historyStore: PlaybackHistoryStore) {
        startPlayback(
            url: track.fileURL,
            historySession: HistorySession(track: track, store: historyStore)
        )
    }

    private func startPlayback(url: URL, historySession: HistorySession?) {
        guard !hasActiveSession else { return }
        finalizeHistory(endKind: .userSkipped)
        self.historySession = historySession
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
        finalizeHistory(endKind: .userSkipped)
        playbackTask?.cancel()
        playbackTask = nil
        service.stop()
        state = .idle
    }

    private func handle(_ event: HiResAudioQueueProbeEvent) {
        switch event {
        case let .started(snapshot):
            self.snapshot = snapshot
            state = .playing
            startHistoryIfNeeded()
        case let .updated(snapshot):
            self.snapshot = snapshot
            state = .playing
        case let .prepared(snapshot):
            self.snapshot = snapshot
            state = .prepared
        case .reachedEnd:
            finalizeHistory(endKind: .natural)
            state = .reachedEnd
        case let .failed(message):
            finalizeHistory(endKind: .other)
            service.stop()
            state = .failed(message)
        }
    }

    private func startHistoryIfNeeded() {
        guard var session = historySession, session.startedAt == nil else { return }
        let startedAt = now()
        session.startedAt = startedAt
        historySession = session
        session.store.recordPlaybackStarted(
            trackID: session.track.id,
            context: session.context,
            isRepeatModeActive: false,
            isConsecutivePlay: false,
            now: startedAt
        )
    }

    private func finalizeHistory(endKind: PlaybackEndKind) {
        guard let session = historySession else { return }
        historySession = nil
        guard let startedAt = session.startedAt else { return }

        let endedAt = now()
        let elapsed = max(0, endedAt.timeIntervalSince(startedAt))
        let duration = max(0, session.track.duration)
        let naturallyCompleted = endKind == .natural
        let listenedSeconds = naturallyCompleted && duration > 0
            ? duration
            : min(elapsed, duration > 0 ? duration : elapsed)
        let countThreshold = min(30, duration * 0.5)
        if naturallyCompleted || (countThreshold > 0 && listenedSeconds >= countThreshold) {
            session.store.recordPlaybackCompleted(trackID: session.track.id)
        }
        session.store.addPlaybackDuration(trackID: session.track.id, seconds: listenedSeconds)
        let isFullPlayback = naturallyCompleted || PlaybackHistoryScoring.isFullPlayback(
            duration: duration,
            listenedSeconds: listenedSeconds
        )
        session.store.recordPlaybackFinished(
            trackID: session.track.id,
            startedAt: startedAt,
            endedAt: endedAt,
            listenedSeconds: listenedSeconds,
            duration: duration,
            context: session.context,
            isFullPlayback: isFullPlayback,
            isSkipped: endKind == .userSkipped && !isFullPlayback,
            endKind: endKind
        )
    }
}

private struct HistorySession {
    let track: Track
    let store: PlaybackHistoryStore
    var startedAt: Date?
    let context = PlaybackStartContext(kind: .manual, source: .hiResLibrary)

    init(track: Track, store: PlaybackHistoryStore, startedAt: Date? = nil) {
        self.track = track
        self.store = store
        self.startedAt = startedAt
    }
}
