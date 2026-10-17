// macOS integration check. Compile with RegisteredSceneryVideo.swift, SceneryVideoService.swift and SceneryVideoLibraryService.swift.
import AVFoundation

@main struct Check {
    @MainActor static func main() async throws {
        precondition(SceneryVideoService.startPosition(duration: 18000, fraction: 0.5) == 8985)
        precondition(SceneryVideoService.startPosition(duration: 10, fraction: 1) == 5)
        precondition(SceneryVideoService.startPosition(duration: .nan, fraction: 1) == 0)
        precondition(SceneryVideoService.startPosition(duration: 100, fraction: -.infinity) == 0)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("mymusic-scenery-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("source.mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 64, AVVideoHeightKey: 64
        ])
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input,
            sourcePixelBufferAttributes: [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
                                          kCVPixelBufferWidthKey as String: 64, kCVPixelBufferHeightKey as String: 64])
        writer.add(input)
        precondition(writer.startWriting(), "\(String(describing: writer.error))")
        writer.startSession(atSourceTime: .zero)
        for frame in 0..<60 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(for: .milliseconds(5)) }
            var buffer: CVPixelBuffer?
            guard let pool = adaptor.pixelBufferPool else { fatalError("Pixel buffer pool unavailable: \(String(describing: writer.error))") }
            precondition(CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer) == kCVReturnSuccess)
            CVPixelBufferLockBaseAddress(buffer!, [])
            memset(CVPixelBufferGetBaseAddress(buffer!), 0, CVPixelBufferGetDataSize(buffer!))
            CVPixelBufferUnlockBaseAddress(buffer!, [])
            precondition(adaptor.append(buffer!, withPresentationTime: CMTime(value: Int64(frame), timescale: 30)))
        }
        input.markAsFinished()
        await writer.finishWriting()
        precondition(writer.status == .completed)
        let service = SceneryVideoService()
        try await service.load(url)
        precondition(service.player.isMuted)
        let item = service.player.currentItem!
        let audio = try await item.asset.loadTracks(withMediaType: .audio)
        precondition(audio.isEmpty)
        precondition(item.videoComposition!.frameDuration == CMTime(value: 1, timescale: 18))
        precondition(service.player.currentTime().seconds < 1.1)
        service.setActive(false)
        precondition(service.player.rate == 0)
        service.stop()
        precondition(service.player.currentItem == nil)
        do { try await service.load(directory.appendingPathComponent("missing.mov")); fatalError("Expected error") }
        catch { service.stop() }
        let root = directory.appendingPathComponent("library")
        let library = SceneryVideoLibraryService(root: root)
        let first = try await library.register(url)
        let saved = await library.url(for: first)
        let originalBytes = try Data(contentsOf: url)
        precondition(tryData(saved) == originalBytes)
        // A new service instance restores solely from disk, independent of the source URL.
        let moved = directory.appendingPathComponent("moved.mov")
        try FileManager.default.moveItem(at: url, to: moved)
        let restored = try await SceneryVideoLibraryService(root: root).current()
        precondition(restored?.fileName == first.fileName)
        try await service.load(saved)
        service.stop()
        let bad = directory.appendingPathComponent("bad.mov")
        try Data("invalid video".utf8).write(to: bad)
        do { _ = try await library.register(bad); fatalError("Expected invalid video rejection") }
        catch {}
        let preserved = try await library.current()
        precondition(preserved?.fileName == first.fileName)
        precondition(tryData(saved) == originalBytes)
        let second = try await library.register(moved)
        precondition(second.fileName != first.fileName)
        precondition(!FileManager.default.fileExists(atPath: saved.path))
        let secondURL = await library.url(for: second)
        precondition(tryData(secondURL) == originalBytes)
        try await library.unregister()
        let removed = try await library.current()
        precondition(removed == nil)
        precondition(!FileManager.default.fileExists(atPath: secondURL.path))
        precondition(tryData(moved) == originalBytes)
        print("PASS: random bounds, silent 18fps playback, pause, cleanup, invalid file, byte-exact copy, disk restore after source move, failed replacement preservation, replacement cleanup, unregister with source intact")
    }

    static func tryData(_ url: URL) -> Data? { try? Data(contentsOf: url) }
}
