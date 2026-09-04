import Foundation
import MediaPlayer
import UIKit

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
    private var artworkTask: Task<Void, Never>?
    private var currentArtworkIdentifier: String?

    init(infoCenter: MPNowPlayingInfoCenter = .default()) {
        self.infoCenter = infoCenter
    }

    func setTrack(_ track: Track, duration: TimeInterval, elapsedTime: TimeInterval, isPlaying: Bool) {
        artworkTask?.cancel()
        currentArtworkIdentifier = track.artworkIdentifier
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
        loadArtwork(identifier: track.artworkIdentifier)
    }

    func updateDuration(_ duration: TimeInterval, elapsedTime: TimeInterval, isPlaying: Bool) {
        update {
            $0[MPMediaItemPropertyPlaybackDuration] = valid(duration)
            $0[MPNowPlayingInfoPropertyElapsedPlaybackTime] = valid(elapsedTime)
            $0[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        }
    }

    func updatePlayback(elapsedTime: TimeInterval, isPlaying: Bool) {
        update {
            $0[MPNowPlayingInfoPropertyElapsedPlaybackTime] = valid(elapsedTime)
            $0[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? 1.0 : 0.0
        }
    }

    func clear() {
        artworkTask?.cancel()
        artworkTask = nil
        currentArtworkIdentifier = nil
        infoCenter.nowPlayingInfo = nil
    }

    private func update(_ change: (inout [String: Any]) -> Void) {
        guard var info = infoCenter.nowPlayingInfo else { return }
        change(&info)
        infoCenter.nowPlayingInfo = info
    }

    private func valid(_ time: TimeInterval) -> TimeInterval {
        time.isFinite ? max(time, 0) : 0
    }

    private func loadArtwork(identifier: String?) {
        guard let identifier else { return }
        artworkTask = Task { [weak self] in
            guard let image = await ArtworkService.shared.artworkImage(for: identifier),
                  !Task.isCancelled else { return }
            guard let self, currentArtworkIdentifier == identifier else { return }
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { requestedSize in
                image.squareCropped(to: requestedSize)
            }
            update { $0[MPMediaItemPropertyArtwork] = artwork }
        }
    }
}
