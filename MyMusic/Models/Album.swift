import Foundation

struct Album: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var artistName: String
    var artworkIdentifier: String? = nil
    var year: Int? = nil
    var trackIDs: [Track.ID]
}
