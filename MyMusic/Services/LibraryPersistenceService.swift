import Foundation

protocol LibraryPersistenceServicing: Sendable {
    func load(for folderURL: URL) async throws -> MusicLibrary?
    func load(for folderURLs: [URL]) async throws -> [String: MusicLibrary]
    func save(_ library: MusicLibrary, for folderURL: URL) async throws
}

extension LibraryPersistenceServicing {
    func load(for folderURLs: [URL]) async throws -> [String: MusicLibrary] {
        var libraries: [String: MusicLibrary] = [:]
        for folderURL in folderURLs {
            if let library = try await load(for: folderURL) {
                libraries[folderURL.standardizedFileURL.path] = library
            }
        }
        return libraries
    }
}

actor LibraryPersistenceService: LibraryPersistenceServicing {
    private struct TrackSnapshot: Codable {
        let folderPath: String
        let tracks: [Track]
    }

    private struct Store: Codable {
        let version: Int
        var snapshots: [TrackSnapshot]
    }

    private struct LegacySnapshot: Codable {
        let folderPath: String
        let library: MusicLibrary
    }

    private struct LegacyStore: Codable {
        var snapshots: [LegacySnapshot]
    }

    private nonisolated static let currentVersion = 2
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
        try await load(for: [folderURL])[folderURL.standardizedFileURL.path]
    }

    func load(for folderURLs: [URL]) async throws -> [String: MusicLibrary] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [:] }
        let data = try Data(contentsOf: fileURL)
        let snapshots = try decodeSnapshots(from: data)
        let snapshotsByPath = Dictionary(
            snapshots.map { ($0.folderPath, $0.tracks) },
            uniquingKeysWith: { _, latest in latest }
        )
        var libraries: [String: MusicLibrary] = [:]
        libraries.reserveCapacity(folderURLs.count)

        for folderURL in folderURLs {
            let folderPath = folderURL.standardizedFileURL.path
            guard let cachedTracks = snapshotsByPath[folderPath] else { continue }
            let tracks = cachedTracks.map { track in
                var restoredTrack = track
                if let relativePath = track.relativePath, !relativePath.isEmpty {
                    restoredTrack.fileURL = folderURL.appending(path: relativePath)
                }
                return restoredTrack
            }
            // Album/Artist/Genre/Composer are derived from tracks. Rebuilding here
            // migrates cached random IDs and keeps every relationship consistent.
            libraries[folderPath] = MusicLibrary.build(from: tracks)
        }
        return libraries
    }

    func save(_ library: MusicLibrary, for folderURL: URL) async throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var snapshots: [TrackSnapshot] = []
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            snapshots = (try? decodeSnapshots(from: data)) ?? []
        }
        let snapshot = TrackSnapshot(folderPath: folderURL.standardizedFileURL.path, tracks: library.tracks)
        snapshots.removeAll { $0.folderPath == snapshot.folderPath }
        snapshots.append(snapshot)
        try JSONEncoder().encode(Store(version: Self.currentVersion, snapshots: snapshots))
            .write(to: fileURL, options: .atomic)
    }

    private func decodeSnapshots(from data: Data) throws -> [TrackSnapshot] {
        let decoder = JSONDecoder()
        if let store = try? decoder.decode(Store.self, from: data),
           store.version == Self.currentVersion {
            return store.snapshots
        }
        if let legacyStore = try? decoder.decode(LegacyStore.self, from: data) {
            return legacyStore.snapshots.map {
                TrackSnapshot(folderPath: $0.folderPath, tracks: $0.library.tracks)
            }
        }
        let legacySnapshot = try decoder.decode(LegacySnapshot.self, from: data)
        return [TrackSnapshot(folderPath: legacySnapshot.folderPath, tracks: legacySnapshot.library.tracks)]
    }
}
