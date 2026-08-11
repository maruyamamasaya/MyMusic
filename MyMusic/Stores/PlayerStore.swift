import Foundation
import Observation

enum RepeatMode: String, CaseIterable, Sendable {
    case off
    case all
    case one

    var next: RepeatMode {
        switch self {
        case .off: .all
        case .all: .one
        case .one: .off
        }
    }
}

@MainActor
@Observable
final class PlayerStore {
    private(set) var currentTrack: Track?
    private(set) var isPlaying = false
    private(set) var currentTime: TimeInterval = 0
    private(set) var duration: TimeInterval = 0
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var queue: [Track] = []
    private(set) var currentIndex: Int?
    private(set) var playbackOrder: [Int] = []
    private(set) var isShuffleEnabled = false
    private(set) var repeatMode: RepeatMode = .off

    var hasNext: Bool {
        guard currentPlaybackPosition != nil else { return false }
        return nextPlaybackPosition(wrapping: repeatMode == .all) != nil
    }

    var hasPrevious: Bool {
        guard let position = currentPlaybackPosition else { return false }
        return currentTime > 0 || position > 0
    }

    private var currentPlaybackPosition: Int? {
        guard let currentIndex else { return nil }
        return playbackOrder.firstIndex(of: currentIndex)
    }

    private let previousRestartThreshold: TimeInterval = 3
    private let audioPlayer: AudioPlayerServicing
    private let playbackHistoryStore: PlaybackHistoryStore
    private var playbackTask: Task<Void, Never>?
    private var playbackRequestID = UUID()
    private var hasRecordedPlaybackStart = false
    private var hasCountedCurrentPlay = false
    private var listenedTime: TimeInterval = 0
    private var lastObservedPlaybackTime: TimeInterval?

    init(
        audioPlayer: AudioPlayerServicing? = nil,
        playbackHistoryStore: PlaybackHistoryStore? = nil
    ) {
        let resolvedPlayer = audioPlayer ?? AudioPlayerService()
        self.audioPlayer = resolvedPlayer
        self.playbackHistoryStore = playbackHistoryStore ?? PlaybackHistoryStore()
        resolvedPlayer.eventHandler = { [weak self] event in
            self?.handle(event)
        }
    }

    /// Starts a one-item queue for callers that do not provide playback context.
    func play(_ track: Track) {
        playQueue([track], startingAt: 0)
    }

    func playQueue(_ tracks: [Track], startingAt index: Int) {
        guard tracks.indices.contains(index) else {
            if tracks.isEmpty { stop() }
            return
        }
        queue = tracks
        currentIndex = nil
        rebuildPlaybackOrder(keepingCurrentIndex: index)
        startPlayback(at: index)
    }

    func playQueue(_ tracks: [Track], startingWith track: Track) {
        guard let index = tracks.firstIndex(where: { $0.id == track.id }) else { return }
        playQueue(tracks, startingAt: index)
    }

    func playQueueItem(at index: Int) {
        guard queue.indices.contains(index) else { return }
        startPlayback(at: index)
    }

    func next() {
        guard let nextPosition = nextPlaybackPosition(wrapping: repeatMode == .all) else {
            audioPlayer.pause()
            isPlaying = false
            return
        }
        startPlayback(at: playbackOrder[nextPosition])
    }

    func previous() {
        guard let position = currentPlaybackPosition else { return }
        if currentTime >= previousRestartThreshold || position == 0 {
            seek(to: 0)
        } else {
            startPlayback(at: playbackOrder[position - 1])
        }
    }

    func toggleShuffle() {
        setShuffleEnabled(!isShuffleEnabled)
    }

    func setShuffleEnabled(_ isEnabled: Bool) {
        guard isShuffleEnabled != isEnabled else { return }
        isShuffleEnabled = isEnabled
        rebuildPlaybackOrder(keepingCurrentIndex: currentIndex)
    }

    func cycleRepeatMode() {
        repeatMode = repeatMode.next
    }

    func pause() {
        audioPlayer.pause()
    }

