import Foundation

protocol PlaylistPersistenceServicing: Sendable {
    func load() async throws -> [Playlist]
    func save(_ playlists: [Playlist]) async throws
}

actor PlaylistPersistenceService: PlaylistPersistenceServicing {
    private let fileManager: FileManager
    private let fileURL: URL

    init(fileManager: FileManager = .default, fileURL: URL? = nil) {
        self.fileManager = fileManager
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = applicationSupport.appending(path: "MyMusic/playlists.json")
        }
    }

    func load() async throws -> [Playlist] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try JSONDecoder().decode([Playlist].self, from: data)
    }

    func save(_ playlists: [Playlist]) async throws {
        let directoryURL = fileURL.deletingLastPathComponent()
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(playlists).write(to: fileURL, options: .atomic)
    }
}
