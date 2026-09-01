import Foundation

enum PlaybackStartKind: String, Codable, CaseIterable, Sendable {
    case manual
    /// The user pressed next/previous, but did not directly choose the destination track.
    case userAdvanced = "user_advanced"
    case automatic
}

enum PlaybackStartSource: String, Codable, CaseIterable, Sendable {
    case album
    case artist
    case favorite
    case highlight
    case history
    case home
    case library
    case playlist
    case queue
    case repeatPlayback = "repeat"
    case search
    case shuffle
    case station
    case workLibrary
    case unknown
}

struct PlaybackStartContext: Codable, Hashable, Sendable {
    var kind: PlaybackStartKind
    var source: PlaybackStartSource

    nonisolated static let manualUnknown = PlaybackStartContext(kind: .manual, source: .unknown)
    nonisolated static let automaticUnknown = PlaybackStartContext(kind: .automatic, source: .unknown)
}

struct PlaybackEvent: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let trackID: Track.ID
    let startedAt: Date
    let endedAt: Date
    let listenedSeconds: TimeInterval
    let completionRatio: Double
    let wasSkipped: Bool
    let wasFullPlayback: Bool
    let startKind: PlaybackStartKind
    let startSource: PlaybackStartSource

    var isEarlySkip: Bool { wasSkipped && listenedSeconds <= 30 }

    init(
        id: String = UUID().uuidString,
        trackID: Track.ID,
        startedAt: Date,
        endedAt: Date,
        listenedSeconds: TimeInterval,
        completionRatio: Double,
        wasSkipped: Bool,
        wasFullPlayback: Bool,
        startKind: PlaybackStartKind,
        startSource: PlaybackStartSource
    ) {
        self.id = id
        self.trackID = trackID
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.listenedSeconds = max(0, listenedSeconds)
        self.completionRatio = min(max(completionRatio, 0), 1)
        self.wasSkipped = wasFullPlayback ? false : wasSkipped
        self.wasFullPlayback = wasFullPlayback
        self.startKind = startKind
        self.startSource = startSource
    }
}

struct PlaybackDailySummary: Codable, Hashable, Sendable {
    var playCount: Int
    var manualPlayCount: Int
    var automaticPlayCount: Int
    var fullPlaybackCount: Int
    var skipCount: Int
    var earlySkipCount: Int
    var sourceCounts: [String: Int]

    init(
        playCount: Int = 0,
        manualPlayCount: Int = 0,
        automaticPlayCount: Int = 0,
        fullPlaybackCount: Int = 0,
        skipCount: Int = 0,
        earlySkipCount: Int = 0,
        sourceCounts: [String: Int] = [:]
    ) {
        self.playCount = playCount
        self.manualPlayCount = manualPlayCount
        self.automaticPlayCount = automaticPlayCount
        self.fullPlaybackCount = fullPlaybackCount
        self.skipCount = skipCount
        self.earlySkipCount = earlySkipCount
        self.sourceCounts = sourceCounts
    }

    private enum CodingKeys: String, CodingKey {
        case playCount, manualPlayCount, automaticPlayCount, fullPlaybackCount, skipCount, earlySkipCount, sourceCounts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playCount = try container.decodeIfPresent(Int.self, forKey: .playCount) ?? 0
        manualPlayCount = try container.decodeIfPresent(Int.self, forKey: .manualPlayCount) ?? 0
        automaticPlayCount = try container.decodeIfPresent(Int.self, forKey: .automaticPlayCount) ?? 0
        fullPlaybackCount = try container.decodeIfPresent(Int.self, forKey: .fullPlaybackCount) ?? 0
        skipCount = try container.decodeIfPresent(Int.self, forKey: .skipCount) ?? 0
        earlySkipCount = try container.decodeIfPresent(Int.self, forKey: .earlySkipCount) ?? 0
        sourceCounts = try container.decodeIfPresent([String: Int].self, forKey: .sourceCounts) ?? [:]
    }
}

