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

    private struct Store: Codable {
        var snapshots: [Snapshot]
    }

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
        let data = try Data(contentsOf: fileURL)
        let snapshots: [Snapshot]
        if let store = try? JSONDecoder().decode(Store.self, from: data) {
            snapshots = store.snapshots
        } else {
            snapshots = [try JSONDecoder().decode(Snapshot.self, from: data)]
        }
        guard let snapshot = snapshots.first(where: { $0.folderPath == folderURL.standardizedFileURL.path }) else { return nil }

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
        var snapshots: [Snapshot] = []
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            snapshots = (try? JSONDecoder().decode(Store.self, from: data).snapshots)
                ?? (try? [JSONDecoder().decode(Snapshot.self, from: data)])
                ?? []
        }
        let snapshot = Snapshot(folderPath: folderURL.standardizedFileURL.path, library: library)
        snapshots.removeAll { $0.folderPath == snapshot.folderPath }
        snapshots.append(snapshot)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Store(snapshots: snapshots)).write(to: fileURL, options: .atomic)
    }
}
