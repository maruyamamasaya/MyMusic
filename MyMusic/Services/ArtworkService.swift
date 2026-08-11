import Foundation

protocol ArtworkServicing: Sendable {
    func storeArtwork(_ data: Data, identifier: String) async throws -> String
    func artworkData(for identifier: String) async -> Data?
}

actor ArtworkService: ArtworkServicing {
    @MainActor static let shared = ArtworkService()

    private let directoryURL: URL

    init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.directoryURL = applicationSupport.appending(path: "MyMusic/Artwork", directoryHint: .isDirectory)
        }
    }

    func storeArtwork(_ data: Data, identifier: String) async throws -> String {
        let fileURL = directoryURL.appending(path: identifier)
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        if !fileManager.fileExists(atPath: fileURL.path) {
            try data.write(to: fileURL, options: .atomic)
        }
        return identifier
    }

    func artworkData(for identifier: String) async -> Data? {
        try? Data(contentsOf: directoryURL.appending(path: identifier), options: .mappedIfSafe)
    }
}
