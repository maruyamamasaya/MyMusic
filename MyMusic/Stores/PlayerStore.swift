import Foundation
import Observation

@Observable
final class PlayerStore {
    enum RepeatMode { case off, all, one }

    private(set) var currentTrack: Track?
    private(set) var isPlaying = false
    var currentTime: TimeInterval = 0
    var duration: TimeInterval = 0
    private(set) var queue: [Track] = []
    var isShuffleEnabled = false
    var repeatMode: RepeatMode = .off

    private let audioPlayer: AudioPlayerServicing

    init(audioPlayer: AudioPlayerServicing = AudioPlayerService()) {
        self.audioPlayer = audioPlayer
    }

    func play(_ track: Track) { currentTrack = track; isPlaying = true; audioPlayer.play(track) }
    func pause() { isPlaying = false; audioPlayer.pause() }
    func resume() { guard currentTrack != nil else { return }; isPlaying = true; audioPlayer.resume() }
    func togglePlayPause() { isPlaying ? pause() : resume() }
    func next() { audioPlayer.next() }
    func previous() { audioPlayer.previous() }
    func seek(to time: TimeInterval) { currentTime = time; audioPlayer.seek(to: time) }
    func setQueue(_ tracks: [Track]) { queue = tracks; audioPlayer.setQueue(tracks) }
}
