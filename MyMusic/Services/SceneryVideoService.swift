import AVFoundation

/// Owns only the silent scenery player. Never configures the music audio session.
@MainActor
final class SceneryVideoService {
    let player = AVPlayer()
    private var scopedURL: URL?
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var generation = UUID()
    private var wantsPlayback = false
    var onFailure: ((String) -> Void)?

    init() {
        player.isMuted = true
        player.preventsDisplaySleepDuringVideoPlayback = false
    }

    func load(_ url: URL) async throws {
        stop()
        let request = generation
        if url.startAccessingSecurityScopedResource() { scopedURL = url }
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        try Task.checkCancellation()
        guard request == generation else { throw CancellationError() }
        guard let source = tracks.first, duration.seconds.isFinite, duration.seconds > 0 else {
            throw SceneryVideoError.invalidVideo
        }

        // A video-only composition prevents the scenery from contributing audio.
        let composition = AVMutableComposition()
        guard let track = composition.addMutableTrack(withMediaType: .video,
                                                       preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw SceneryVideoError.invalidVideo
        }
        let transform = try await source.load(.preferredTransform)
        try Task.checkCancellation()
        guard request == generation else { throw CancellationError() }
        try track.insertTimeRange(CMTimeRange(start: .zero, duration: duration), of: source, at: .zero)
        track.preferredTransform = transform
        let rendering = try await AVMutableVideoComposition.videoComposition(withPropertiesOf: composition)
        try Task.checkCancellation()
        guard request == generation else { throw CancellationError() }
        rendering.frameDuration = CMTime(value: 1, timescale: 18)
        // Bound composition output size, including portrait sources, without upscaling.
        let size = rendering.renderSize
        let scale = min(1, 1280 / max(size.width, size.height))
        // Scale output while preserving generated spatial instructions.
        rendering.renderScale = Float(scale)
        let item = AVPlayerItem(asset: composition)
        item.videoComposition = rendering
        item.preferredForwardBufferDuration = 3
        player.replaceCurrentItem(with: item)
        statusObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            let failed = item.status == .failed
            let message = item.error?.localizedDescription ?? "動画を再生できませんでした。"
            Task { @MainActor [weak self] in
                guard let self, self.generation == request, failed else { return }
                self.player.pause()
                self.onFailure?(message)
            }
        }
        endObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime,
                                                              object: item, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.generation == request else { return }
                await self.player.seek(to: .zero)
                guard self.generation == request else { return }
                self.setActive(self.wantsPlayback)
            }
        }
        let start = Self.startPosition(duration: duration.seconds, fraction: Double.random(in: 0..<1))
        let completed = await player.seek(to: CMTime(seconds: start, preferredTimescale: 600),
                                         toleranceBefore: CMTime(seconds: 1, preferredTimescale: 600),
                                         toleranceAfter: CMTime(seconds: 1, preferredTimescale: 600))
        try Task.checkCancellation()
        guard request == generation else { throw CancellationError() }
        guard completed else { throw SceneryVideoError.invalidVideo }
    }

    static func startPosition(duration: Double, fraction: Double) -> Double {
        guard duration.isFinite, duration > 0, fraction.isFinite else { return 0 }
        // Leave up to 30 seconds before the end so opening does not immediately loop.
        return max(0, duration - min(30, duration / 2)) * min(1, max(0, fraction))
    }

    func setActive(_ active: Bool) {
        wantsPlayback = active
        if active { player.play() } else { player.pause() }
    }

    func stop() {
        generation = UUID()
        wantsPlayback = false
        player.pause()
        statusObservation = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
        player.replaceCurrentItem(with: nil)
        scopedURL?.stopAccessingSecurityScopedResource()
        scopedURL = nil
    }
}

private enum SceneryVideoError: LocalizedError {
    case invalidVideo
    var errorDescription: String? { "再生できる映像がありません。端末にダウンロード済みの動画を選んでください。" }
}
