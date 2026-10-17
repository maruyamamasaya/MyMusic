// macOS integration check. Compile with RegisteredSceneryVideo.swift, SceneryVideoService.swift and SceneryVideoLibraryService.swift and SceneryVideoStore.swift.
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
        precondition(FileManager.default.fileExists(atPath: saved.path))
        let secondURL = await library.url(for: second)
        precondition(tryData(secondURL) == originalBytes)
        let collection = try await library.videos()
        precondition(collection.count == 2)
        try await library.select(first)
        let selectedAgain = try await SceneryVideoLibraryService(root: root).current()
        precondition(selectedAgain?.id == first.id)
        try await library.select(second)

        // Old single-video documents remain readable and upgrade without losing their media.
        let legacyRoot = directory.appendingPathComponent("legacy")
        try FileManager.default.createDirectory(at: legacyRoot, withIntermediateDirectories: true)
        try originalBytes.write(to: legacyRoot.appendingPathComponent(first.fileName))
        try JSONEncoder().encode(first).write(to: legacyRoot.appendingPathComponent("current.json"))
        let legacy = SceneryVideoLibraryService(root: legacyRoot)
        let legacyCurrent = try await legacy.current()
        precondition(legacyCurrent?.id == first.id)
        _ = try await legacy.register(moved)
        let upgraded = try await legacy.videos()
        precondition(upgraded.count == 2 && upgraded.contains(first))
        precondition(tryData(legacyRoot.appendingPathComponent(first.fileName)) == originalBytes)
        let manifestURL = legacyRoot.appendingPathComponent("current.json")
        let validManifest = try Data(contentsOf: manifestURL)
        try Data("{broken".utf8).write(to: manifestURL)
        do { _ = try await legacy.register(moved); fatalError("Expected corrupt manifest rejection") }
        catch {}
        precondition(tryData(manifestURL) == Data("{broken".utf8))
        try validManifest.write(to: manifestURL)
        let kept = try await legacy.videos()
        precondition(kept.count == 2)
        try await legacy.unregister()

        let settings = SceneryVideoStore(library: library)
        await settings.open(preparesPlayback: false)
        precondition(settings.registeredVideo?.fileName == second.fileName)
        precondition(!settings.isReady && settings.player.currentItem == nil)
        await settings.open(moved, preparesPlayback: false)
        precondition(settings.errorMessage == nil && settings.player.currentItem == nil)
        let scenery = SceneryVideoStore(library: library)
        await scenery.open()
        precondition(scenery.isReady && scenery.player.currentItem != nil)
        scenery.stop()
        precondition(settings.registeredVideos.count == 3)
        await settings.select(second)
        precondition(settings.registeredVideo?.id == second.id)
        await settings.remove(first)
        precondition(settings.registeredVideos.count == 2 && settings.registeredVideo?.id == second.id)
        precondition(!FileManager.default.fileExists(atPath: saved.path))
        await settings.remove(second)
        precondition(settings.registeredVideos.count == 1 && settings.registeredVideo != nil)
        await settings.remove(settings.registeredVideos[0])
        precondition(settings.registeredVideo == nil && settings.registeredVideos.isEmpty && settings.errorMessage == nil)
        await settings.unregister()
        let removed = try await library.current()
        precondition(removed == nil)
        precondition(!FileManager.default.fileExists(atPath: secondURL.path))
        precondition(tryData(moved) == originalBytes)
        print("PASS: random bounds, silent 18fps playback, pause, cleanup, invalid file, byte-exact copy, disk restore after source move, failed replacement preservation, multiple registrations, persistent selection, nonselected and selected removal, legacy migration, corrupt manifest preservation, unregister with source intact, settings metadata and registration without playback, scenery reopening after settings")
    }

    static func tryData(_ url: URL) -> Data? { try? Data(contentsOf: url) }
}
