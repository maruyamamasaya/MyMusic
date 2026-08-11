import Foundation

struct PlaybackHistory: Codable, Hashable, Sendable {
    let trackID: Track.ID
    var isFavorite: Bool
    var playCount: Int
    var lastPlayedAt: Date?
    var playbackPreference: Int

    init(
        trackID: Track.ID,
        isFavorite: Bool,
        playCount: Int,
        lastPlayedAt: Date?,
        playbackPreference: Int = 0
    ) {
        self.trackID = trackID
        self.isFavorite = isFavorite
        self.playCount = playCount
        self.lastPlayedAt = lastPlayedAt
        self.playbackPreference = playbackPreference
    }

    private enum CodingKeys: String, CodingKey {
        case trackID, isFavorite, playCount, lastPlayedAt, playbackPreference
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trackID = try container.decode(Track.ID.self, forKey: .trackID)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        playCount = try container.decode(Int.self, forKey: .playCount)
        lastPlayedAt = try container.decodeIfPresent(Date.self, forKey: .lastPlayedAt)
        playbackPreference = try container.decodeIfPresent(Int.self, forKey: .playbackPreference) ?? 0
    }
}
