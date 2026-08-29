import XCTest
@testable import MyMusic

final class HomeCategoryTests: XCTestCase {
    func testActivityContainsAnalyticsAndMusicHistoryTiles() throws {
        let activity = try XCTUnwrap(HomeCategory.all.first { $0.id == .activity })

        XCTAssertEqual(activity.items.map(\.destination), [.analytics, .musicHistory])
        XCTAssertEqual(activity.items.map(\.title), ["再生分析", "音楽史"])
    }
}
