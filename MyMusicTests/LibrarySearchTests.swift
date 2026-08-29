import Foundation
import XCTest
@testable import MyMusic

final class AlbumArtistLibraryTests: XCTestCase {
    func testCompilationWithDifferentTrackArtistsBuildsOneAlbum() throws {
        let tracks = [
            makeTrack(title: "One", artist: "Artist A", albumArtist: "Various Artists"),
            makeTrack(title: "Two", artist: "Artist B", albumArtist: "Various Artists"),
            makeTrack(title: "Three", artist: "Artist C", albumArtist: "Various Artists")
        ]

        let library = MusicLibrary.build(from: tracks)
        let album = try XCTUnwrap(library.albums.first)
        XCTAssertEqual(library.albums.count, 1)
        XCTAssertEqual(album.artistName, "Various Artists")
        XCTAssertEqual(Set(album.trackIDs), Set(tracks.map(\.id)))
        XCTAssertEqual(Set(library.artists.map(\.name)), ["Artist A", "Artist B", "Artist C"])
        XCTAssertFalse(library.artists.contains { $0.name == "Various Artists" })
        XCTAssertTrue(library.artists.allSatisfy { $0.albumIDs == [album.id] })
        XCTAssertEqual(album.legacyAlbumIDs, Set(["Artist A", "Artist B", "Artist C"].map {
            StableLibraryIdentifier.albumID(title: "Test Album", artistName: $0)
        }))
    }

    func testAlbumArtistMissingUsesTrackArtist() throws {
        let track = makeTrack(artist: "Artist A", albumArtist: nil)
        let album = try XCTUnwrap(MusicLibrary.build(from: [track]).albums.first)
        XCTAssertEqual(album.artistName, "Artist A")
        XCTAssertEqual(
            album.id,
            StableLibraryIdentifier.albumID(title: "Test Album", artistName: "Artist A")
        )
    }

    func testSameTitleWithDifferentAlbumArtistsBuildsSeparateAlbums() {
        let tracks = [
            makeTrack(artist: "Singer A", albumArtist: "Artist A", album: "Greatest Hits"),
            makeTrack(artist: "Singer B", albumArtist: "Artist B", album: "Greatest Hits")
        ]

        let albums = MusicLibrary.build(from: tracks).albums
        XCTAssertEqual(albums.count, 2)
        XCTAssertEqual(Set(albums.map(\.artistName)), ["Artist A", "Artist B"])
    }

    func testTrackWithoutAlbumArtistDecodesFromLegacyJSON() throws {
        let id = UUID()
        let json = """
        {
          "id": "\(id.uuidString)",
          "title": "Legacy Song",
          "artistName": "Legacy Artist",
          "albumTitle": "Legacy Album",
          "duration": 180,
          "fileURL": "file:///tmp/legacy-song.m4a"
        }
        """

        let track = try JSONDecoder().decode(Track.self, from: Data(json.utf8))
        XCTAssertEqual(track.id, id)
        XCTAssertNil(track.albumArtistName)
        XCTAssertNil(track.metadataRevision)
        XCTAssertEqual(track.albumTitle, "Legacy Album")
    }

    private func makeTrack(
        title: String = "Song",
        artist: String,
        albumArtist: String?,
        album: String = "Test Album"
    ) -> Track {
        Track(
            id: UUID(),
            title: title,
            artistName: artist,
            albumArtistName: albumArtist,
            albumTitle: album,
            duration: 180,
            fileURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).m4a")
        )
    }
}

final class AlbumArtistSearchServiceTests: XCTestCase {
    private let service = TrackSearchService()

    func testArtistKeywordMatchesTrackArtistAndAlbumArtist() {
        let track = makeTrack()
        var filter = TrackSearchFilter()
        filter.keywordField = .artist

        XCTAssertEqual(search([track], query: "Aimer", filter: filter), [track])
        XCTAssertEqual(search([track], query: "Various Artists", filter: filter), [track])
    }

    func testArtistConditionSupportsContainsExactAndNotContainsAcrossBothNames() {
        let track = makeTrack()
        var filter = TrackSearchFilter()
        filter.conditions = [TrackSearchCondition(kind: .artist, textValue: "Various", textMatchMode: .contains)]
        XCTAssertEqual(search([track], filter: filter), [track])

        filter.conditions[0].textValue = "Aimer"
        filter.conditions[0].textMatchMode = .exact
        XCTAssertEqual(search([track], filter: filter), [track])

        filter.conditions[0].textValue = "Various"
        filter.conditions[0].textMatchMode = .notContains
        XCTAssertTrue(search([track], filter: filter).isEmpty)

        filter.conditions[0].textValue = "LiSA"
        XCTAssertEqual(search([track], filter: filter), [track])
    }

    private func search(
        _ tracks: [Track],
        query: String = "",
        filter: TrackSearchFilter
    ) -> [Track] {
        service.search(tracks: tracks, query: query, filter: filter, historyEntries: [:])
    }

    private func makeTrack() -> Track {
        Track(
            id: UUID(),
            title: "Song",
            artistName: "Aimer",
            albumArtistName: "Various Artists",
            albumTitle: "Compilation",
            duration: 180,
            fileURL: URL(fileURLWithPath: "/tmp/search.m4a")
        )
    }
}

@MainActor
final class TrackSearchStoreTests: XCTestCase {
    func testRapidUpdatesOnlyApplyLatestQuery() async throws {
        let first = makeTrack(title: "First")
        let latest = makeTrack(title: "Latest")
        let tracks = [first, latest]
        let library = MusicLibrary.build(from: tracks)
        let store = TrackSearchStore(debounceDuration: .milliseconds(20))

        store.update(
            tracks: tracks,
            albums: library.albums,
            artists: library.artists,
            query: "First",
            filter: TrackSearchFilter(),
            historyEntries: [:]
        )
        store.update(
            tracks: tracks,
            albums: library.albums,
            artists: library.artists,
            query: "Latest",
            filter: TrackSearchFilter(),
            historyEntries: [:]
        )

        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(store.results, [latest])
    }

    private func makeTrack(title: String) -> Track {
        Track(
            id: UUID(),
            title: title,
            artistName: "Artist",
            albumTitle: "Album",
            duration: 180,
            fileURL: URL(fileURLWithPath: "/tmp/\(title).m4a")
        )
    }
}
