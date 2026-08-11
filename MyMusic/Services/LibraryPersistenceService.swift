import Foundation

protocol LibraryPersistenceServicing: Sendable {
    func load(for folderURL: URL) async throws -> MusicLibrary?
    func save(_ library: MusicLibrary, for folderURL: URL) async throws
}

actor LibraryPersistenceService: LibraryPersistenceServicing {
    private struct Snapshot: Codable {
        let folderPath: String
        let library: MusicLibrary
    }

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = applicationSupport.appending(path: "MyMusic/library-index.json")
        }
    }

    func load(for folderURL: URL) async throws -> MusicLibrary? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let snapshot = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: fileURL))
        guard snapshot.folderPath == folderURL.standardizedFileURL.path else { return nil }

        let tracks = snapshot.library.tracks.map { track in
            var restoredTrack = track
            if let relativePath = track.relativePath, !relativePath.isEmpty {
                restoredTrack.fileURL = folderURL.appending(path: relativePath)
            }
            return restoredTrack
        }
        // Album/Artist/Genre/Composer are derived from tracks. Rebuilding here
        // migrates cached random IDs and keeps every relationship consistent.
        return MusicLibrary.build(from: tracks)
    }

    func save(_ library: MusicLibrary, for folderURL: URL) async throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let snapshot = Snapshot(folderPath: folderURL.standardizedFileURL.path, library: library)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }
}
