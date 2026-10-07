import XCTest
@testable import MyMusic

final class PlaybackDurationSummaryTests: XCTestCase {
    func testCalendarPeriodsUseLocalStartDateAndExclusiveEnd() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        calendar.firstWeekday = 2
        func date(_ day: Int, month: Int = 10) -> Date {
            calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: 23))!
        }
        func event(_ day: Int, seconds: Double, month: Int = 10) -> PlaybackEvent {
            PlaybackEvent(
                trackID: UUID(), startedAt: date(day, month: month),
                endedAt: date(day, month: month).addingTimeInterval(7200),
                listenedSeconds: seconds, completionRatio: 0,
                wasSkipped: false, wasFullPlayback: false,
                startKind: .manual, startSource: .library
            )
        }
        let summary = PlaybackDurationSummary(events: [
            event(1, seconds: 60), event(1, seconds: 30),
            event(4, seconds: 120), event(5, seconds: 240),
            event(30, seconds: 300, month: 9)
        ], calendar: calendar)
        XCTAssertEqual(summary.seconds(for: date(1), component: .day), 90)
        XCTAssertEqual(summary.seconds(for: date(1), component: .month), 450)
        XCTAssertEqual(summary.seconds(for: date(4), component: .weekOfYear), 510)
        XCTAssertEqual(summary.seconds(for: date(6), component: .day), 0)
    }

    func testDurationFormatting() {
        XCTAssertEqual(PlaybackDurationSummary.formatted(0), "0分")
        XCTAssertEqual(PlaybackDurationSummary.formatted(30), "1分未満")
        XCTAssertEqual(PlaybackDurationSummary.formatted(3660), "1時間1分")
        XCTAssertEqual(PlaybackDurationSummary.formatted(.infinity), "0分")
    }
}
