import ImageIO
import UIKit
import XCTest
@testable import MyMusic

final class WatchArtworkPreparationServiceTests: XCTestCase {
    func testPreparedArtworkIsBoundedJPEG() async throws {
        let png = try XCTUnwrap(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        ))
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = WatchArtworkPreparationService(
            artworkService: WatchArtworkSourceStub(data: png),
            directoryURL: directory
        )

        let preparedFileURL = await service.prepareArtworkFile(identifier: "art", trackID: UUID())
        let fileURL = try XCTUnwrap(preparedFileURL)
        let data = try Data(contentsOf: fileURL)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertLessThanOrEqual(image.width, 512)
        XCTAssertLessThanOrEqual(image.height, 512)
        XCTAssertEqual(image.width, 1, "Images smaller than the Watch limit must not be enlarged")
        XCTAssertEqual(image.height, 1, "Images smaller than the Watch limit must not be enlarged")
        XCTAssertEqual(CGImageSourceGetType(source) as String?, "public.jpeg")
    }

    func testLargeArtworkIsDownsampledTo512PixelsWithAspectRatioPreserved() async throws {
        let sourceData = UIGraphicsImageRenderer(size: CGSize(width: 1_024, height: 512)).jpegData(
            withCompressionQuality: 1
        ) { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1_024, height: 512))
        }
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        defer { try? FileManager.default.removeItem(at: directory) }
        let service = WatchArtworkPreparationService(
            artworkService: WatchArtworkSourceStub(data: sourceData),
            directoryURL: directory
        )

        let preparedFileURL = await service.prepareArtworkFile(identifier: "large", trackID: UUID())
        let fileURL = try XCTUnwrap(preparedFileURL)
        let data = try Data(contentsOf: fileURL)
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        XCTAssertEqual(image.width, 512)
        XCTAssertEqual(image.height, 256)
    }
}

private actor WatchArtworkSourceStub: ArtworkServicing {
    let data: Data

    init(data: Data) {
        self.data = data
    }

    func storeArtwork(_ data: Data, identifier: String) async throws -> String { identifier }
    func artworkData(for identifier: String) async -> Data? { data }
}
