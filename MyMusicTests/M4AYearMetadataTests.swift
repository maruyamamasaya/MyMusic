import AVFoundation
import XCTest
@testable import MyMusic

final class M4AYearMetadataTests: XCTestCase {
    func testReadsITunesYearAndDateWithoutUsingOtherDates() async throws {
        let year = try await MetadataService.m4aYear(in: [item(.iTunesMetadataReleaseDate, "2021")])
        XCTAssertEqual(year, 2021)
        let date = try await MetadataService.m4aYear(in: [item(.iTunesMetadataReleaseDate, " 2021-06-27 ")])
        XCTAssertEqual(date, 2021)
        let fallback = try await MetadataService.m4aYear(in: [
            item(.iTunesMetadataReleaseDate, "invalid"), item(.iTunesMetadataReleaseDate, "2021")
        ])
        XCTAssertEqual(fallback, 2021)
        let unrelated = try await MetadataService.m4aYear(in: [
            item(.commonIdentifierCreationDate, "2026"), item(.iTunesMetadataDiscNumber, "2021年06月27日")
        ])
        XCTAssertNil(unrelated)
    }

    // Short synthetic silent AAC/M4A with an iTunes ©day atom containing 2021.
    @MainActor
    func testReadsYearFromRealM4AContainer() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "Year-\(UUID()).m4a")
        defer { try? FileManager.default.removeItem(at: url) }
        let data = try XCTUnwrap(Data(base64Encoded: "AAAAHGZ0eXBNNEEgAAACAE00QSBpc29taXNvMgAAAyJtb292AAAAbG12aGQAAAAAAAAAAAAAAAAAAKxEAAAFKwABAAABAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACAAACMXRyYWsAAABcdGtoZAAAAAMAAAAAAAAAAAAAAAEAAAAAAAAFKwAAAAAAAAAAAAAAAQEAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAACRlZHRzAAAAHGVsc3QAAAAAAAAAAQAABSsAAAQAAAEAAAAAAaltZGlhAAAAIG1kaGQAAAAAAAAAAAAAAAAAAKxEAAAJK1XEAAAAAAAtaGRscgAAAAAAAAAAc291bgAAAAAAAAAAAAAAAFNvdW5kSGFuZGxlcgAAAAFUbWluZgAAABBzbWhkAAAAAAAAAAAAAAAkZGluZgAAABxkcmVmAAAAAAAAAAEAAAAMdXJsIAAAAAEAAAEYc3RibAAAAGpzdHNkAAAAAAAAAAEAAABabXA0YQAAAAAAAAABAAAAAAAAAAAAAQAQAAAAAKxEAAAAAAA2ZXNkcwAAAAADgICAJQABAASAgIAXQBUAAAAAAQ2IAAAP2gWAgIAFEghW5QAGgICAAQIAAAAgc3R0cwAAAAAAAAACAAAAAgAABAAAAAABAAABKwAAABxzdHNjAAAAAAAAAAEAAAABAAAAAwAAAAEAAAAgc3RzegAAAAAAAAAAAAAAAwAAABMAAAAEAAAABAAAABRzdGNvAAAAAAAAAAEAAANOAAAAGnNncGQBAAAAcm9sbAAAAAIAAAAB//8AAAAcc2JncAAAAAByb2xsAAAAAQAAAAMAAAABAAAAfXVkdGEAAAB1bWV0YQAAAAAAAAAhaGRscgAAAAAAAAAAbWRpcmFwcGwAAAAAAAAAAAAAAABIaWxzdAAAABypZGF5AAAAFGRhdGEAAAABAAAAADIwMjEAAAAkqXRvbwAAABxkYXRhAAAAAQAAAABMYXZmNjMuMS4xMDIAAAAIZnJlZQAAACNtZGF03ABMYXZjNjMuMS4xMDIAAjBADgEYIAcBGCAH"))
        try data.write(to: url)
        let year = try await MetadataService().m4aYear(for: url)
        XCTAssertEqual(year, 2021)
        XCTAssertEqual(try Data(contentsOf: url), data)
    }

    func testLegacyTrackDecodesWithoutM4AYearRevision() throws {
        let data = Data("""
        {"id":"\(UUID())","title":"Legacy","artistName":"Artist","duration":180,
         "fileURL":"file:///tmp/song.m4a"}
        """.utf8)
        var track = try JSONDecoder().decode(Track.self, from: data)
        XCTAssertNil(track.m4aYearRevision)
        track.m4aYearRevision = 1
        let restored = try JSONDecoder().decode(Track.self, from: JSONEncoder().encode(track))
        XCTAssertEqual(restored, track)
    }

    private func item(_ identifier: AVMetadataIdentifier, _ value: String) -> AVMetadataItem {
        let item = AVMutableMetadataItem()
        item.identifier = identifier
        item.value = value as NSString
        return item
    }
}
