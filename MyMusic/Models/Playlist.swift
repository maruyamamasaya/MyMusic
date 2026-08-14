import Foundation

struct Playlist: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var trackIDs: [Track.ID]
    let createdAt: Date
    var updatedAt: Date
    var description: String? = nil
    var artworkIdentifier: String? = nil
    var searchDefinition: PlaylistSearchDefinition? = nil
}
