import Foundation

struct GenreDisplayPreset: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var enabledGenreNames: Set<String>
}
