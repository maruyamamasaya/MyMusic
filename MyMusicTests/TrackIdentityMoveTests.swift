import Foundation
import XCTest
@testable import MyMusic

final class TrackIdentityMoveTests: XCTestCase {
    func testRegisteringCachedTrackDoesNotRequireTheAudioFileToBeReadable() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TrackIdentityCachedRegistration-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let registryURL = directory.appending(path: "identities.json")
        let unavailableFolder = directory.appending(path: "offline", directoryHint: .isDirectory)
        let trackID = UUID()
        let track = Track(
            id: trackID, title: "Cached", artistName: "Artist", duration: 180,
            fileURL: unavailableFolder.appending(path: "song.m4a"), relativePath: "song.m4a",
            fileSize: 1_024, modificationDate: .distantPast, firstSeenAt: .distantPast
        )
        let subject = TrackIdentityService(registryURL: registryURL)

        await subject.registerExistingTracks([track], in: unavailableFolder)

        let resolved = await subject.resolveIdentity(
            for: track.fileURL,
            relativePath: unavailableFolder.standardizedFileURL.path + "/song.m4a",
            fileSize: track.fileSize,
            modificationDate: track.modificationDate,
            duration: track.duration,
            discoveredAt: .now
        )
        XCTAssertEqual(resolved.id, trackID)
        XCTAssertEqual(resolved.firstSeenAt, track.firstSeenAt)
    }

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

    func testMoveAndRegistryReloadKeepFirstSeenAt() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TrackIdentityFirstSeenTests-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let registryURL = directory.appending(path: "identities.json")
        let originalURL = directory.appending(path: "original.m4a")
        let movedURL = directory.appending(path: "moved.m4a")
        try Data("same audio bytes".utf8).write(to: originalURL)
        let firstSeenAt = Date(timeIntervalSince1970: 1_800_000_000)
        let originalPath = directory.path + "/original.m4a"
        let subject = TrackIdentityService(registryURL: registryURL)
        await subject.prepareForScan(relativePaths: [originalPath])
        let original = await subject.resolveIdentity(
            for: originalURL, relativePath: originalPath, fileSize: 16,
            modificationDate: nil, duration: 180, discoveredAt: firstSeenAt
        )
        await subject.finishScan()

        try FileManager.default.moveItem(at: originalURL, to: movedURL)
        let movedPath = directory.path + "/moved.m4a"
        let reloaded = TrackIdentityService(registryURL: registryURL)
        await reloaded.prepareForScan(relativePaths: [movedPath])
        let moved = await reloaded.resolveIdentity(
            for: movedURL, relativePath: movedPath, fileSize: 16,
            modificationDate: nil, duration: 180, discoveredAt: firstSeenAt.addingTimeInterval(500)
        )
        await reloaded.finishScan()

        XCTAssertEqual(moved.id, original.id)
        XCTAssertEqual(moved.firstSeenAt, firstSeenAt)
    }
}
