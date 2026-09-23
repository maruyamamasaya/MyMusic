import Foundation

nonisolated struct HiResLibraryCatalog: Sendable {
    let tracks: [Track]
    let albums: [Album]
    let artists: [Artist]
    private let tracksByID: [Track.ID: Track]

    init(tracks: [Track], albums: [Album], artists: [Artist]) {
        self.tracks = tracks
        self.albums = albums
        self.artists = artists
        self.tracksByID = Dictionary(
            tracks.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    static let empty = HiResLibraryCatalog(tracks: [], albums: [], artists: [])

    func tracks(for trackIDs: [Track.ID]) -> [Track] {
        return trackIDs.compactMap { tracksByID[$0] }
    }
}
