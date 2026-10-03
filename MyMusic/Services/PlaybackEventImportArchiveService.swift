import Foundation
import CryptoKit

/// Keeps the complete received bytes independently of the filtered import and history DB.
actor PlaybackEventImportArchiveService {
    private let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent("MyMusic/PlaybackEventImportOriginals", isDirectory: true)
    }

    func preserve(_ data: Data) throws -> URL {
        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let destination = directory.appendingPathComponent("\(digest).json")
        // Never overwrite an existing original, including a damaged archive.
        if !manager.fileExists(atPath: destination.path) {
            try data.write(to: destination, options: .atomic)
        }
        guard try Data(contentsOf: destination) == data else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return destination
    }
}
