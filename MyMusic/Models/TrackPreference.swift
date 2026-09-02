import Foundation

nonisolated struct TrackPreference: Codable, Hashable, Sendable {
    let trackID: Track.ID
    var playbackPreference: Int
    var favorite: Bool
}

nonisolated struct TrackPreferencesDocument: Codable, Sendable {
    let schemaVersion: Int
    let tracks: [TrackPreference]
}

nonisolated struct TrackPreferenceImportResult: Equatable, Sendable {
    let total: Int
    let updated: Int
    let unchanged: Int
    let missingTrack: Int
    let invalid: Int
}
