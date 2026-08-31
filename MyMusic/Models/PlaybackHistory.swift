import Foundation

struct PlaybackHistory: Codable, Hashable, Sendable {
    let trackID: Track.ID
    var isFavorite: Bool
    var playCount: Int
    var lastPlayedAt: Date?
    var playbackPreference: Int
    var playbackEvents: [Date]
    var totalPlaybackDuration: TimeInterval
    var skipCount: Int
    var fullPlaybackCount: Int
    var consecutivePlayCount: Int
    var repeatPlaybackCount: Int
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
        totalPlaybackDuration: TimeInterval = 0,
        skipCount: Int = 0,
        fullPlaybackCount: Int = 0,
        consecutivePlayCount: Int = 0,
        repeatPlaybackCount: Int = 0,
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
        self.totalPlaybackDuration = totalPlaybackDuration
        self.skipCount = skipCount
        self.fullPlaybackCount = fullPlaybackCount
        self.consecutivePlayCount = consecutivePlayCount
        self.repeatPlaybackCount = repeatPlaybackCount
        self.boredomCount = boredomCount
        self.boredomHiddenUntil = boredomHiddenUntil
        self.isPermanentlyHiddenFromShuffle = isPermanentlyHiddenFromShuffle
    }

    private enum CodingKeys: String, CodingKey {
        case trackID, isFavorite, playCount, lastPlayedAt, playbackPreference, playbackEvents
        case totalPlaybackDuration, skipCount, fullPlaybackCount, consecutivePlayCount, repeatPlaybackCount
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
        totalPlaybackDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .totalPlaybackDuration) ?? 0
        skipCount = try container.decodeIfPresent(Int.self, forKey: .skipCount) ?? 0
        fullPlaybackCount = try container.decodeIfPresent(Int.self, forKey: .fullPlaybackCount) ?? 0
        consecutivePlayCount = try container.decodeIfPresent(Int.self, forKey: .consecutivePlayCount) ?? 0
        repeatPlaybackCount = try container.decodeIfPresent(Int.self, forKey: .repeatPlaybackCount) ?? 0
        boredomCount = try container.decodeIfPresent(Int.self, forKey: .boredomCount) ?? 0
        boredomHiddenUntil = try container.decodeIfPresent(Date.self, forKey: .boredomHiddenUntil)
        isPermanentlyHiddenFromShuffle = try container.decodeIfPresent(Bool.self, forKey: .isPermanentlyHiddenFromShuffle) ?? false
    }
}
