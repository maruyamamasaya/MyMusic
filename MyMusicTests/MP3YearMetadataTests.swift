import AVFoundation
import XCTest
@testable import MyMusic

final class MP3YearMetadataTests: XCTestCase {
    func testEditorYearFieldsAndPriority() async throws {
        let year = try await MetadataService.mp3Year(in: [
            item(.id3MetadataOriginalReleaseTime, "1980"),
            item(.id3MetadataRecordingTime, "2002-05-01"),
            item(.id3MetadataYear, " 2001 ")
        ])
        XCTAssertEqual(year, 2001)
        let modern = try await MetadataService.mp3Year(in: [item(.id3MetadataRecordingTime, "2002-05-01")])
        XCTAssertEqual(modern, 2002)
        let original = try await MetadataService.mp3Year(in: [item(.id3MetadataOriginalReleaseTime, "1980")])
        XCTAssertNil(original)
        let fallback = try await MetadataService.mp3Year(in: [item(.id3MetadataYear, "bad"), item(.id3MetadataRecordingTime, "2002")])
        XCTAssertEqual(fallback, 2002)
    }

    func testRejectsNonYearsAndAcceptsTrimmedDates() {
        for value in ["", "0", "0000", "abc2001", "20010", "2001/2002"] {
            XCTAssertNil(MetadataService.parseTagYear(value))
        }
        XCTAssertEqual(MetadataService.parseTagYear(" 2001-02-03 "), 2001)
    }

    private func item(_ identifier: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as NSString
        return item
    }
}
