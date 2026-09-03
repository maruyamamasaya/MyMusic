import Foundation
import XCTest
@testable import MyMusic

final class LibrarySyncServiceTests: XCTestCase {
    func testConcurrentScansAreSerializedThroughPersistence() async throws {
        let scanner = ConcurrencyCheckingLibraryService()
        let persistence = RecordingLibraryPersistence()
        let subject = LibrarySyncService(service: scanner, persistence: persistence)

        async let first = subject.scan(
            folderURL: URL(fileURLWithPath: "/tmp/library-a"),
            previousTracks: []
        )
        async let second = subject.scan(
            folderURL: URL(fileURLWithPath: "/tmp/library-b"),
            previousTracks: []
        )
        _ = try await (first, second)

        let maximumConcurrentScans = await scanner.maximumConcurrentScans
        XCTAssertEqual(maximumConcurrentScans, 1)
        try await subject.save(MusicLibrary.build(from: []), for: URL(fileURLWithPath: "/tmp/library-a"))
        try await subject.save(MusicLibrary.build(from: []), for: URL(fileURLWithPath: "/tmp/library-b"))
        let saveCount = await persistence.saveCount
        XCTAssertEqual(saveCount, 2)
    }

    func testCombinedLibraryPreservesStableTrackIDs() async {
        let subject = LibrarySyncService(
            service: EmptyLibraryService(),
            persistence: RecordingLibraryPersistence()
        )
        let id = UUID()
        let track = Track(
            id: id,
            title: "Song",
            artistName: "Artist",
            duration: 180,
            fileURL: URL(fileURLWithPath: "/tmp/library/song.m4a"),
            relativePath: "song.m4a"
        )

        let combined = await subject.combinedLibrary(
            folderIDs: ["library"],
            librariesByFolderID: ["library": MusicLibrary.build(from: [track])]
        )

        XCTAssertEqual(combined.tracks.map(\.id), [id])
    }
}

private actor ConcurrencyCheckingLibraryService: MusicLibraryServicing {
    private var concurrentScans = 0
    private(set) var maximumConcurrentScans = 0

    func loadLibrary(from folderURL: URL, previousTracks: [Track]) async throws -> MusicLibrary {
        concurrentScans += 1
        maximumConcurrentScans = max(maximumConcurrentScans, concurrentScans)
        try await Task.sleep(for: .milliseconds(30))
        concurrentScans -= 1
        return MusicLibrary.build(from: [])
    }
}

private struct EmptyLibraryService: MusicLibraryServicing {
    func loadLibrary(from folderURL: URL, previousTracks: [Track]) async throws -> MusicLibrary {
        MusicLibrary.build(from: [])
    }
}

private actor RecordingLibraryPersistence: LibraryPersistenceServicing {
    private(set) var saveCount = 0
    func load(for folderURL: URL) async throws -> MusicLibrary? { nil }
    func save(_ library: MusicLibrary, for folderURL: URL) async throws { saveCount += 1 }
}
