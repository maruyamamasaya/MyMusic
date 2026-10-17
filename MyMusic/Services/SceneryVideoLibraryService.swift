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

    private func collection() throws -> SceneryVideoCollection {
        guard files.fileExists(atPath: manifest.path) else { return SceneryVideoCollection() }
        let data = try Data(contentsOf: manifest)
        let result: SceneryVideoCollection
        if let document = try? JSONDecoder().decode(SceneryVideoCollection.self, from: data) {
            guard document.version == 2 else { throw LibraryError.invalidLibrary }
            result = document
        } else {
            // Preserve the existing single-video registration without copying or deleting its file.
            let legacy = try JSONDecoder().decode(RegisteredSceneryVideo.self, from: data)
            result = SceneryVideoCollection(videos: [legacy], selectedFileName: legacy.fileName)
        }
        guard Set(result.videos.map(\.fileName)).count == result.videos.count,
              result.selectedFileName == nil || result.videos.contains(where: { $0.fileName == result.selectedFileName }),
              result.videos.allSatisfy({ $0.fileName == URL(fileURLWithPath: $0.fileName).lastPathComponent
                  && !$0.fileName.hasPrefix(".") && $0.byteCount > 0 }) else {
            throw LibraryError.invalidLibrary
        }
        return result
    }

    func videos() throws -> [RegisteredSceneryVideo] { try collection().videos }

    func current() throws -> RegisteredSceneryVideo? {
        let document = try collection()
        guard let video = document.videos.first(where: { $0.fileName == document.selectedFileName }) else { return nil }
        guard files.fileExists(atPath: root.appendingPathComponent(video.fileName).path) else {
            throw LibraryError.missingVideo
        }
        return video
    }

    private func save(_ document: SceneryVideoCollection) throws {
        try JSONEncoder().encode(document).write(to: manifest, options: .atomic)
    }

    func select(_ video: RegisteredSceneryVideo) throws {
        var document = try collection()
        guard document.videos.contains(where: { $0.fileName == video.fileName }),
              files.fileExists(atPath: root.appendingPathComponent(video.fileName).path) else {
            throw LibraryError.missingVideo
        }
        document.selectedFileName = video.fileName
        try save(document)
    }

    func remove(_ video: RegisteredSceneryVideo) throws {
        var document = try collection()
        guard document.videos.contains(where: { $0.fileName == video.fileName }) else { return }
        document.videos.removeAll { $0.fileName == video.fileName }
        if document.selectedFileName == video.fileName { document.selectedFileName = document.videos.first?.fileName }
        try save(document)
        cleanup(keeping: Set(document.videos.map(\.fileName)))
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
        var document = try collection()
        document.videos.append(video)
        document.selectedFileName = name
        try save(document)
        committed = true
        cleanup(keeping: Set(document.videos.map(\.fileName)))
        return video
    }

    func unregister() throws {
        // Remove the registration first; never touch the original file selected in Files.
        if files.fileExists(atPath: manifest.path) { try files.removeItem(at: manifest) }
        if files.fileExists(atPath: root.path) { try files.removeItem(at: root) }
    }

    private func cleanup(keeping names: Set<String>) {
        guard let contents = try? files.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return }
        for url in contents where !names.contains(url.lastPathComponent) && url.lastPathComponent != "current.json" {
            try? files.removeItem(at: url)
        }
    }

    private enum LibraryError: LocalizedError {
        case missingVideo, invalidVideo, invalidLibrary
        var errorDescription: String? {
            switch self {
            case .invalidLibrary: "動画の登録情報を読み込めませんでした。登録情報は変更していません。"
            case .missingVideo: "保存した動画が見つかりません。動画を再登録するか、登録を解除してください。"
            case .invalidVideo: "このファイルには再生できる映像がありません。別の動画を選んでください。"
            }
        }
    }
}
