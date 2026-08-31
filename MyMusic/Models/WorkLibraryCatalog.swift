import Foundation

nonisolated struct WorkLibraryCatalog: Sendable {
    var tracks: [Track]
    var albums: [Album]
    var artists: [Artist]
    var albumArtists: [WorkAlbumArtist]

    static let empty = WorkLibraryCatalog(
        tracks: [],
        albums: [],
        artists: [],
        albumArtists: []
    )

    func tracks(for trackIDs: [Track.ID]) -> [Track] {
        let tracksByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        return trackIDs.compactMap { tracksByID[$0] }
    }
}

nonisolated struct WorkAlbumArtist: Identifiable, Hashable, Sendable {
    let name: String
    let trackIDs: [Track.ID]

    var id: String { name }
}
