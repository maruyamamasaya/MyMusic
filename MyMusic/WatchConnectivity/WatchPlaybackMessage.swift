import Foundation

enum WatchPlaybackCommand: String, CaseIterable, Sendable {
    case play
    case pause
    case togglePlayPause
    case next
    case previous
    case requestState
}

struct WatchPlaybackState: Equatable, Sendable {
    static let schemaVersion = 1

    var trackID: UUID?
    var title: String
    var artist: String
    var isPlaying: Bool
    var currentTime: TimeInterval
    var duration: TimeInterval

    static let empty = WatchPlaybackState(
        trackID: nil,
        title: "",
        artist: "",
        isPlaying: false,
        currentTime: 0,
        duration: 0
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
            "duration": duration.isFinite ? max(duration, 0) : 0
        ]
    }

    init(
        trackID: UUID?,
        title: String,
        artist: String,
        isPlaying: Bool,
        currentTime: TimeInterval,
        duration: TimeInterval
    ) {
        self.trackID = trackID
        self.title = title
        self.artist = artist
        self.isPlaying = isPlaying
        self.currentTime = currentTime
        self.duration = duration
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
            duration: max(duration, 0)
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
