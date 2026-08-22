import Foundation

struct Track: Identifiable, Codable, Hashable, Sendable {
    static let longFormMinimumDuration: TimeInterval = 20 * 60

    let id: UUID
    var title: String
    var artistName: String
    var albumTitle: String? = nil
    var duration: TimeInterval
    var fileURL: URL
    var relativePath: String? = nil
    var fileSize: Int64? = nil
    var modificationDate: Date? = nil
    var artworkIdentifier: String? = nil
    var trackNumber: Int? = nil
    var discNumber: Int? = nil
    var year: Int? = nil
    var genre: String? = nil
    var composer: String? = nil
    var audioFormat: AudioFormat? = nil

    var isLongForm: Bool {
        duration >= Self.longFormMinimumDuration
    }
}
