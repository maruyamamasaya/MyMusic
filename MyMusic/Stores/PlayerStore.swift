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

    private let audioPlayer: AudioPlayerServicing
    private var playbackTask: Task<Void, Never>?

    init(audioPlayer: AudioPlayerServicing? = nil) {
        let resolvedPlayer = audioPlayer ?? AudioPlayerService()
        self.audioPlayer = resolvedPlayer
        resolvedPlayer.eventHandler = { [weak self] event in
            self?.handle(event)
        }
    }

    func play(_ track: Track) {
        playbackTask?.cancel()
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
                isPlaying = false
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func pause() {
        audioPlayer.pause()
    }

    func resume() {
        guard currentTrack != nil else { return }
        playbackTask?.cancel()
        isLoading = true
        errorMessage = nil
        playbackTask = Task { [weak self] in
            guard let self else { return }
            do {
                try await audioPlayer.resume()
            } catch is CancellationError {
                return
            } catch {
                isPlaying = false
                errorMessage = error.localizedDescription
            }
            isLoading = false
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
        audioPlayer.stop()
        currentTrack = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        isLoading = false
    }

    func dismissError() { errorMessage = nil }

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
        case let .failed(message):
            isPlaying = false
            isLoading = false
            errorMessage = message
        }
    }
}
