import Foundation

struct PlaybackHistory: Codable, Hashable, Sendable {
    let trackID: Track.ID
    var isFavorite: Bool
    var playCount: Int
    var lastPlayedAt: Date?
    var playbackPreference: Int
    var playbackEvents: [Date]
    var boredomCount: Int
    var boredomHiddenUntil: Date?
    var isPermanentlyHiddenFromShuffle: Bool

    init(
        trackID: Track.ID,
        isFavorite: Bool,
        playCount: Int,
        lastPlayedAt: Date?,
        playbackPreference: Int = 0,
        playbackEvents: [Date] = [],
        boredomCount: Int = 0,
        boredomHiddenUntil: Date? = nil,
        isPermanentlyHiddenFromShuffle: Bool = false
    ) {
        self.trackID = trackID
        self.isFavorite = isFavorite
        self.playCount = playCount
        self.lastPlayedAt = lastPlayedAt
        self.playbackPreference = playbackPreference
        self.playbackEvents = playbackEvents
        self.boredomCount = boredomCount
        self.boredomHiddenUntil = boredomHiddenUntil
        self.isPermanentlyHiddenFromShuffle = isPermanentlyHiddenFromShuffle
    }

    private enum CodingKeys: String, CodingKey {
        case trackID, isFavorite, playCount, lastPlayedAt, playbackPreference, playbackEvents
        case boredomCount, boredomHiddenUntil, isPermanentlyHiddenFromShuffle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        trackID = try container.decode(Track.ID.self, forKey: .trackID)
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        playCount = try container.decode(Int.self, forKey: .playCount)
        lastPlayedAt = try container.decodeIfPresent(Date.self, forKey: .lastPlayedAt)
        playbackPreference = try container.decodeIfPresent(Int.self, forKey: .playbackPreference) ?? 0
        playbackEvents = try container.decodeIfPresent([Date].self, forKey: .playbackEvents)
            ?? lastPlayedAt.map { [$0] }
            ?? []
        boredomCount = try container.decodeIfPresent(Int.self, forKey: .boredomCount) ?? 0
        boredomHiddenUntil = try container.decodeIfPresent(Date.self, forKey: .boredomHiddenUntil)
        isPermanentlyHiddenFromShuffle = try container.decodeIfPresent(Bool.self, forKey: .isPermanentlyHiddenFromShuffle) ?? false
    }
}
