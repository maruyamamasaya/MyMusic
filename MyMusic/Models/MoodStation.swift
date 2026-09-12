import Foundation

nonisolated enum StationMood: String, CaseIterable, Identifiable, Sendable {
    case relax, uplift, focus, immerse, stimulate, surprise
    var id: Self { self }
}

nonisolated enum StationSound: String, CaseIterable, Identifiable, Sendable {
    case any, vocals, instrumental, electronic, ambient, piano
    var id: Self { self }
}

nonisolated struct StationAnswers: Equatable, Sendable {
    var mood: StationMood
    var sound: StationSound
}

nonisolated struct MoodStation: Identifiable, Sendable {
    let id: UUID
    let answers: StationAnswers
    let trackIDs: [Track.ID]
    let analyzedTrackCount: Int
    let matchingTrackCount: Int
}

nonisolated struct StationCandidate: Sendable {
    let trackID: Track.ID
    let artist: String
    let values: TrackFeatureValues
    let overplayFactor: Double

    init(trackID: Track.ID, artist: String, values: TrackFeatureValues, overplayFactor: Double = 1) {
        self.trackID = trackID
        self.artist = artist
        self.values = values
        self.overplayFactor = overplayFactor
    }
}
