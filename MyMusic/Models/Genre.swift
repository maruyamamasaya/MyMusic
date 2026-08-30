import Foundation

nonisolated struct Genre: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var trackIDs: [Track.ID]
}
