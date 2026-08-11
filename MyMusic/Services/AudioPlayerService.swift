import Foundation

protocol AudioPlayerServicing: AnyObject {
    func play(_ track: Track)
    func pause()
    func resume()
    func seek(to time: TimeInterval)
    func next()
    func previous()
    func setQueue(_ tracks: [Track])
}

final class AudioPlayerService: AudioPlayerServicing {
    func play(_ track: Track) {}
    func pause() {}
    func resume() {}
    func seek(to time: TimeInterval) {}
    func next() {}
    func previous() {}
    func setQueue(_ tracks: [Track]) {}
}
