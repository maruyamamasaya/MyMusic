import Foundation

nonisolated enum StationMood: String, CaseIterable, Identifiable, Sendable {
    case relax, uplift, focus, immerse, stimulate, surprise
    var id: Self { self }
}

nonisolated enum StationSound: String, CaseIterable, Identifiable, Sendable {
    case any, vocals, instrumental, electronic, ambient, piano
    var id: Self { self }
}

nonisolated enum MoodMixKind: String, CaseIterable, Identifiable, Sendable {
    case calm, energy, ambient, electronic

    var id: Self { self }
    var title: String { rawValue.capitalized }
    var featureKey: String { rawValue }
    var systemImage: String {
        switch self {
        case .calm: "wind"
        case .energy: "bolt.fill"
        case .ambient: "sparkles"
        case .electronic: "waveform"
        }
    }
    var subtitle: String {
        switch self {
        case .calm: "穏やかな曲"
        case .energy: "勢いのある曲"
        case .ambient: "広がりのある音"
        case .electronic: "電子的な音"
        }
    }
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
