import XCTest
@testable import MyMusic

final class HomeRepresentativeTrackPolicyTests: XCTestCase {
    func testEligibleArtworkTracksExcludeVeryShortWorkAndMissingArtwork() {
        let regular = makeTrack(title: "Regular", duration: 180, artworkIdentifier: "regular")
        let longForm = makeTrack(title: "Long", duration: 60 * 60, artworkIdentifier: "long")
        let veryShort = makeTrack(title: "Very Short", duration: 29.999, artworkIdentifier: "short")
        let workGenre = makeTrack(title: "Work", duration: 180, artworkIdentifier: "work", genre: Track.workPlaybackGenre)
        let noArtwork = makeTrack(title: "No Artwork", duration: 180, artworkIdentifier: nil)

        XCTAssertEqual(
            HomeRepresentativeTrackPolicy.eligibleArtworkTracks(
                from: [regular, longForm, veryShort, workGenre, noArtwork]
            ).map(\.id),
            [regular.id, longForm.id]
        )
    }

    func testSelectionAvoidsImmediatelyPreviousTrackWhenAlternativeExists() {
        let first = makeTrack(title: "First", artworkIdentifier: "first")
        let second = makeTrack(title: "Second", artworkIdentifier: "second")

        XCTAssertEqual(
            HomeRepresentativeTrackPolicy.select(from: [first, second], excluding: first.id)?.id,
            second.id
        )
        XCTAssertEqual(
            HomeRepresentativeTrackPolicy.select(from: [first], excluding: first.id)?.id,
            first.id
        )
    }

    func testRepresentativeIsFirstAndRemovedFromFollowingQueue() {
        let first = makeTrack(title: "First")
        let representative = makeTrack(title: "Representative")
        let last = makeTrack(title: "Last")

        let queue = HomeRepresentativeTrackPolicy.placingRepresentativeFirst(
            representative,
            in: [first, representative, last, representative]
        )

        XCTAssertEqual(queue.map(\.id), [representative.id, first.id, last.id])
    }

    func testPerformanceSnapshotBuildsHomeContentOffLoadedSnapshots() async throws {
        let now = Date(timeIntervalSince1970: 1_790_035_200)
        let regular = makeTrack(title: "Regular", artworkIdentifier: "regular")
        let favorite = makeTrack(title: "Favorite", artworkIdentifier: "favorite")
        let hidden = makeTrack(title: "Hidden", artworkIdentifier: "hidden")
        let short = makeTrack(title: "Short", duration: 10, artworkIdentifier: "short")
        let work = makeTrack(
            title: "Work", artworkIdentifier: "work", genre: Track.workPlaybackGenre
        )
        let library = MusicLibrary.build(from: [regular, favorite, hidden, short, work])
        let dayKey = "2026-09-22"
        let histories = [
            regular.id: PlaybackHistory(
                trackID: regular.id,
                isFavorite: false,
                playCount: 3,
                lastPlayedAt: now,
                dailySummaries: [dayKey: PlaybackDailySummary(playCount: 3)]
            ),
            hidden.id: PlaybackHistory(
                trackID: hidden.id,
                isFavorite: false,
                playCount: 0,
                lastPlayedAt: nil,
                isPermanentlyHiddenFromShuffle: true
            )
        ]
        let preferences = [
            favorite.id: TrackPreference(
                trackID: favorite.id,
                playbackPreference: 1,
                favorite: true
            )
        ]
        let previous = HomeDestinationPresentation(
            representativeTrack: regular,
            artworkIdentifier: regular.artworkIdentifier,
            instantPlaybackIsAvailable: true
        )
        let request = HomePerformanceSnapshotRequest(
            tracks: library.tracks,
            albums: library.albums,
            artists: library.artists,
            workTracks: [work],
            hiResTracks: [],
            histories: histories,
            preferences: preferences,
            listenLaterEntries: [],
            favorites: LibraryFavorites(),
            destinations: [.quickPlay, .discoveryPlay, .favorites, .workSizePlay],
            representativeDestinations: [.quickPlay, .discoveryPlay, .favorites],
            previousPresentations: [.quickPlay: previous],
            previousHighlightArtworkIdentifier: "regular",
            rotatesRepresentatives: false,
            includesMixes: true,
            includesTodayPlaybackSummary: true,
            now: now
        )

        let prepared = await HomePerformanceSnapshotWorker.shared.prepare(request)
        let snapshot = try XCTUnwrap(prepared)

        XCTAssertEqual(snapshot.destinationPresentations[.quickPlay]?.representativeTrack?.id, regular.id)
        XCTAssertEqual(snapshot.destinationPresentations[.discoveryPlay]?.representativeTrack?.id, favorite.id)
        XCTAssertEqual(snapshot.destinationPresentations[.favorites]?.representativeTrack?.id, favorite.id)
        XCTAssertNil(snapshot.destinationPresentations[.workSizePlay]?.representativeTrack)
        XCTAssertEqual(snapshot.destinationPresentations[.workSizePlay]?.artworkIdentifier, "work")
        XCTAssertEqual(snapshot.highlightArtworkIdentifier, "regular")
        XCTAssertEqual(snapshot.todayPlaybackSummary?.playCount, 3)

        let mixIDs = Set(try XCTUnwrap(snapshot.mixQueues).values.flatMap { $0.map(\.id) })
        XCTAssertTrue(mixIDs.isSubset(of: Set([regular.id, favorite.id])))
        XCTAssertFalse(mixIDs.contains(hidden.id))
        XCTAssertFalse(mixIDs.contains(short.id))
        XCTAssertFalse(mixIDs.contains(work.id))
    }

    func testRotationSnapshotCanSkipMixAndTodayRecalculation() async throws {
        let track = makeTrack(title: "Track", artworkIdentifier: "artwork")
        let library = MusicLibrary.build(from: [track])
        let request = HomePerformanceSnapshotRequest(
            tracks: library.tracks,
            albums: library.albums,
            artists: library.artists,
            workTracks: [],
            hiResTracks: [],
            histories: [:],
            preferences: [:],
            listenLaterEntries: [],
            favorites: LibraryFavorites(),
            destinations: [.quickPlay],
            representativeDestinations: [.quickPlay],
            previousPresentations: [:],
            previousHighlightArtworkIdentifier: nil,
            rotatesRepresentatives: true,
            includesMixes: false,
            includesTodayPlaybackSummary: false,
            now: Date(timeIntervalSince1970: 1_790_035_200)
        )

        let prepared = await HomePerformanceSnapshotWorker.shared.prepare(request)
        let snapshot = try XCTUnwrap(prepared)

        XCTAssertNil(snapshot.mixQueues)
        XCTAssertNil(snapshot.mixDay)
        XCTAssertNil(snapshot.todayPlaybackSummary)
        XCTAssertEqual(snapshot.destinationPresentations[.quickPlay]?.representativeTrack?.id, track.id)
    }

    private func makeTrack(
        title: String,
        duration: TimeInterval = 180,
        artworkIdentifier: String? = nil,
        genre: String? = nil
    ) -> Track {
        Track(
            id: UUID(),
            title: title,
            artistName: "Artist",
            duration: duration,
            fileURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).m4a"),
            artworkIdentifier: artworkIdentifier,
            genre: genre
        )
    }
}
