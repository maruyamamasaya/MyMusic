import CryptoKit
import Foundation

enum StableLibraryIdentifier {
    nonisolated static func albumID(title: String, artistName: String) -> UUID {
        id(for: "album\u{1F}\(artistName)\u{1F}\(title)")
    }

    nonisolated static func artistID(name: String) -> UUID {
        id(for: "artist\u{1F}\(name)")
    }

    private nonisolated static func id(for value: String) -> UUID {
        let normalized = value.precomposedStringWithCanonicalMapping
        let digest = SHA256.hash(data: Data(normalized.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x50
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
