import Foundation

nonisolated enum StationMood: String, CaseIterable, Identifiable, Sendable {
    case relax, uplift, focus, immerse, stimulate, surprise
    var id: Self { self }
}

nonisolated enum StationSound: String, CaseIterable, Identifiable, Sendable {
    case soft, light, rhythmic, heavy, bright, dark
    var id: Self { self }
}

nonisolated enum StationRefinement: String, Sendable {
    case vocals, texture, intensity
}

nonisolated enum StationDirection: String, Sendable {
    case first, second
}

nonisolated struct StationAnswers: Equatable, Sendable {
    var mood: StationMood
    var sound: StationSound
    var refinement: StationRefinement?
    var direction: StationDirection?
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
}
