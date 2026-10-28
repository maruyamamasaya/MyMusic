import Foundation
import XCTest
@testable import MyMusic

final class RediscoveryWindowTests: XCTestCase {
    func testRollingDayAndWeekHaveDifferentCandidates() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let twoDaysAgo = now.addingTimeInterval(-48 * 60 * 60)
        XCTAssertTrue(PlaybackHistoryStore.isEligibleForRediscovery(lastPlayedAt: twoDaysAgo, now: now))
        XCTAssertFalse(PlaybackHistoryStore.isEligibleForRediscovery(
            lastPlayedAt: twoDaysAgo, now: now, exclusionInterval: 168 * 60 * 60))
    }

    func testBoundaryIsExcludedAndOlderOrUnplayedAreIncluded() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        for interval: TimeInterval in [24 * 60 * 60, 168 * 60 * 60] {
            XCTAssertFalse(PlaybackHistoryStore.isEligibleForRediscovery(
                lastPlayedAt: now.addingTimeInterval(-interval), now: now, exclusionInterval: interval))
            XCTAssertTrue(PlaybackHistoryStore.isEligibleForRediscovery(
                lastPlayedAt: now.addingTimeInterval(-interval - 1), now: now, exclusionInterval: interval))
            XCTAssertTrue(PlaybackHistoryStore.isEligibleForRediscovery(
                lastPlayedAt: nil, now: now, exclusionInterval: interval))
        }
    }
}
