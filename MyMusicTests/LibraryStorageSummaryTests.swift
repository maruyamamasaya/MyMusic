import XCTest
@testable import MyMusic

final class LibraryStorageSummaryTests: XCTestCase {
    func testEmptyLibrary() {
        XCTAssertEqual(LibraryStorageSummary.empty.trackCount, 0)
        XCTAssertEqual(LibraryStorageSummary.empty.totalBytes, 0)
        XCTAssertEqual(LibraryStorageSummary.empty.unknownSizeCount, 0)
    }

    func testSumsBytesIncludingZeroAndCountsUnknownSizes() {
        let summary = LibraryStorageSummary(fileSizes: [1_000_000_000, 250_000_000, 0, nil, -1])
        XCTAssertEqual(summary.trackCount, 5)
        XCTAssertEqual(summary.totalBytes, 1_250_000_000)
        XCTAssertEqual(summary.unknownSizeCount, 2)
    }

    func testOverflowDoesNotCrashOrWrapCapacity() {
        let summary = LibraryStorageSummary(fileSizes: [Int64.max, 1])
        XCTAssertEqual(summary.totalBytes, Int64.max)
        XCTAssertEqual(summary.unknownSizeCount, 1)
    }
}
