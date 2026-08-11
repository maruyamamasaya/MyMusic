import Foundation
import Observation

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

    var hasNext: Bool {
        guard let currentIndex else { return false }
        return queue.indices.contains(currentIndex + 1)
    }

    var hasPrevious: Bool {
        guard let currentIndex else { return false }
        return currentTime > 0 || queue.indices.contains(currentIndex - 1)
    }

    private let previousRestartThreshold: TimeInterval = 3
    private let audioPlayer: AudioPlayerServicing
    private var playbackTask: Task<Void, Never>?
    private var playbackRequestID = UUID()

    init(audioPlayer: AudioPlayerServicing? = nil) {
        let resolvedPlayer = audioPlayer ?? AudioPlayerService()
        self.audioPlayer = resolvedPlayer
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
        guard let currentIndex else { return }
        let nextIndex = currentIndex + 1
        guard queue.indices.contains(nextIndex) else {
            audioPlayer.pause()
            isPlaying = false
            return
        }
        startPlayback(at: nextIndex)
    }

    func previous() {
        guard let currentIndex else { return }
        if currentTime >= previousRestartThreshold || !queue.indices.contains(currentIndex - 1) {
            seek(to: 0)
        } else {
            startPlayback(at: currentIndex - 1)
        }
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
        currentIndex = nil
        currentTrack = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        isLoading = false
    }

    func dismissError() { errorMessage = nil }

    private func startPlayback(at index: Int) {
        guard queue.indices.contains(index) else { return }
        playbackTask?.cancel()
        let requestID = beginPlaybackRequest()
        let track = queue[index]
        currentIndex = index
        currentTrack = track
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

    private func handle(_ event: AudioPlaybackEvent) {
        switch event {
        case let .ready(duration):
            self.duration = duration
            isLoading = false
        case let .timeChanged(time):
            currentTime = time.isFinite ? time : 0
        case let .playingChanged(isPlaying):
            self.isPlaying = isPlaying
        case .ended:
            isPlaying = false
            currentTime = duration
            next()
        case let .failed(message):
            isPlaying = false
            isLoading = false
            errorMessage = message
        }
    }
}
