import XCTest
@testable import MyMusic

final class HomeCategoryTests: XCTestCase {
    func testActivityContainsAnalyticsAndMusicHistoryTiles() throws {
        let activity = try XCTUnwrap(HomeCategory.all.first { $0.id == .activity })

        XCTAssertEqual(activity.items.map(\.destination), [.analytics, .musicHistory])
        XCTAssertEqual(activity.items.map(\.title), ["再生分析", "音楽史"])
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
            ["activity-analytics", "activity-music-history"]
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

    func testWorkSectionUsesTwelfthTileForContinuation() {
        XCTAssertEqual(HomeWorkTileLayout.maximumTileCount, 12)
        XCTAssertEqual(HomeWorkTileLayout.maximumPlaylistCount, 10)
        XCTAssertFalse(HomeWorkTileLayout.showsContinuationTile(for: 10))
        XCTAssertTrue(HomeWorkTileLayout.showsContinuationTile(for: 11))
    }
}
