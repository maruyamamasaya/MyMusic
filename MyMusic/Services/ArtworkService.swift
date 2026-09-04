import Foundation
import ImageIO
import UIKit

nonisolated protocol ArtworkServicing: Sendable {
    func storeArtwork(_ data: Data, identifier: String) async throws -> String
    func artworkData(for identifier: String) async -> Data?
}

actor ArtworkService: ArtworkServicing {
    nonisolated static let shared = ArtworkService()

    private let directoryURL: URL
    private let memoryCache: NSCache<NSString, NSData>
    private let imageCache: NSCache<NSString, UIImage>
    private var failedImageIdentifiers: Set<String> = []

    init(directoryURL: URL? = nil) {
        let memoryCache = NSCache<NSString, NSData>()
        memoryCache.countLimit = 200
        self.memoryCache = memoryCache
        let imageCache = NSCache<NSString, UIImage>()
        imageCache.countLimit = 80
        self.imageCache = imageCache
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
        failedImageIdentifiers.remove(identifier)
        imageCache.removeObject(forKey: identifier as NSString)
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

    func artworkImage(for identifier: String) async -> UIImage? {
        guard !failedImageIdentifiers.contains(identifier) else { return nil }
        if let cached = imageCache.object(forKey: identifier as NSString) {
            return cached
        }
        guard let data = await artworkData(for: identifier) else {
            failedImageIdentifiers.insert(identifier)
            return nil
        }
        let decodedImage = await Task.detached(priority: .utility) {
            Self.decodeImage(data)
        }.value
        guard let image = decodedImage else {
            failedImageIdentifiers.insert(identifier)
            memoryCache.removeObject(forKey: identifier as NSString)
            return nil
        }
        imageCache.setObject(image, forKey: identifier as NSString)
        return image
    }

    private nonisolated static func decodeImage(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(
            data as CFData,
            [kCGImageSourceShouldCache: false] as CFDictionary
        ), CGImageSourceGetCount(source) > 0,
           CGImageSourceCopyPropertiesAtIndex(source, 0, nil) != nil else { return nil }
        let options: CFDictionary = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: 1_024
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: image)
    }
}
