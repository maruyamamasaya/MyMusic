import Foundation
import XCTest
@testable import MyMusic

final class TodayPlaybackSummaryServiceTests: XCTestCase {
    func testTodayUsesLocalDayForStartsAndFinishedListeningTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Asia/Tokyo"))
        let today = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 12)))
        let yesterday = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 23)))
        let trackID = UUID()
        let entry = PlaybackHistory(
            trackID: trackID,
            isFavorite: false,
            playCount: 2,
            lastPlayedAt: today,
            playbackEvents: [event(trackID: trackID, at: yesterday, seconds: 500),
                             event(trackID: trackID, at: today, seconds: 3_665)],
            dailySummaries: ["2026-09-20": PlaybackDailySummary(playCount: 1),
                             "2026-09-21": PlaybackDailySummary(playCount: 2)]
        )

        let result = TodayPlaybackSummaryService().summary(from: [trackID: entry], now: today, calendar: calendar)
        XCTAssertEqual(result.playCount, 2)
        XCTAssertEqual(result.listenedSeconds, 3_665)
        XCTAssertEqual(result.compactText, "今日 2回 · 1時間1分")
    }

    private func event(trackID: UUID, at date: Date, seconds: TimeInterval) -> PlaybackEvent {
        PlaybackEvent(trackID: trackID, startedAt: date,
                      endedAt: date.addingTimeInterval(seconds), listenedSeconds: seconds,
                      completionRatio: 1, wasSkipped: false, wasFullPlayback: true,
                      startKind: .manual, startSource: .home)
    }
}
