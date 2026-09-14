import XCTest
@testable import MyMusic

final class SongsViewArrangementTests: XCTestCase {
    func testFiltersByFavoriteAndSearchesGenre() {
        let favorite = makeTrack("Favorite", genre: "Rock")
        let other = makeTrack("Other", genre: "Ambient")
        let preferences = [
            favorite.id: TrackPreference(trackID: favorite.id, playbackPreference: 0, favorite: true)
        ]

        let favorites = SongsView.arrange(
            [other, favorite],
            request: request(query: "", filter: .favorites, sort: .title),
            preferences: preferences,
            histories: [:]
        )
        let genreSearch = SongsView.arrange(
            [other, favorite],
            request: request(query: "rock", filter: .all, sort: .title),
            preferences: preferences,
            histories: [:]
        )

        XCTAssertEqual(favorites.map(\.id), [favorite.id])
        XCTAssertEqual(genreSearch.map(\.id), [favorite.id])
    }

    func testFiltersUnplayedAndRecentlyAdded() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var recent = makeTrack("Recent")
        recent.firstSeenAt = now.addingTimeInterval(-60)
        var old = makeTrack("Old")
        old.firstSeenAt = now.addingTimeInterval(-PlaybackHistoryStore.recentlyAddedInterval - 1)
        let histories = [
            old.id: PlaybackHistory(
                trackID: old.id,
                isFavorite: false,
                playCount: 2,
                lastPlayedAt: now
            )
        ]

        let unplayed = SongsView.arrange(
            [old, recent],
            request: request(query: "", filter: .unplayed, sort: .title),
            preferences: [:],
            histories: histories,
            now: now
        )
        let recentlyAdded = SongsView.arrange(
            [old, recent],
            request: request(query: "", filter: .recentlyAdded, sort: .title),
            preferences: [:],
            histories: histories,
            now: now
        )

        XCTAssertEqual(unplayed.map(\.id), [recent.id])
        XCTAssertEqual(recentlyAdded.map(\.id), [recent.id])
    }

    func testSortsByPlayCountAndLastPlayed() {
        let first = makeTrack("First")
        let second = makeTrack("Second")
        let histories = [
            first.id: PlaybackHistory(
                trackID: first.id,
                isFavorite: false,
                playCount: 2,
                lastPlayedAt: Date(timeIntervalSince1970: 200)
            ),
            second.id: PlaybackHistory(
                trackID: second.id,
                isFavorite: false,
                playCount: 5,
                lastPlayedAt: Date(timeIntervalSince1970: 100)
            )
        ]

        let byCount = SongsView.arrange(
            [first, second],
            request: request(query: "", filter: .all, sort: .playCount),
            preferences: [:],
            histories: histories
        )
        let byRecent = SongsView.arrange(
            [first, second],
            request: request(query: "", filter: .all, sort: .lastPlayed),
            preferences: [:],
            histories: histories
        )

        XCTAssertEqual(byCount.map(\.id), [second.id, first.id])
        XCTAssertEqual(byRecent.map(\.id), [first.id, second.id])
    }

    private func request(
        query: String,
        filter: SongListFilter,
        sort: SongSortOrder
    ) -> SongArrangementRequest {
        SongArrangementRequest(
            query: query,
            filter: filter,
            sortOrder: sort,
            randomSeed: 1,
            trackCount: 2,
            preferenceRevision: 0,
            historyRevision: 0
        )
    }

    private func makeTrack(_ title: String, genre: String? = nil) -> Track {
        Track(
            id: UUID(),
            title: title,
            artistName: "Artist",
            duration: 120,
            fileURL: URL(fileURLWithPath: "/tmp/\(title).m4a"),
            genre: genre
        )
    }
}
