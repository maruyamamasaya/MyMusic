import Foundation

nonisolated struct Artist: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var albumIDs: [Album.ID]
    var trackIDs: [Track.ID]
}
