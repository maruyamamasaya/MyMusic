import Foundation

nonisolated struct LibraryYear: Identifiable, Hashable, Sendable {
    /// nil represents missing or invalid tag years.
    let year: Int?
    let trackIDs: [Track.ID]

    var id: Int? { year }
}
