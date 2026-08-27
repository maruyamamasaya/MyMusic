import Foundation

protocol ArtworkServicing: Sendable {
    func storeArtwork(_ data: Data, identifier: String) async throws -> String
    func artworkData(for identifier: String) async -> Data?
}

actor ArtworkService: ArtworkServicing {
    @MainActor static let shared = ArtworkService()

    private let directoryURL: URL
    private let memoryCache: NSCache<NSString, NSData>

    init(directoryURL: URL? = nil) {
        let memoryCache = NSCache<NSString, NSData>()
        memoryCache.countLimit = 200
        self.memoryCache = memoryCache
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
        memoryCache.setObject(data as NSData, forKey: identifier as NSString)
        return identifier
    }

    func artworkData(for identifier: String) async -> Data? {
        if let cached = memoryCache.object(forKey: identifier as NSString) {
            return cached as Data
        }
        guard let data = try? Data(
            contentsOf: directoryURL.appending(path: identifier),
            options: .mappedIfSafe
        ) else { return nil }
        memoryCache.setObject(data as NSData, forKey: identifier as NSString)
        return data
    }
}
