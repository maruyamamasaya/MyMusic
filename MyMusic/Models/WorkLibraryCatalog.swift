import Foundation

nonisolated struct WorkLibraryCatalog: Sendable {
    let tracks: [Track]
    let albums: [Album]
    let artists: [Artist]
    let albumArtists: [WorkAlbumArtist]
    private let tracksByID: [Track.ID: Track]

    init(tracks: [Track], albums: [Album], artists: [Artist], albumArtists: [WorkAlbumArtist]) {
        self.tracks = tracks
        self.albums = albums
        self.artists = artists
        self.albumArtists = albumArtists
        self.tracksByID = Dictionary(
            tracks.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
    }

    static let empty = WorkLibraryCatalog(
        tracks: [],
        albums: [],
        artists: [],
        albumArtists: []
    )

    func tracks(for trackIDs: [Track.ID]) -> [Track] {
        return trackIDs.compactMap { tracksByID[$0] }
    }
}

nonisolated struct WorkAlbumArtist: Identifiable, Hashable, Sendable {
    let name: String
    let trackIDs: [Track.ID]

    var id: String { name }
}
