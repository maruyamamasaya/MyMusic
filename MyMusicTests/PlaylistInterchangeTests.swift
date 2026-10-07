import XCTest
@testable import MyMusic

@MainActor
final class PlaylistInterchangeTests: XCTestCase {
    func testRepeatedJSONImportsKeepIdentityTagsOrderAndPersistedCount() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let persistence = PlaylistPersistenceService(fileURL: root.appendingPathComponent("playlists.json"))
        let archive = PlaylistImportArchiveService(directory: root.appendingPathComponent("archive"))
        let store = PlaylistStore(persistence: persistence)
        await store.loadIfNeeded()
        let tracks = [track("First"), track("Second")]
        let original = Playlist(id: UUID(), name: "夜", trackIDs: tracks.map(\.id),
            createdAt: Date(timeIntervalSince1970: 100), updatedAt: Date(timeIntervalSince1970: 200), tags: ["夜", "集中"])
        var data = try MusicDataExportService().allPlaylistsJSON([original], tracks: tracks).data
        for index in 0..<4 {
            let result = try MusicDataImportService().parse(data: data, fileExtension: "json", libraryTracks: tracks)
            let summary = try await store.applyImportedPlaylists(result.playlists, original: data, archive: archive)
            XCTAssertEqual(summary.added, index == 0 ? 1 : 0)
            XCTAssertEqual(summary.unchanged, index == 0 ? 0 : 1)
            XCTAssertEqual(store.playlists, [original])
            data = try MusicDataExportService().allPlaylistsJSON(store.playlists, tracks: tracks).data
        }
        let reloaded = try await persistence.load()
        XCTAssertEqual(reloaded, [original])
    }

    func testChangedIDRequiresConfirmationAndKeepsBackup() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let persistence = PlaylistPersistenceService(fileURL: root.appendingPathComponent("playlists.json"))
        let archiveURL = root.appendingPathComponent("archive")
        let archive = PlaylistImportArchiveService(directory: archiveURL)
        let store = PlaylistStore(persistence: persistence)
        await store.loadIfNeeded()
        let tracks = [track("First")]
        let first = Playlist(id: UUID(), name: "Original", trackIDs: tracks.map(\.id),
            createdAt: Date(timeIntervalSince1970: 100), updatedAt: Date(timeIntervalSince1970: 200), tags: ["夜"])
        let initialData = try MusicDataExportService().allPlaylistsJSON([first], tracks: tracks).data
        let initial = try MusicDataImportService().parse(data: initialData, fileExtension: "json", libraryTracks: tracks)
        _ = try await store.applyImportedPlaylists(initial.playlists, original: initialData, archive: archive)
        var changed = first
        changed.name = "Mac edit"
        changed.tags = ["集中"]
        changed.updatedAt = Date(timeIntervalSince1970: 300)
        let data = try MusicDataExportService().allPlaylistsJSON([changed], tracks: tracks).data
        let parsed = try MusicDataImportService().parse(data: data, fileExtension: "json", libraryTracks: tracks)
        do {
            _ = try await store.applyImportedPlaylists(parsed.playlists, original: data, archive: archive)
            XCTFail("Unconfirmed replacement must fail")
        } catch { XCTAssertEqual(store.playlists, [first]) }
        _ = try await store.applyImportedPlaylists(parsed.playlists, original: data, archive: archive, allowUpdatingExisting: true)
        XCTAssertEqual(store.playlists, [changed])
        let files = try FileManager.default.contentsOfDirectory(at: archiveURL, includingPropertiesForKeys: nil)
        XCTAssertTrue(try files.contains { try Data(contentsOf: $0) == data })
        XCTAssertTrue(try files.contains { (try? JSONDecoder().decode([Playlist].self, from: Data(contentsOf: $0))) == [first] })
    }

    func testMissingTagsKeepExistingTagsAndMalformedIDIsRejected() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let persistence = PlaylistPersistenceService(fileURL: root.appendingPathComponent("playlists.json"))
        let first = Playlist(id: UUID(), name: "Legacy", trackIDs: [], createdAt: .distantPast,
            updatedAt: .distantPast, tags: ["夜"])
        try await persistence.save([first])
        let store = PlaylistStore(persistence: persistence)
        await store.loadIfNeeded()
        let data = Data("{\"version\":1,\"playlistID\":\"\(first.id)\",\"name\":\"Legacy\",\"tracks\":[]}".utf8)
        let parsed = try MusicDataImportService().parse(data: data, fileExtension: "json", libraryTracks: [])
        _ = try await store.applyImportedPlaylists(parsed.playlists, original: data,
            archive: PlaylistImportArchiveService(directory: root.appendingPathComponent("archive")))
        XCTAssertEqual(store.playlists, [first])
        let invalid = Data("{\"version\":1,\"playlistID\":\"invalid\",\"name\":\"Legacy\",\"tracks\":[]}".utf8)
        XCTAssertThrowsError(try MusicDataImportService().parse(data: invalid, fileExtension: "json", libraryTracks: []))
    }

    func testMissingReferencesAreRejectedOnImportAndExport() throws {
        let missing = UUID()
        let playlist = Playlist(id: UUID(), name: "Missing", trackIDs: [missing], createdAt: Date(), updatedAt: Date())
        XCTAssertThrowsError(try MusicDataExportService().allPlaylistsJSON([playlist], tracks: []))
        let data = Data("{\"version\":1,\"playlistID\":\"\(playlist.id)\",\"name\":\"Missing\",\"tracks\":[{\"trackID\":\"\(missing)\"}]}".utf8)
        XCTAssertThrowsError(try MusicDataImportService().parse(data: data, fileExtension: "json", libraryTracks: []))
    }

    func testSaveFailureDoesNotPublishImportedData() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = PlaylistStore(persistence: FailingPlaylistPersistence())
        await store.loadIfNeeded()
        let draft = PlaylistImportDraft(id: UUID(), createdAt: nil, updatedAt: nil, tagsWereProvided: true,
            name: "Failure", trackIDs: [], kind: .regular, tags: [])
        do {
            _ = try await store.applyImportedPlaylists([draft], original: Data("{}".utf8),
                archive: PlaylistImportArchiveService(directory: root.appendingPathComponent("archive")))
            XCTFail("Save must fail")
        } catch { XCTAssertTrue(store.playlists.isEmpty) }
    }

    func testArchiveFailureAndStaleConfirmationLeaveExistingPlaylistUntouched() async throws {
        let root = try temporaryDirectory()
        defer { try? FileManager.default.removeItem(at: root) }
        let persistence = PlaylistPersistenceService(fileURL: root.appendingPathComponent("playlists.json"))
        let first = Playlist(id: UUID(), name: "Existing", trackIDs: [],
            createdAt: Date(timeIntervalSince1970: 100), updatedAt: Date(timeIntervalSince1970: 200), tags: ["夜"])
        try await persistence.save([first])
        let store = PlaylistStore(persistence: persistence)
        await store.loadIfNeeded()
        let draft = PlaylistImportDraft(id: first.id, createdAt: first.createdAt, updatedAt: first.updatedAt,
            tagsWereProvided: true, name: "Received", trackIDs: [], kind: .regular, tags: ["集中"])
        let blocker = root.appendingPathComponent("blocked")
        try Data("file".utf8).write(to: blocker)
        do {
            _ = try await store.applyImportedPlaylists([draft], original: Data("{}".utf8),
                archive: PlaylistImportArchiveService(directory: blocker), allowUpdatingExisting: true)
            XCTFail("Archive failure must abort")
        } catch { XCTAssertEqual(store.playlists, [first]) }
        let snapshot = store.playlists
        store.setTags(["Local edit"], for: first.id)
        await store.waitForPendingSave()
        let edited = store.playlists
        do {
            _ = try await store.applyImportedPlaylists([draft], original: Data("{}".utf8),
                archive: PlaylistImportArchiveService(directory: root.appendingPathComponent("archive")),
                allowUpdatingExisting: true, expectedPlaylists: snapshot)
            XCTFail("Stale confirmation must abort")
        } catch { XCTAssertEqual(store.playlists, edited) }
        let persisted = try await persistence.load()
        XCTAssertEqual(persisted, edited)
    }

    func testDuplicatePlaylistIDsAndInvalidTailRejectEntireDocument() throws {
        let id = UUID()
        let valid = "{\"playlistID\":\"\(id)\",\"name\":\"Valid\",\"tracks\":[]}"
        let duplicate = Data("{\"version\":1,\"playlists\":[\(valid),\(valid)]}".utf8)
        XCTAssertThrowsError(try MusicDataImportService().parse(data: duplicate, fileExtension: "json", libraryTracks: []))
        let invalidTail = Data("{\"version\":1,\"playlists\":[\(valid),{\"name\":\"Invalid\",\"tracks\":[{\"trackID\":\"bad\"}]}]}".utf8)
        XCTAssertThrowsError(try MusicDataImportService().parse(data: invalidTail, fileExtension: "json", libraryTracks: []))
    }

    private func track(_ name: String) -> Track {
        Track(id: UUID(), title: name, artistName: "Artist", duration: 120,
            fileURL: URL(fileURLWithPath: "/tmp/\(name).wav"))
    }

    private func temporaryDirectory() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }
}

private actor FailingPlaylistPersistence: PlaylistPersistenceServicing {
    func load() async throws -> [Playlist] { [] }
    func save(_ playlists: [Playlist]) async throws { throw CocoaError(.fileWriteUnknown) }
}
