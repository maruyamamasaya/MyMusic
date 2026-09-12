import Foundation
import XCTest
@testable import MyMusic

final class DailyArtistArtworkSelectionTests: XCTestCase {
    private let artistID = UUID(uuidString: "10000000-0000-0000-0000-000000000001")!
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    func testSelectionIsStableWithinTheSameDay() throws {
        let morning = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: 8)))
        let evening = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 13, hour: 22)))
        let identifiers = ["cover-c", "cover-a", "cover-b"]

        XCTAssertEqual(
            DailyArtistArtworkSelection.identifier(for: artistID, from: identifiers, date: morning, calendar: calendar),
            DailyArtistArtworkSelection.identifier(
                for: artistID,
                from: Array(identifiers.reversed()),
                date: evening,
                calendar: calendar
            )
        )
    }

    func testSelectionRotatesOnTheNextDayWhenMultipleCoversExist() throws {
        let firstDay = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 13)))
        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: firstDay))
        let identifiers = ["cover-a", "cover-b", "cover-c"]

        XCTAssertNotEqual(
            DailyArtistArtworkSelection.identifier(for: artistID, from: identifiers, date: firstDay, calendar: calendar),
            DailyArtistArtworkSelection.identifier(for: artistID, from: identifiers, date: nextDay, calendar: calendar)
        )
    }

    func testMissingArtworkReturnsNil() {
        XCTAssertNil(DailyArtistArtworkSelection.identifier(for: artistID, from: []))
    }
}