    func resume() {
        guard currentTrack != nil else { return }
        playbackTask?.cancel()
        let requestID = beginPlaybackRequest()
        isLoading = true
        errorMessage = nil
        playbackTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await audioPlayer.resume()
            } catch is CancellationError {
                return
            } catch {
                guard playbackRequestID == requestID else { return }
                isPlaying = false
                errorMessage = error.localizedDescription
            }
            if playbackRequestID == requestID { isLoading = false }
        }
    }

    func togglePlayPause() {
        isPlaying ? pause() : resume()
    }

    func seek(to time: TimeInterval) {
        audioPlayer.seek(to: time)
    }

    func stop() {
        playbackTask?.cancel()
        playbackTask = nil
        playbackRequestID = UUID()
        audioPlayer.stop()
        queue = []
        playbackOrder = []
        currentIndex = nil
        currentTrack = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        isLoading = false
    }

    func dismissError() { errorMessage = nil }

    private func startPlayback(at index: Int) {
        guard queue.indices.contains(index), playbackOrder.contains(index) else { return }
        playbackTask?.cancel()
        let requestID = beginPlaybackRequest()
        let track = queue[index]
        currentIndex = index
        currentTrack = track
        resetPlaybackSession()
        currentTime = 0
        duration = track.duration
        isPlaying = false
        isLoading = true
        errorMessage = nil

        playbackTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await audioPlayer.play(track)
            } catch is CancellationError {
                return
            } catch {
                guard playbackRequestID == requestID else { return }
                isPlaying = false
                errorMessage = error.localizedDescription
            }
            if playbackRequestID == requestID { isLoading = false }
        }
    }

    private func beginPlaybackRequest() -> UUID {
        let requestID = UUID()
        playbackRequestID = requestID
        return requestID
    }

    private func rebuildPlaybackOrder(keepingCurrentIndex index: Int?) {
        let naturalOrder = Array(queue.indices)
        guard isShuffleEnabled, let index, queue.indices.contains(index) else {
            playbackOrder = naturalOrder
            return
        }
        playbackOrder = [index] + naturalOrder.filter { $0 != index }.shuffled()
    }

    private func nextPlaybackPosition(wrapping: Bool) -> Int? {
        guard let position = currentPlaybackPosition, !playbackOrder.isEmpty else { return nil }
        let nextPosition = position + 1
        if playbackOrder.indices.contains(nextPosition) { return nextPosition }
        return wrapping ? playbackOrder.startIndex : nil
    }

    private func advanceAfterTrackEnded() {
        if repeatMode == .one, let currentIndex {
            startPlayback(at: currentIndex)
            return
        }

        guard let nextPosition = nextPlaybackPosition(wrapping: repeatMode == .all) else {
            isPlaying = false
            return
        }
        startPlayback(at: playbackOrder[nextPosition])
    }

    private func handle(_ event: AudioPlaybackEvent) {
        switch event {
        case let .ready(duration):
            self.duration = duration
            isLoading = false
        case let .timeChanged(time):
            let safeTime = time.isFinite ? time : 0
            recordListenedTime(at: safeTime)
            currentTime = safeTime
        case let .playingChanged(isPlaying):
            self.isPlaying = isPlaying
            if isPlaying, let currentTrack, !hasRecordedPlaybackStart {
                playbackHistoryStore.recordPlaybackStarted(trackID: currentTrack.id)
                hasRecordedPlaybackStart = true
            }
            lastObservedPlaybackTime = isPlaying ? currentTime : nil
        case .ended:
            isPlaying = false
            currentTime = duration
            advanceAfterTrackEnded()
        case let .failed(message):
            isPlaying = false
            isLoading = false
            errorMessage = message
        }
    }

    private func resetPlaybackSession() {
        hasRecordedPlaybackStart = false
        hasCountedCurrentPlay = false
        listenedTime = 0
        lastObservedPlaybackTime = nil
    }

    private func recordListenedTime(at time: TimeInterval) {
        defer { lastObservedPlaybackTime = isPlaying ? time : nil }
        guard isPlaying, !hasCountedCurrentPlay, let previous = lastObservedPlaybackTime else { return }
        let delta = time - previous
        guard delta > 0, delta <= 1.5 else { return }
        listenedTime += delta
        let threshold = min(30, duration * 0.5)
        guard threshold > 0, listenedTime >= threshold, let currentTrack else { return }
        playbackHistoryStore.recordPlaybackCompleted(trackID: currentTrack.id)
        hasCountedCurrentPlay = true
    }
}
