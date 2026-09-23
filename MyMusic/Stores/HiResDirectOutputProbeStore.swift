import Foundation
import Observation

@MainActor
@Observable
final class HiResDirectOutputProbeStore {
    enum State: Equatable {
        case idle
        case switching
        case playing
        case paused
        case prepared
        case reachedEnd
        case failed(String)
    }

    private let service: HiResAudioQueueProbeServicing
    private let now: () -> Date
    private var playbackTask: Task<Void, Never>?
    private var historySession: HistorySession?
    private var historyStore: PlaybackHistoryStore?
    var state: State = .idle
    var snapshot: HiResAudioQueueProbeSnapshot?
    private(set) var currentTrack: Track?
    private(set) var queue: [Track] = []
    private(set) var currentIndex: Int?
    private(set) var currentTime: TimeInterval = 0
    private(set) var isShuffleEnabled = false
    private(set) var repeatMode: RepeatMode = .off
    private var playbackOrder: [Int] = []

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
        state == .playing || state == .paused || state == .switching || state == .reachedEnd
    }

    var isPlaying: Bool { state == .playing }
    var isLoading: Bool { state == .switching }
    var duration: TimeInterval { max(currentTrack?.duration ?? 0, 0) }
    var canGoPrevious: Bool { (currentPlaybackPosition ?? 0) > 0 || currentTime > 0 }
    var canGoNext: Bool {
        nextPlaybackPosition(wrapping: repeatMode == .all) != nil
    }

    func play(url: URL) {
        startPlayback(url: url, historySession: nil)
    }

    func play(track: Track, historyStore: PlaybackHistoryStore) {
        play(track: track, queue: [track], historyStore: historyStore)
    }

    func play(track: Track, queue tracks: [Track], historyStore: PlaybackHistoryStore) {
        let normalizedQueue = normalizedQueue(tracks, including: track)
        queue = normalizedQueue
        currentIndex = normalizedQueue.firstIndex(where: { $0.id == track.id })
        rebuildPlaybackOrder()
        currentTrack = track
        self.historyStore = historyStore
        currentTime = 0
        startPlayback(
            url: track.fileURL,
            historySession: HistorySession(track: track, store: historyStore),
            replacingActiveSession: true
        )
    }

    private func startPlayback(
        url: URL,
        historySession: HistorySession?,
        replacingActiveSession: Bool = false
    ) {
        guard replacingActiveSession || !hasActiveSession else { return }
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

    func togglePlayPause() {
        switch state {
        case .playing:
            do {
                try service.pause()
                pauseHistory()
                state = .paused
            } catch {
                state = .failed(error.localizedDescription)
            }
        case .paused:
            do {
                try service.resume()
                resumeHistory()
                state = .playing
            } catch {
                state = .failed(error.localizedDescription)
            }
        case .idle, .reachedEnd, .failed:
            guard let currentTrack, let historyStore else { return }
            play(track: currentTrack, queue: queue, historyStore: historyStore)
        case .switching, .prepared:
            break
        }
    }

    func seek(to time: TimeInterval) {
        guard state == .playing || state == .paused else { return }
        let target = min(max(time.isFinite ? time : 0, 0), duration)
        let wasPaused = state == .paused
        do {
            try service.seek(to: target)
            if wasPaused { try service.pause() }
            currentTime = target
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func skip(by interval: TimeInterval) {
        seek(to: currentTime + interval)
    }

    func previous() {
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        guard let position = currentPlaybackPosition, position > 0 else { return }
        playTrack(at: playbackOrder[position - 1])
    }

    func next() {
        guard let position = nextPlaybackPosition(wrapping: repeatMode == .all) else { return }
        playTrack(at: playbackOrder[position])
    }

    func toggleShuffle() {
        isShuffleEnabled.toggle()
        rebuildPlaybackOrder()
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next
    }

    func playTrack(at index: Int) {
        guard queue.indices.contains(index), let historyStore else { return }
        let track = queue[index]
        currentIndex = index
        currentTrack = track
        currentTime = 0
        startPlayback(
            url: track.fileURL,
            historySession: HistorySession(track: track, store: historyStore),
            replacingActiveSession: true
        )
    }

    func stop() {
        finalizeHistory(endKind: .userSkipped)
        playbackTask?.cancel()
        playbackTask = nil
        service.stop()
        state = .idle
        currentTime = 0
    }

    private func handle(_ event: HiResAudioQueueProbeEvent) {
        switch event {
        case let .started(snapshot):
            self.snapshot = snapshot
            state = .playing
            startHistoryIfNeeded()
        case let .updated(snapshot):
            self.snapshot = snapshot
            if state != .paused { state = .playing }
        case let .prepared(snapshot):
            self.snapshot = snapshot
            state = .prepared
        case let .progress(time):
            currentTime = min(max(time, 0), duration > 0 ? duration : time)
        case .reachedEnd:
            finalizeHistory(endKind: .natural)
            currentTime = duration
            if repeatMode == .one, let currentIndex {
                playTrack(at: currentIndex)
            } else if canGoNext {
                next()
            } else {
                playbackTask?.cancel()
                playbackTask = nil
                service.stop()
                state = .reachedEnd
            }
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
        session.activeSince = startedAt
        historySession = session
        session.store.recordPlaybackStarted(
            trackID: session.track.id,
            context: session.context,
            isRepeatModeActive: repeatMode != .off,
            isConsecutivePlay: false,
            now: startedAt
        )
    }

    private func finalizeHistory(endKind: PlaybackEndKind) {
        guard var session = historySession else { return }
        historySession = nil
        guard let startedAt = session.startedAt else { return }

        let endedAt = now()
        session.accumulate(until: endedAt)
        let duration = max(0, session.track.duration)
        let naturallyCompleted = endKind == .natural
        let listenedSeconds = naturallyCompleted && duration > 0
            ? duration
            : min(session.listenedSeconds, duration > 0 ? duration : session.listenedSeconds)
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

    private func pauseHistory() {
        guard var session = historySession else { return }
        session.accumulate(until: now())
        historySession = session
    }

    private func resumeHistory() {
        guard var session = historySession, session.startedAt != nil else { return }
        session.activeSince = now()
        historySession = session
    }

    private func normalizedQueue(_ tracks: [Track], including track: Track) -> [Track] {
        var seen: Set<Track.ID> = []
        var result = tracks.filter { seen.insert($0.id).inserted }
        if seen.insert(track.id).inserted { result.append(track) }
        return result
    }

    private var currentPlaybackPosition: Int? {
        guard let currentIndex else { return nil }
        return playbackOrder.firstIndex(of: currentIndex)
    }

    private func nextPlaybackPosition(wrapping: Bool) -> Int? {
        guard let position = currentPlaybackPosition, !playbackOrder.isEmpty else { return nil }
        let nextPosition = position + 1
        if playbackOrder.indices.contains(nextPosition) { return nextPosition }
        return wrapping ? playbackOrder.startIndex : nil
    }

    private func rebuildPlaybackOrder() {
        guard !queue.isEmpty else {
            playbackOrder = []
            return
        }
        let naturalOrder = Array(queue.indices)
        guard isShuffleEnabled, let currentIndex else {
            playbackOrder = naturalOrder
            return
        }
        playbackOrder = [currentIndex] + naturalOrder.filter { $0 != currentIndex }.shuffled()
    }
}

private struct HistorySession {
    let track: Track
    let store: PlaybackHistoryStore
    var startedAt: Date?
    var activeSince: Date?
    var listenedSeconds: TimeInterval = 0
    let context = PlaybackStartContext(kind: .manual, source: .hiResLibrary)

    init(track: Track, store: PlaybackHistoryStore, startedAt: Date? = nil) {
        self.track = track
        self.store = store
        self.startedAt = startedAt
        activeSince = startedAt
    }

    mutating func accumulate(until date: Date) {
        guard let activeSince else { return }
        listenedSeconds += max(0, date.timeIntervalSince(activeSince))
        self.activeSince = nil
    }
}
