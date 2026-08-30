import Foundation

nonisolated struct Composer: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var trackIDs: [Track.ID]
}
