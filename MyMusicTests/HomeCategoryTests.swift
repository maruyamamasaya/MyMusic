import XCTest
@testable import MyMusic

final class HomeCategoryTests: XCTestCase {
    func testActivityContainsAnalyticsMusicHistoryAndTrendsTiles() throws {
        let activity = try XCTUnwrap(HomeCategory.all.first { $0.id == .activity })

        XCTAssertEqual(activity.items.map(\.destination), [.analytics, .musicHistory, .recentMusicTrends])
        XCTAssertEqual(activity.items.map(\.title), ["再生分析", "音楽史", "最近の音楽傾向"])
    }

    func testListenLaterTileFollowsDiscoveryPlay() throws {
        let myMusic = try XCTUnwrap(HomeCategory.all.first { $0.id == .myMusic })
        let discoveryIndex = try XCTUnwrap(myMusic.items.firstIndex { $0.destination == .discoveryPlay })

        XCTAssertEqual(myMusic.items[discoveryIndex + 1].destination, .listenLater)
        XCTAssertEqual(myMusic.items[discoveryIndex + 1].title, "あとで聴く")
        XCTAssertEqual(myMusic.items[discoveryIndex + 2].destination, .recentlyAddedPlay)
    }

    func testLibraryAndActivityTilesHaveStableLocalImageNames() throws {
        let library = try XCTUnwrap(HomeCategory.all.first { $0.id == .library })
        let activity = try XCTUnwrap(HomeCategory.all.first { $0.id == .activity })

        XCTAssertEqual(
            library.items.map(\.localBackgroundImageName),
            [
                "library-songs",
                "library-albums",
                "library-artists",
                "library-genres",
                "library-composers"
            ]
        )
        XCTAssertEqual(
            activity.items.map(\.localBackgroundImageName),
            ["activity-analytics", "activity-music-history", nil]
        )
    }

    func testOtherHomeTilesDoNotRequestLocalBackgroundImages() {
        let destinations = HomeCategory.all
            .filter { $0.id != .library && $0.id != .activity }
            .flatMap(\.items)
            .map(\.destination)

        XCTAssertTrue(destinations.allSatisfy { $0.localBackgroundImageName == nil })
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
}
