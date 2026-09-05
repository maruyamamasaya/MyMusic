import XCTest
import ZIPFoundation
@testable import MyMusic

final class AnalyticsArchiveExportTests: XCTestCase {
    func testArchiveContainsEveryAnalyticsJSONAtRoot() async throws {
        let filenames = [
            "MyMusic-Library.json",
            "MyMusic-Playback-Events.json",
            "MyMusic-Playback-Preferences.json",
            "MyMusic-Track-Features.json",
            "MyMusic-Volume-Normalization.json",
            "MyMusic-Playlists.json",
            "MyMusic-Equalizer.json",
            "MyMusic-Genre-Display-Presets.json"
        ]
        let files = filenames.map {
            MusicExportFile(data: Data($0.utf8), filename: $0, contentType: .json)
        }
        let exportedAt = Date(timeIntervalSince1970: 1_800_000_000)

        let result = try await AnalyticsArchiveExportService().archive(
            files: files,
            exportedAt: exportedAt,
            timeZone: TimeZone(secondsFromGMT: 0)!
        )
        let archive = try Archive(data: result.data, accessMode: .read)

        XCTAssertEqual(result.filename, "MyMusic-Analytics-2027-01-15.zip")
        XCTAssertEqual(result.contentType, .zip)
        XCTAssertEqual(Set(archive.map(\.path)), Set(filenames))
    }
}
