import Foundation

enum WorkLibraryCatalogService {
    static func build(from tracks: [Track]) -> WorkLibraryCatalog {
        build(from: MusicLibrary.build(from: tracks))
    }

    static func build(from library: MusicLibrary) -> WorkLibraryCatalog {
        let tracks = library.tracks
        let workTracks = tracks.filter(\.isEligibleForWorkPlayback)
        guard !workTracks.isEmpty else { return .empty }

        let workTrackIDs = Set(workTracks.map(\.id))
        let workAlbums = library.albums.compactMap { album -> Album? in
            var album = album
            album.trackIDs = album.trackIDs.filter(workTrackIDs.contains)
            return album.trackIDs.isEmpty ? nil : album
        }
        let workAlbumIDs = Set(workAlbums.map(\.id))
        let workArtists = library.artists.compactMap { artist -> Artist? in
            var artist = artist
            artist.trackIDs = artist.trackIDs.filter(workTrackIDs.contains)
            artist.albumIDs = artist.albumIDs.filter(workAlbumIDs.contains)
            return artist.trackIDs.isEmpty ? nil : artist
        }
        let albumArtists = Dictionary(grouping: workTracks, by: albumArtistName(for:))
            .map { name, tracks in
                WorkAlbumArtist(name: name, trackIDs: tracks.map(\.id))
            }
            .sorted { lhs, rhs in
                lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }

        return WorkLibraryCatalog(
            tracks: workTracks,
            albums: workAlbums,
            artists: workArtists,
            albumArtists: albumArtists
        )
    }

    nonisolated private static func albumArtistName(for track: Track) -> String {
        let albumArtistName = track.albumArtistName?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return albumArtistName.flatMap { $0.isEmpty ? nil : $0 } ?? track.artistName
    }
}
