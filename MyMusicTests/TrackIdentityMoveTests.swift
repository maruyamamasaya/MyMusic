import Foundation
import XCTest
@testable import MyMusic

final class TrackIdentityMoveTests: XCTestCase {
    func testRenameKeepsExistingTrackIDUsingResourceIdentifier() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TrackIdentityMoveTests-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let registryURL = directory.appending(path: "identities.json")
        let originalURL = directory.appending(path: "original.m4a")
        let renamedURL = directory.appending(path: "renamed.m4a")
        try Data("same audio bytes".utf8).write(to: originalURL)

        let subject = TrackIdentityService(registryURL: registryURL)
        let originalPath = directory.path + "/original.m4a"
        await subject.prepareForScan(relativePaths: [originalPath])
        let originalID = await subject.resolveID(
            for: originalURL,
            relativePath: originalPath,
            fileSize: 16,
            modificationDate: nil,
            duration: 180
        )
        await subject.finishScan()

        try FileManager.default.moveItem(at: originalURL, to: renamedURL)
        let renamedPath = directory.path + "/renamed.m4a"
        await subject.prepareForScan(relativePaths: [renamedPath])
        let renamedID = await subject.resolveID(
            for: renamedURL,
            relativePath: renamedPath,
            fileSize: 16,
            modificationDate: nil,
            duration: 180
        )
        await subject.finishScan()

        XCTAssertEqual(renamedID, originalID)
    }
}
