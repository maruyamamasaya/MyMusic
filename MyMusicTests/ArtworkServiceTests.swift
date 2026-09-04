import XCTest
@testable import MyMusic

final class ArtworkServiceTests: XCTestCase {
    func testCorruptArtworkFailureIsCachedUntilArtworkIsStoredAgain() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let identifier = "artwork"
        let fileURL = directory.appending(path: identifier)
        try Data("not an image".utf8).write(to: fileURL)
        let service = ArtworkService(directoryURL: directory)

        let firstAttempt = await service.artworkImage(for: identifier)
        XCTAssertNil(firstAttempt)

        let validPNG = try XCTUnwrap(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
        ))
        try validPNG.write(to: fileURL, options: .atomic)
        let cachedFailureAttempt = await service.artworkImage(for: identifier)
        XCTAssertNil(cachedFailureAttempt)

        _ = try await service.storeArtwork(validPNG, identifier: identifier)
        let recoveredImage = await service.artworkImage(for: identifier)
        XCTAssertNotNil(recoveredImage)
    }
}
