import Foundation
import XCTest
@testable import MyMusic

final class LibraryYearTests: XCTestCase {
    func testTagYearsDescendAndUnknownComesLastWithoutLosingTracks() {
        let tracks = [1998, 2026, 1998, nil, 0, -1, 10000].map { year in
            Track(id: UUID(), title: "曲", artistName: "Artist", duration: 60,
                  fileURL: URL(fileURLWithPath: "/test.mp3"), year: year)
        }
        let groups = LibraryYearService.groups(tracks: tracks)
        XCTAssertEqual(groups.map(\.year), [2026, 1998, nil])
        XCTAssertEqual(groups.map { $0.trackIDs.count }, [1, 2, 4])
        XCTAssertEqual(groups[1].trackIDs, [tracks[0].id, tracks[2].id])
        XCTAssertEqual(Set(groups.flatMap(\.trackIDs)), Set(tracks.map(\.id)))
    }

    func testEmptyAndFilteredInputsDoNotLeaveOldGroups() {
        XCTAssertTrue(LibraryYearService.groups(tracks: []).isEmpty)
        let track = Track(id: UUID(), title: "曲", artistName: "Artist", duration: 60,
                          fileURL: URL(fileURLWithPath: "/test.mp3"), year: 2000)
        XCTAssertEqual(LibraryYearService.groups(tracks: [track]).map(\.year), [2000])
    }
}
