import Foundation

struct PlaybackHistory: Codable, Hashable, Sendable {
    let trackID: Track.ID
    var isFavorite: Bool
    var playCount: Int
    var lastPlayedAt: Date?
}
