import Foundation

struct ListenLaterEntry: Codable, Equatable, Sendable {
    let trackID: Track.ID
    let playCountWhenAdded: Int
    let addedAt: Date
}
