import XCTest
@testable import MyMusic

final class HomeCategoryTests: XCTestCase {
    func testActivityContainsAnalyticsMusicHistoryAndTrendsTiles() throws {
        let activity = try XCTUnwrap(HomeCategory.all.first { $0.id == .activity })

        XCTAssertEqual(activity.items.map(\.destination), [.weeklyRanking, .artistRanking, .analytics, .musicHistory, .recentMusicTrends])
        XCTAssertEqual(activity.items.map(\.title), ["Weekly", "ランキング", "再生分析", "音楽史", "最近の音楽傾向"])
    }

    func testExploreOwnsDiscoveryAndMyMusicStartsWithManualQueue() throws {
        let explore = try XCTUnwrap(HomeCategory.all.first { $0.id == .explore })
        XCTAssertEqual(explore.items.map(\.destination), [.quickPlay, .rediscoverPlay, .rediscoverWeekPlay, .discoveryPlay, .pianoPlay, .ambientPlay])
        let myMusic = try XCTUnwrap(HomeCategory.all.first { $0.id == .myMusic })
        XCTAssertEqual(myMusic.items.first?.destination, .manualQueue)
        XCTAssertEqual(myMusic.items.first?.title, "次に再生する")
        XCTAssertEqual(myMusic.items.dropFirst().first?.destination, .listenLater)
    }

    func testLibraryAndActivityTilesHaveStableLocalImageNames() throws {
        let library = try XCTUnwrap(HomeCategory.all.first { $0.id == .library })
        let activity = try XCTUnwrap(HomeCategory.all.first { $0.id == .activity })

        XCTAssertEqual(
            library.items.map(\.localBackgroundImageName),
            [
                "library-songs-v2",
                "library-albums-v2",
                "library-artists-v2",
                "library-genres-v2",
                "library-composers-v2",
                "library-years"
            ]
        )
        XCTAssertEqual(
            activity.items.map(\.localBackgroundImageName),
            ["activity-weekly-ranking-v1", "activity-ranking", "activity-analytics-v2", "activity-music-history-v2", "activity-music-trends"]
        )
    }

    func testOtherHomeTilesDoNotRequestLocalBackgroundImages() {
        let destinations = HomeCategory.all
            .filter { $0.id != .library && $0.id != .activity }
            .flatMap(\.items)
            .map(\.destination)

        XCTAssertEqual(HomeDestination.ambientPlay.localBackgroundImageName, "ambient-crystal-lake-v1")
        XCTAssertEqual(HomeDestination.pianoPlay.localBackgroundImageName, "piano-crystal-v1")
        XCTAssertEqual(HomeDestination.manualQueue.localBackgroundImageName, "manual-queue-v1")
        XCTAssertEqual(HomeDestination.workSizePlay.localBackgroundImageName, "work-bgm-background")
        XCTAssertEqual(HomeDestination.hiResLibrary.localBackgroundImageName, "library-hires-v1")
        XCTAssertTrue(destinations.filter { $0 != .workSizePlay && $0 != .hiResLibrary && $0 != .manualQueue && $0 != .pianoPlay && $0 != .ambientPlay }.allSatisfy { $0.localBackgroundImageName == nil })
    }

    func testStationHasStableLocalBackgroundImageName() {
        XCTAssertEqual(HomeTileBackgroundImage.stationImageName, "station-background")
    }

    func testHighlightHasStableLocalBackgroundImageName() {
        XCTAssertEqual(HomeTileBackgroundImage.highlightImageName, "highlight-background")
    }

    func testWorkSectionUsesTwelfthTileForContinuation() {
        XCTAssertEqual(HomeWorkTileLayout.maximumTileCount, 12)
        XCTAssertEqual(HomeWorkTileLayout.maximumPlaylistCount, 10)
        XCTAssertFalse(HomeWorkTileLayout.showsContinuationTile(for: 10))
        XCTAssertTrue(HomeWorkTileLayout.showsContinuationTile(for: 11))
    }

    func testMyMusicHidesTilesWithoutTargetTracks() throws {
        let myMusic = try XCTUnwrap(HomeCategory.all.first { $0.id == .myMusic })
        let availableDestinations: Set<HomeDestination> = [
            .quickPlay,
            .listenLater,
            .favorites
        ]

        let visibleItems = HomeCarouselContentPolicy.visibleItems(in: myMusic) {
            availableDestinations.contains($0)
        }

        XCTAssertEqual(
            visibleItems.map(\.destination),
            [.manualQueue, .listenLater, .favorites]
        )
    }

    func testNonMyMusicTilesRemainVisibleWithoutTrackContent() throws {
        let library = try XCTUnwrap(HomeCategory.all.first { $0.id == .library })

        let visibleItems = HomeCarouselContentPolicy.visibleItems(in: library) { _ in false }

        XCTAssertEqual(visibleItems, library.items)
    }
}
