import Foundation
import CryptoKit

/// Original bytes and the complete pre-import local snapshot are retained before replacement.
actor PlaylistImportArchiveService {
    private let directory: URL

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appendingPathComponent("MyMusic/PlaylistImportArchive", isDirectory: true)
    }

    func preserve(original: Data, playlists: [Playlist]) throws {
        let previous = try JSONEncoder().encode(playlists)
        try preserve(original, prefix: "received")
        try preserve(previous, prefix: "before")
    }

    private func preserve(_ data: Data, prefix: String) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let digest = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        let url = directory.appendingPathComponent("\(prefix)-\(digest).json")
        if !FileManager.default.fileExists(atPath: url.path) {
            try data.write(to: url, options: .atomic)
        }
        guard try Data(contentsOf: url) == data else { throw CocoaError(.fileReadCorruptFile) }
    }
}
