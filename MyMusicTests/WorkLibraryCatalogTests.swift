import XCTest
@testable import MyMusic

final class WorkLibraryCatalogTests: XCTestCase {
    func testCatalogContainsOnlyWorkEligibleTracksAndTheirCollections() throws {
        let longTrack = makeTrack(
            title: "Long Focus",
            artist: "Performer A",
            albumArtist: "Focus Collective",
            album: "Long Sessions",
            duration: Track.longFormMinimumDuration
        )
        let genreTrack = makeTrack(
            title: "Short Focus",
            artist: "Performer B",
            albumArtist: nil,
            album: "Focus Cues",
            duration: 180,
            genre: Track.workPlaybackGenre
        )
        let regularTrack = makeTrack(
            title: "Regular Song",
            artist: "Performer C",
            albumArtist: "Regular Collective",
            album: "Regular Album",
            duration: 180,
            genre: "Pop"
        )

        let catalog = WorkLibraryCatalogService.build(
            from: [longTrack, genreTrack, regularTrack]
        )

        XCTAssertEqual(Set(catalog.tracks.map(\.id)), [longTrack.id, genreTrack.id])
        XCTAssertEqual(Set(catalog.albums.map(\.title)), ["Long Sessions", "Focus Cues"])
        XCTAssertEqual(Set(catalog.artists.map(\.name)), ["Performer A", "Performer B"])
        XCTAssertEqual(
            Set(catalog.albumArtists.map(\.name)),
            ["Focus Collective", "Performer B"]
        )
        XCTAssertFalse(catalog.albums.flatMap(\.trackIDs).contains(regularTrack.id))
    }

    func testWorkLibraryCategoriesUseRequestedOrderAndNames() {
        XCTAssertEqual(
            WorkLibraryCategory.allCases.map(\.title),
            ["曲名", "アルバム", "アーティスト", "アルバムアーティスト", "プレイリスト"]
        )
    }

    private func makeTrack(
        title: String,
        artist: String,
        albumArtist: String?,
        album: String,
        duration: TimeInterval,
        genre: String? = nil
    ) -> Track {
        Track(
            id: UUID(),
            title: title,
            artistName: artist,
            albumArtistName: albumArtist,
            albumTitle: album,
            duration: duration,
            fileURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).m4a"),
            genre: genre
        )
    }
}
