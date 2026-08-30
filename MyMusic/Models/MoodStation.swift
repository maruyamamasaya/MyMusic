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

nonisolated struct StationDecade: Hashable, Identifiable, Sendable {
    let startYear: Int

    var id: Int { startYear }

    init?(year: Int) {
        guard (1...9999).contains(year) else { return nil }
        startYear = year - year % 10
    }

    func contains(_ year: Int?) -> Bool {
        guard let year else { return false }
        return year >= startYear && year < startYear + 10
    }
}

nonisolated struct StationAnswers: Equatable, Sendable {
    var mood: StationMood
    var sound: StationSound
    var refinement: StationRefinement? = nil
    var direction: StationDirection? = nil
    var decade: StationDecade? = nil
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
    let year: Int?
    let values: TrackFeatureValues

    init(trackID: Track.ID, artist: String, year: Int? = nil, values: TrackFeatureValues) {
        self.trackID = trackID
        self.artist = artist
        self.year = year
        self.values = values
    }
}
