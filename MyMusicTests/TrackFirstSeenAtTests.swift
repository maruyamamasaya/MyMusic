import Foundation
import XCTest
@testable import MyMusic

final class TrackFirstSeenAtTests: XCTestCase {
    @MainActor
    func testRecentlyAddedExcludesUnknownFutureWorkAndVeryShortTracks() {
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
        work.genre = Track.workPlaybackGenre
        var longTrack = makeTrack(name: "long", firstSeenAt: now)
        longTrack.duration = 60 * 60
        var veryShort = makeTrack(name: "very-short", firstSeenAt: now)
        veryShort.duration = 29.999
        var thirtySeconds = makeTrack(name: "thirty-seconds", firstSeenAt: now)
        thirtySeconds.duration = Track.regularRandomMinimumDuration

        let result = store.recentlyAddedTracks(
            from: [recent, boundary, old, unknown, future, work, longTrack, veryShort, thirtySeconds], now: now
        )

        XCTAssertEqual(Set(result.map(\.id)), Set([recent.id, boundary.id, longTrack.id, thirtySeconds.id]))
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

    func testScanReportIncludesICloudAndMetadataFailures() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "LibraryScanReport-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let unreadableMetadataFile = directory.appending(path: "metadata-failure.m4a")
        try Data("audio".utf8).write(to: unreadableMetadataFile)

        let service = MusicLibraryService(
            fileImportService: FirstSeenFileImportStub(
                files: [unreadableMetadataFile],
                notices: [.iCloudDownloadPending(relativePath: "pending.m4a")]
            ),
            metadataService: FailingMetadataStub(),
            identityService: FirstSeenIdentityStub()
        )

        let report = try await service.loadLibraryReport(from: directory, previousTracks: [])

        XCTAssertTrue(report.library.tracks.isEmpty)
        XCTAssertEqual(report.notices.count, 2)
        XCTAssertTrue(report.notices.contains(.iCloudDownloadPending(relativePath: "pending.m4a")))
        XCTAssertTrue(report.notices.contains { notice in
            guard case let .metadataReadFailed(path, detail) = notice else { return false }
            return path == "metadata-failure.m4a" && detail.contains("metadata unavailable")
        })
    }

    func testCompleteScanReloadsUnchangedMetadataAndReportsProgress() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "CompleteLibraryScan-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "song.m4a")
        try Data("audio".utf8).write(to: file)
        let values = try file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let trackID = StableTrackIdentifier.id(for: file.lastPathComponent)
        let firstSeenAt = Date(timeIntervalSince1970: 1_700_000_000)
        let previous = Track(
            id: trackID,
            title: "Old title",
            artistName: "Artist",
            duration: 180,
            fileURL: file,
            relativePath: file.lastPathComponent,
            fileSize: values.fileSize.map(Int64.init),
            modificationDate: values.contentModificationDate,
            firstSeenAt: firstSeenAt,
            metadataRevision: MetadataService.currentMetadataRevision
        )
        let progressRecorder = ScanProgressRecorder()
        let service = MusicLibraryService(
            fileImportService: FirstSeenFileImportStub(files: [file]),
            metadataService: FirstSeenMetadataStub(),
            identityService: FirstSeenIdentityStub(),
            checkpointService: LibraryScanCheckpointService(
                directoryURL: directory.appending(path: "checkpoints", directoryHint: .isDirectory)
            )
        )

        let report = try await service.loadLibraryReport(
            from: directory,
            previousTracks: [previous],
            depth: .complete
        ) { progress in
            await progressRecorder.append(progress)
        }

        XCTAssertEqual(report.library.tracks.first?.title, "song.m4a")
        XCTAssertEqual(report.library.tracks.first?.id, trackID)
        XCTAssertEqual(report.library.tracks.first?.firstSeenAt, firstSeenAt)
        let progresses = await progressRecorder.values
        XCTAssertEqual(progresses, [
            LibraryScanProgress(completedCount: 0, totalCount: 1),
            LibraryScanProgress(completedCount: 1, totalCount: 1)
        ])
    }

    func testCompleteScanResumesRecentMatchingCheckpoint() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "ResumeLibraryScan-\(UUID())", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appending(path: "song.m4a")
        try Data("audio".utf8).write(to: file)
        let metadata = CheckpointMetadataStub()
        let checkpoint = LibraryScanCheckpointService(
            directoryURL: directory.appending(path: "checkpoints", directoryHint: .isDirectory)
        )
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let service = MusicLibraryService(
            fileImportService: FirstSeenFileImportStub(files: [file]),
            metadataService: metadata,
            identityService: FirstSeenIdentityStub(),
            checkpointService: checkpoint,
            now: { now }
        )

        let first = try await service.loadLibraryReport(
            from: directory,
            previousTracks: [],
            depth: .complete
        )
        let savedEntries = await checkpoint.recentEntries(
            for: directory,
            since: now.addingTimeInterval(-600)
        )
        XCTAssertEqual(savedEntries.count, 1)
        XCTAssertEqual(savedEntries["song.m4a"]?.track, first.library.tracks.first)
        let resumed = try await service.loadLibraryReport(
            from: directory,
            previousTracks: [],
            depth: .complete
        )

        let metadataCallCount = await metadata.callCount
        XCTAssertEqual(metadataCallCount, 1)
        XCTAssertEqual(resumed.library.tracks, first.library.tracks)
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
    var notices: [LibraryScanNotice] = []
    func saveLibraryFolders(_ urls: [URL]) throws {}
    func restoreLibraryFolders() throws -> [URL] { [] }
    func audioFiles(in folderURL: URL) async throws -> [URL] { files }
    func audioFileScan(in folderURL: URL) async throws -> AudioFileScanResult {
        AudioFileScanResult(files: files, notices: notices)
    }
}

private struct FailingMetadataStub: MetadataServicing {
    func metadata(for fileURL: URL, relativeTo libraryFolder: URL, discoveredAt: Date) async throws -> Track {
        throw NSError(domain: "MetadataTest", code: 17, userInfo: [
            NSLocalizedDescriptionKey: "metadata unavailable"
        ])
    }
}

private actor ScanProgressRecorder {
    private(set) var values: [LibraryScanProgress] = []
    func append(_ value: LibraryScanProgress) { values.append(value) }
}

private actor CheckpointMetadataStub: MetadataServicing {
    private(set) var callCount = 0

    func metadata(for fileURL: URL, relativeTo libraryFolder: URL, discoveredAt: Date) async throws -> Track {
        callCount += 1
        let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let relativePath = fileURL.lastPathComponent
        let identityPath = libraryFolder.standardizedFileURL.path.precomposedStringWithCanonicalMapping
            + "/" + relativePath
        return Track(
            id: StableTrackIdentifier.id(for: identityPath),
            title: "Refreshed title",
            artistName: "Artist",
            duration: 180,
            fileURL: fileURL,
            relativePath: relativePath,
            fileSize: values.fileSize.map(Int64.init),
            modificationDate: values.contentModificationDate,
            firstSeenAt: discoveredAt,
            metadataRevision: MetadataService.currentMetadataRevision
        )
    }
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