struct PlaybackHistory: Codable, Hashable, Sendable {
    let trackID: Track.ID
    var isFavorite: Bool
    var playCount: Int
    var firstPlayedAt: Date?
    var lastPlayedAt: Date?
    var playbackPreference: Int
    var playbackEvents: [PlaybackEvent]
    var dailySummaries: [String: PlaybackDailySummary]
    var manualPlayCount: Int
    var automaticPlayCount: Int
    var playbackSourceCounts: [String: Int]
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
        firstPlayedAt: Date? = nil,
        lastPlayedAt: Date?,
        playbackPreference: Int = 0,
        playbackEvents: [PlaybackEvent] = [],
        dailySummaries: [String: PlaybackDailySummary] = [:],
        manualPlayCount: Int = 0,
        automaticPlayCount: Int = 0,
        playbackSourceCounts: [String: Int] = [:],
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
        self.firstPlayedAt = firstPlayedAt
        self.lastPlayedAt = lastPlayedAt
        self.playbackPreference = playbackPreference
        self.playbackEvents = playbackEvents
        self.dailySummaries = dailySummaries
        self.manualPlayCount = manualPlayCount
        self.automaticPlayCount = automaticPlayCount
        self.playbackSourceCounts = playbackSourceCounts
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
        case trackID, isFavorite, playCount, firstPlayedAt, lastPlayedAt, playbackPreference, playbackEvents
        case dailySummaries, manualPlayCount, automaticPlayCount, playbackSourceCounts
        case totalPlaybackDuration, skipCount, fullPlaybackCount, consecutivePlayCount, repeatPlaybackCount
        case boredomCount, boredomHiddenUntil, isPermanentlyHiddenFromShuffle
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let decodedTrackID = try container.decode(Track.ID.self, forKey: .trackID)
        trackID = decodedTrackID
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
        playCount = try container.decode(Int.self, forKey: .playCount)
        let decodedFirstPlayedAt = try container.decodeIfPresent(Date.self, forKey: .firstPlayedAt)
        let decodedLastPlayedAt = try container.decodeIfPresent(Date.self, forKey: .lastPlayedAt)
        lastPlayedAt = decodedLastPlayedAt
        playbackPreference = try container.decodeIfPresent(Int.self, forKey: .playbackPreference) ?? 0
        let decodedPlaybackEvents: [PlaybackEvent]
        if let events = try? container.decode([PlaybackEvent].self, forKey: .playbackEvents) {
            decodedPlaybackEvents = events
        } else {
            let legacyDates = try container.decodeIfPresent([Date].self, forKey: .playbackEvents)
                ?? decodedLastPlayedAt.map { [$0] }
                ?? []
            decodedPlaybackEvents = legacyDates.enumerated().map { offset, date in
                PlaybackEvent(
                    id: "legacy-json-\(decodedTrackID.uuidString)-\(offset)-\(date.timeIntervalSince1970)",
                    trackID: decodedTrackID, startedAt: date, endedAt: date, listenedSeconds: 0,
                    completionRatio: 0, wasSkipped: false, wasFullPlayback: false,
                    startKind: .manual, startSource: .unknown
                )
            }
        }
        playbackEvents = decodedPlaybackEvents
        firstPlayedAt = decodedFirstPlayedAt ?? decodedPlaybackEvents.map(\.startedAt).min() ?? decodedLastPlayedAt
        dailySummaries = try container.decodeIfPresent(
            [String: PlaybackDailySummary].self,
            forKey: .dailySummaries
        ) ?? Self.dailySummaries(from: decodedPlaybackEvents.map(\.startedAt))
        manualPlayCount = try container.decodeIfPresent(Int.self, forKey: .manualPlayCount) ?? 0
        automaticPlayCount = try container.decodeIfPresent(Int.self, forKey: .automaticPlayCount) ?? 0
        playbackSourceCounts = try container.decodeIfPresent([String: Int].self, forKey: .playbackSourceCounts) ?? [:]
        totalPlaybackDuration = try container.decodeIfPresent(TimeInterval.self, forKey: .totalPlaybackDuration) ?? 0
        skipCount = try container.decodeIfPresent(Int.self, forKey: .skipCount) ?? 0
        fullPlaybackCount = try container.decodeIfPresent(Int.self, forKey: .fullPlaybackCount) ?? 0
        consecutivePlayCount = try container.decodeIfPresent(Int.self, forKey: .consecutivePlayCount) ?? 0
        repeatPlaybackCount = try container.decodeIfPresent(Int.self, forKey: .repeatPlaybackCount) ?? 0
        boredomCount = try container.decodeIfPresent(Int.self, forKey: .boredomCount) ?? 0
        boredomHiddenUntil = try container.decodeIfPresent(Date.self, forKey: .boredomHiddenUntil)
        isPermanentlyHiddenFromShuffle = try container.decodeIfPresent(Bool.self, forKey: .isPermanentlyHiddenFromShuffle) ?? false
    }

    private static func dailySummaries(from events: [Date]) -> [String: PlaybackDailySummary] {
        events.reduce(into: [:]) { summaries, date in
            let key = dayKey(for: date)
            var summary = summaries[key] ?? PlaybackDailySummary()
            summary.playCount += 1
            summary.sourceCounts[PlaybackStartSource.unknown.rawValue, default: 0] += 1
            summaries[key] = summary
        }
    }

    private static func dayKey(for date: Date) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }
}
