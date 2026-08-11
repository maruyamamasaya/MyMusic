import Foundation
import MediaPlayer

@MainActor
protocol NowPlayingServicing: AnyObject {
    func setTrack(_ track: Track, duration: TimeInterval, elapsedTime: TimeInterval, isPlaying: Bool)
    func updateDuration(_ duration: TimeInterval, elapsedTime: TimeInterval, isPlaying: Bool)
    func updatePlayback(elapsedTime: TimeInterval, isPlaying: Bool)
    func clear()
}

@MainActor
final class NowPlayingService: NowPlayingServicing {
    private let infoCenter: MPNowPlayingInfoCenter

    init(infoCenter: MPNowPlayingInfoCenter = .default()) {
        self.infoCenter = infoCenter
    }

    func setTrack(_ track: Track, duration: TimeInterval, elapsedTime: TimeInterval, isPlaying: Bool) {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artistName,
            MPMediaItemPropertyPlaybackDuration: valid(duration),
            MPNowPlayingInfoPropertyElapsedPlaybackTime: valid(elapsedTime),
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0
        ]
        if let albumTitle = track.albumTitle, !albumTitle.isEmpty {
            info[MPMediaItemPropertyAlbumTitle] = albumTitle
        }
        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = isPlaying ? .playing : .paused
    }

    func updateDuration(_ duration: TimeInterval, elapsedTime: TimeInterval, isPlaying: Bool) {
        update {
            $0[MPMediaItemPropertyPlaybackDuration] = valid(duration)
            $0[MPNowPlayingInfoPropertyElapsedPlaybackTime] = valid(elapsedTime)
            $0[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        }
        infoCenter.playbackState = isPlaying ? .playing : .paused
    }

    func updatePlayback(elapsedTime: TimeInterval, isPlaying: Bool) {
        update {
            $0[MPNowPlayingInfoPropertyElapsedPlaybackTime] = valid(elapsedTime)
            $0[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        }
        infoCenter.playbackState = isPlaying ? .playing : .paused
    }

    func clear() {
        infoCenter.nowPlayingInfo = nil
        infoCenter.playbackState = .stopped
    }

    private func update(_ change: (inout [String: Any]) -> Void) {
        guard var info = infoCenter.nowPlayingInfo else { return }
        change(&info)
        infoCenter.nowPlayingInfo = info
    }

    private func valid(_ time: TimeInterval) -> TimeInterval {
        time.isFinite ? max(time, 0) : 0
    }
}
