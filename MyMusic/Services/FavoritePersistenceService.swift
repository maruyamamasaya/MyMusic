import Foundation

protocol FavoritePersistenceServicing: Sendable {
    func load() async throws -> LibraryFavorites
    func save(_ favorites: LibraryFavorites) async throws
}

actor FavoritePersistenceService: FavoritePersistenceServicing {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "MyMusic/library-favorites.json")
    }

    func load() async throws -> LibraryFavorites {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return LibraryFavorites() }
        return try JSONDecoder().decode(LibraryFavorites.self, from: Data(contentsOf: fileURL))
    }

    func save(_ favorites: LibraryFavorites) async throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(favorites).write(to: fileURL, options: .atomic)
    }
}
