import Foundation

nonisolated struct Album: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var artistName: String
    var artworkIdentifier: String? = nil
    var year: Int? = nil
    var trackIDs: [Track.ID]
    // IDs used by the pre-Album-Artist grouping remain valid favorite aliases.
    var legacyAlbumIDs: Set<Album.ID>? = nil
}
