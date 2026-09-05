import Foundation
import XCTest
@testable import MyMusic

final class TrackFirstSeenAtTests: XCTestCase {
    @MainActor
    func testRecentlyAddedUsesInclusiveTwoWeekWindowAndExcludesUnknownFutureAndWorkTracks() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let store = PlaybackHistoryStore()
        let recent = makeTrack(name: "recent", firstSeenAt: now.addingTimeInterval(-60))
        let boundary = makeTrack(
            name: "boundary", firstSeenAt: now.addingTimeInterval(-PlaybackHistoryStore.recentlyAddedInterval)
        )
        let old = makeTrack(name: "old", firstSeenAt: now.addingTimeInterval(-PlaybackHistoryStore.recentlyAddedInterval - 1))
        let unknown = makeTrack(name: "unknown", firstSeenAt: nil)
        let future = makeTrack(name: "future", firstSeenAt: now.addingTimeInterval(1))
        var work = makeTrack(name: "work", firstSeenAt: now)
        work.duration = Track.longFormMinimumDuration

        let result = store.recentlyAddedTracks(
            from: [recent, boundary, old, unknown, future, work], now: now
        )

        XCTAssertEqual(Set(result.map(\.id)), Set([recent.id, boundary.id]))
    }

    func testLegacyTrackJSONDecodesUnknownFirstSeenAtAsNil() throws {
        let id = UUID()
        let data = Data("""
        {"id":"\(id.uuidString)","title":"Legacy","artistName":"Artist","duration":180,
         "fileURL":"file:///tmp/legacy.m4a"}
        """.utf8)

        let track = try JSONDecoder().decode(Track.self, from: data)

        XCTAssertNil(track.firstSeenAt)
    }

    func testTrackAndMultipleFolderSnapshotsRoundTripFirstSeenAt() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TrackFirstSeenAtTests-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = LibraryPersistenceService(fileURL: directory.appending(path: "library-index.json"))
        let firstDate = Date(timeIntervalSince1970: 1_800_000_000)
        let secondDate = firstDate.addingTimeInterval(60)
        let firstFolder = directory.appending(path: "one", directoryHint: .isDirectory)
        let secondFolder = directory.appending(path: "two", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: firstFolder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: secondFolder, withIntermediateDirectories: true)
        let first = makeTrack(folder: firstFolder, name: "first", firstSeenAt: firstDate)
        let second = makeTrack(folder: secondFolder, name: "second", firstSeenAt: secondDate)

        try await persistence.save(.build(from: [first]), for: firstFolder)
        try await persistence.save(.build(from: [second]), for: secondFolder)

        let restoredFirst = try await persistence.load(for: firstFolder)
        let restoredSecond = try await persistence.load(for: secondFolder)
        XCTAssertEqual(restoredFirst?.tracks.first?.firstSeenAt, firstDate)
        XCTAssertEqual(restoredSecond?.tracks.first?.firstSeenAt, secondDate)
    }

    func testScanUsesOneTimestampAndPreservesItAcrossMetadataChange() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "TrackFirstSeenAtScan-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = [directory.appending(path: "a.m4a"), directory.appending(path: "b.m4a")]
        for file in files { try Data("audio".utf8).write(to: file) }
        let timestamp = Date(timeIntervalSince1970: 1_800_000_000)
        let metadata = FirstSeenMetadataStub()
        let service = MusicLibraryService(
            fileImportService: FirstSeenFileImportStub(files: files),
            metadataService: metadata,
            identityService: FirstSeenIdentityStub(),
            now: { timestamp }
        )

        let initial = try await service.loadLibrary(from: directory, previousTracks: [])
        XCTAssertEqual(initial.tracks.map(\.firstSeenAt), [timestamp, timestamp])

        var previous = initial.tracks
        previous[0].title = "Old metadata"
        let rescanned = try await service.loadLibrary(from: directory, previousTracks: previous)
        XCTAssertEqual(rescanned.tracks.map(\.firstSeenAt), [timestamp, timestamp])
    }

    private func makeTrack(folder: URL, name: String, firstSeenAt: Date) -> Track {
        Track(id: UUID(), title: name, artistName: "Artist", duration: 180,
              fileURL: folder.appending(path: "\(name).m4a"), relativePath: "\(name).m4a",
              firstSeenAt: firstSeenAt)
    }

    private func makeTrack(name: String, firstSeenAt: Date?) -> Track {
        Track(id: UUID(), title: name, artistName: "Artist", duration: 180,
              fileURL: URL(fileURLWithPath: "/tmp/\(name).m4a"),
              relativePath: "\(name).m4a", firstSeenAt: firstSeenAt)
    }
}

private struct FirstSeenFileImportStub: FileImportServicing {
    let files: [URL]
    func saveLibraryFolders(_ urls: [URL]) throws {}
    func restoreLibraryFolders() throws -> [URL] { [] }
    func audioFiles(in folderURL: URL) async throws -> [URL] { files }
}

private actor FirstSeenMetadataStub: MetadataServicing {
    func metadata(for fileURL: URL, relativeTo libraryFolder: URL, discoveredAt: Date) async throws -> Track {
        Track(id: StableTrackIdentifier.id(for: fileURL.lastPathComponent), title: fileURL.lastPathComponent,
              artistName: "Artist", duration: 180, fileURL: fileURL,
              relativePath: fileURL.lastPathComponent, fileSize: 999,
              modificationDate: .distantPast, firstSeenAt: discoveredAt,
              metadataRevision: MetadataService.currentMetadataRevision)
    }
}

private actor FirstSeenIdentityStub: TrackIdentityServicing {
    func prepareForScan(relativePaths: Set<String>) async {}
    func finishScan() async {}
    func resolveID(for fileURL: URL, relativePath: String, fileSize: Int64?, modificationDate: Date?, duration: TimeInterval) async -> Track.ID {
        StableTrackIdentifier.id(for: relativePath)
    }
    func registerExistingTracks(_ tracks: [Track], in folderURL: URL) async {}
    func fingerprints(for trackIDs: [Track.ID]) async -> [Track.ID: String] { [:] }
    func buildFingerprint(for track: Track, in folderURL: URL, allowDownloading: Bool) async -> TrackFingerprintBuildResult { .unavailable }
}
