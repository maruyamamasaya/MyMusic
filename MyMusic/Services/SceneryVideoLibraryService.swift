import AVFoundation

/// Copies large files off MainActor. The manifest is the commit point for replacement.
actor SceneryVideoLibraryService {
    private let root: URL
    private let files = FileManager.default

    init(root: URL? = nil) {
        self.root = root ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MyMusic/SceneryVideo", isDirectory: true)
    }

    private var manifest: URL { root.appendingPathComponent("current.json") }

    func current() throws -> RegisteredSceneryVideo? {
        guard files.fileExists(atPath: manifest.path) else { return nil }
        let video = try JSONDecoder().decode(RegisteredSceneryVideo.self, from: Data(contentsOf: manifest))
        guard video.fileName == URL(fileURLWithPath: video.fileName).lastPathComponent,
              !video.fileName.hasPrefix("."), video.byteCount > 0,
              files.fileExists(atPath: root.appendingPathComponent(video.fileName).path) else {
            throw LibraryError.missingVideo
        }
        return video
    }

    func url(for video: RegisteredSceneryVideo) -> URL { root.appendingPathComponent(video.fileName) }

    func register(_ source: URL) async throws -> RegisteredSceneryVideo {
        try Task.checkCancellation()
        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        let suffix = source.pathExtension.isEmpty ? "mov" : source.pathExtension
        let name = UUID().uuidString + "." + suffix
        let destination = root.appendingPathComponent(name)
        var committed = false
        defer { if !committed { try? files.removeItem(at: destination) } }

        // File coordination also lets File Providers materialize an iCloud selection.
        var coordinationError: NSError?
        var copyError: Error?
        NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { readable in
            do { try self.files.copyItem(at: readable, to: destination) }
            catch { copyError = error }
        }
        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }
        try Task.checkCancellation()
        let attributes = try files.attributesOfItem(atPath: destination.path)
        guard let size = attributes[.size] as? NSNumber, size.int64Value > 0 else { throw LibraryError.missingVideo }
        let asset = AVURLAsset(url: destination)
        let playable = try await asset.load(.isPlayable)
        let duration = try await asset.load(.duration)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        try Task.checkCancellation()
        guard playable, !tracks.isEmpty, duration.seconds.isFinite, duration.seconds > 0 else {
            throw LibraryError.invalidVideo
        }
        let video = RegisteredSceneryVideo(fileName: name, originalName: source.lastPathComponent,
                                           byteCount: size.int64Value)
        // Persist only after a complete copy and validation; a failed write leaves the old selection.
        try JSONEncoder().encode(video).write(to: manifest, options: .atomic)
        committed = true
        cleanup(except: name)
        return video
    }

    func unregister() throws {
        // Remove the registration first; never touch the original file selected in Files.
        if files.fileExists(atPath: manifest.path) { try files.removeItem(at: manifest) }
        if files.fileExists(atPath: root.path) { try files.removeItem(at: root) }
    }

    private func cleanup(except name: String) {
        guard let contents = try? files.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        for url in contents where url.lastPathComponent != name && url.lastPathComponent != "current.json" {
            try? files.removeItem(at: url)
        }
    }

    private enum LibraryError: LocalizedError {
        case missingVideo, invalidVideo
        var errorDescription: String? {
            switch self {
            case .missingVideo: "保存した動画が見つかりません。動画を再登録するか、登録を解除してください。"
            case .invalidVideo: "このファイルには再生できる映像がありません。別の動画を選んでください。"
            }
        }
    }
}
