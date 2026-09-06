import Foundation

enum WatchPlaybackCommand: String, CaseIterable, Sendable {
    case play
    case pause
    case togglePlayPause
    case next
    case previous
    case toggleFavorite
    case increasePlaybackPreference
    case decreasePlaybackPreference
    case requestArtwork
    case requestState
}

struct WatchPlaybackState: Equatable, Sendable {
    nonisolated static let schemaVersion = 1

    var trackID: UUID?
    var title: String
    var artist: String
    var isPlaying: Bool
    var currentTime: TimeInterval
    var duration: TimeInterval
    var isFavorite: Bool
    var playbackPreference: Int
    var hasArtwork: Bool

    static let empty = WatchPlaybackState(
        trackID: nil,
        title: "",
        artist: "",
        isPlaying: false,
        currentTime: 0,
        duration: 0,
        isFavorite: false,
        playbackPreference: 0,
        hasArtwork: false
    )

    var message: [String: Any] {
        [
            "kind": "playbackState",
            "version": Self.schemaVersion,
            "trackID": trackID?.uuidString ?? "",
            "title": title,
            "artist": artist,
            "isPlaying": isPlaying,
            "currentTime": currentTime.isFinite ? max(currentTime, 0) : 0,
            "duration": duration.isFinite ? max(duration, 0) : 0,
            "isFavorite": isFavorite,
            "playbackPreference": playbackPreference,
            "hasArtwork": hasArtwork
        ]
    }

    init(
        trackID: UUID?,
        title: String,
        artist: String,
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval,
        isFavorite: Bool = false,
        playbackPreference: Int = 0,
        hasArtwork: Bool = false
    ) {
        self.trackID = trackID
        self.title = title
        self.artist = artist
        self.isPlaying = isPlaying
        self.currentTime = currentTime
        self.duration = duration
        self.isFavorite = isFavorite
        self.playbackPreference = min(max(playbackPreference, -10), 10)
        self.hasArtwork = hasArtwork
    }

    init?(message: [String: Any]) {
        guard message["kind"] as? String == "playbackState",
              message["version"] as? Int == Self.schemaVersion,
              let title = message["title"] as? String,
              let artist = message["artist"] as? String,
              let isPlaying = message["isPlaying"] as? Bool,
              let currentTime = message["currentTime"] as? Double,
              let duration = message["duration"] as? Double,
              currentTime.isFinite,
              duration.isFinite else { return nil }

        let trackIDString = message["trackID"] as? String ?? ""
        self.init(
            trackID: UUID(uuidString: trackIDString),
            title: title,
            artist: artist,
            isPlaying: isPlaying,
            currentTime: max(currentTime, 0),
            duration: max(duration, 0),
            isFavorite: message["isFavorite"] as? Bool ?? false,
            playbackPreference: message["playbackPreference"] as? Int ?? 0,
            hasArtwork: message["hasArtwork"] as? Bool ?? false
        )
    }

    static func commandMessage(_ command: WatchPlaybackCommand) -> [String: Any] {
        ["kind": "command", "version": schemaVersion, "command": command.rawValue]
    }

    static func command(from message: [String: Any]) -> WatchPlaybackCommand? {
        guard message["kind"] as? String == "command",
              message["version"] as? Int == schemaVersion,
              let value = message["command"] as? String else { return nil }
        return WatchPlaybackCommand(rawValue: value)
    }
}

enum WatchArtworkFileMetadata {
    nonisolated static func message(trackID: UUID) -> [String: Any] {
        ["kind": "artwork", "version": WatchPlaybackState.schemaVersion, "trackID": trackID.uuidString]
    }

    nonisolated static func trackID(from message: [String: Any]?) -> UUID? {
        guard message?["kind"] as? String == "artwork",
              message?["version"] as? Int == WatchPlaybackState.schemaVersion,
              let value = message?["trackID"] as? String else { return nil }
        return UUID(uuidString: value)
    }
}
