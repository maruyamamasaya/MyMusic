import Foundation

nonisolated struct TrackPreferenceImportPreview: Identifiable, Sendable {
    let id = UUID()
    let rows: [Row]
    let expectedEntries: [Track.ID: TrackPreference]
    var imported: [TrackPreference] { rows.map(\.incoming) }
    var matchedTrackIDs: Set<Track.ID> { Set(rows.filter(\.isMatched).map(\.id)) }
    var changedCount: Int { rows.filter { $0.isMatched && $0.isChanged }.count }
    var unchangedCount: Int { rows.filter { $0.isMatched && !$0.isChanged }.count }
    var missingCount: Int { rows.filter { !$0.isMatched }.count }

    struct Row: Identifiable, Sendable {
        var id: Track.ID { incoming.trackID }
        let title: String
        let artist: String
        let current: TrackPreference?
        let incoming: TrackPreference
        let isMatched: Bool
        var isChanged: Bool { current != incoming }
    }

    init(imported: [TrackPreference], entries: [Track.ID: TrackPreference], tracks: [Track]) {
        let tracksByID = Dictionary(tracks.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let ids = Set(imported.map(\.trackID))
        expectedEntries = entries.filter { ids.contains($0.key) }
        rows = imported.map { value in
            let track = tracksByID[value.trackID]
            return Row(title: track?.title ?? "Libraryにない曲", artist: track?.artistName ?? "",
                       current: track == nil ? nil : entries[value.trackID] ?? TrackPreference(
                        trackID: value.trackID, playbackPreference: 0, favorite: false),
                       incoming: value, isMatched: track != nil)
        }
    }
}

nonisolated enum TrackPreferenceImportPreviewError: LocalizedError {
    case stateChanged
    var errorDescription: String? {
        "確認後に評価・ハートまたは曲の照合状態が変わりました。キャンセルしてJSONを選び直し、最新の差分を確認してください。"
    }
}
