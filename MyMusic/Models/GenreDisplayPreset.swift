import Foundation

struct GenreDisplayPreset: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var enabledGenreNames: Set<String>
    var includesUnassignedGenreSetting: Bool? = nil
}

struct GenreDisplayOption: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
}
