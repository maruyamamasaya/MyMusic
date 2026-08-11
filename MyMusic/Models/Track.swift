import Foundation

struct Track: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var artistName: String
    var albumTitle: String? = nil
    var duration: TimeInterval
    var fileURL: URL
    var artworkIdentifier: String? = nil
    var trackNumber: Int? = nil
    var discNumber: Int? = nil
    var year: Int? = nil
    var genre: String? = nil
    var audioFormat: AudioFormat? = nil
}
