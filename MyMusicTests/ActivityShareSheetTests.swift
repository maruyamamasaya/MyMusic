import UIKit
import XCTest
@testable import MyMusic

@MainActor
final class ActivityShareSheetTests: XCTestCase {
    func testPopoverAlwaysHasSourceViewAndRect() throws {
        let controller = UIActivityViewController(activityItems: ["test"], applicationActivities: nil)

        ActivityPopoverConfiguration.apply(to: controller)

        let popover = try XCTUnwrap(controller.popoverPresentationController)
        XCTAssertNotNil(popover.sourceView)
        XCTAssertFalse(popover.sourceRect.isNull)
        XCTAssertGreaterThan(popover.sourceRect.width, 0)
        XCTAssertGreaterThan(popover.sourceRect.height, 0)
    }

    func testShareItemCreatesNamedFileAndCleansTemporaryDirectory() throws {
        let file = MusicExportFile(
            data: Data("payload".utf8),
            filename: "MyMusic-Test.json",
            contentType: .json
        )
        let item = try ActivityShareItem(file: file)
        let directory = item.fileURL.deletingLastPathComponent()

        XCTAssertEqual(item.fileURL.lastPathComponent, "MyMusic-Test.json")
        XCTAssertEqual(try Data(contentsOf: item.fileURL), file.data)

        item.removeTemporaryFile()
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }
}
