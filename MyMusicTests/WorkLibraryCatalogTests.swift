import XCTest
@testable import MyMusic

final class WorkLibraryCatalogTests: XCTestCase {
    func testCatalogContainsOnlyWorkEligibleTracksAndTheirCollections() throws {
        let longTrack = makeTrack(
            title: "Long Focus",
            artist: "Performer A",
            albumArtist: "Focus Collective",
            album: "Long Sessions",
            duration: 60 * 60,
            genre: "Ambient"
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

        XCTAssertEqual(Set(catalog.tracks.map(\.id)), [genreTrack.id])
        XCTAssertEqual(Set(catalog.albums.map(\.title)), ["Focus Cues"])
        XCTAssertEqual(Set(catalog.artists.map(\.name)), ["Performer B"])
        XCTAssertEqual(Set(catalog.albumArtists.map(\.name)), ["Performer B"])
        XCTAssertFalse(catalog.albums.flatMap(\.trackIDs).contains(longTrack.id))
        XCTAssertFalse(catalog.albums.flatMap(\.trackIDs).contains(regularTrack.id))
    }

    func testWorkEligibilityRequiresExactGenreEntryAndIgnoresDuration() {
        let longTrack = makeTrack(
            title: "Long Regular",
            artist: "Artist",
            albumArtist: nil,
            album: "Album",
            duration: 60 * 60,
            genre: "Ambient"
        )
        let combinedGenreTrack = makeTrack(
            title: "Tagged Work",
            artist: "Artist",
            albumArtist: nil,
            album: "Album",
            duration: 180,
            genre: "Ambient; 作業用BGM"
        )
        let similarGenreTrack = makeTrack(
            title: "Similar Genre",
            artist: "Artist",
            albumArtist: nil,
            album: "Album",
            duration: 180,
            genre: "作業用BGM向け"
        )

        XCTAssertFalse(longTrack.isEligibleForWorkPlayback)
        XCTAssertTrue(longTrack.isEligibleForRegularPlayback)
        XCTAssertTrue(combinedGenreTrack.isEligibleForWorkPlayback)
        XCTAssertFalse(similarGenreTrack.isEligibleForWorkPlayback)
    }

    func testRegularRandomEligibilityExcludesOnlyTracksBelowThirtySeconds() {
        let veryShort = makeTrack(
            title: "Very Short",
            artist: "Artist",
            albumArtist: nil,
            album: "Album",
            duration: 29.999,
            genre: "Jingle"
        )
        let boundary = makeTrack(
            title: "Thirty Seconds",
            artist: "Artist",
            albumArtist: nil,
            album: "Album",
            duration: Track.regularRandomMinimumDuration,
            genre: "Jingle"
        )
        let workTrack = makeTrack(
            title: "Work",
            artist: "Artist",
            albumArtist: nil,
            album: "Album",
            duration: 180,
            genre: Track.workPlaybackGenre
        )

        XCTAssertTrue(veryShort.isEligibleForRegularPlayback)
        XCTAssertFalse(veryShort.isEligibleForRegularRandomPlayback)
        XCTAssertTrue(boundary.isEligibleForRegularRandomPlayback)
        XCTAssertFalse(workTrack.isEligibleForRegularRandomPlayback)
    }

    @MainActor
    func testRegularRandomEntryPointsExcludeVeryShortTracks() {
        let veryShort = makeTrack(
            title: "Very Short",
            artist: "Artist",
            albumArtist: nil,
            album: "Album",
            duration: 29.999,
            genre: "Jingle"
        )
        let boundary = makeTrack(
            title: "Thirty Seconds",
            artist: "Artist",
            albumArtist: nil,
            album: "Album",
            duration: Track.regularRandomMinimumDuration,
            genre: "Jingle"
        )
        let store = PlaybackHistoryStore()

        XCTAssertEqual(
            Set(store.preferenceWeightedShuffle([veryShort, boundary]).map(\.id)),
            [boundary.id]
        )
        XCTAssertEqual(
            Set(store.discoveryPlayTracks(from: [veryShort, boundary]).map(\.id)),
            [boundary.id]
        )
        XCTAssertEqual(
            Set(store.highlightPlaybackTracks(from: [veryShort, boundary]).map(\.id)),
            [boundary.id]
        )
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
