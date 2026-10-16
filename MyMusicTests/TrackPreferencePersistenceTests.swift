import Foundation
import XCTest
@testable import MyMusic

@MainActor
final class TrackPreferencePersistenceTests: XCTestCase {
    func testExpandedRangePersistsAndKeepsNegativeLimit() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = TrackPreferencePersistenceService(applicationDirectory: directory)
        let store = TrackPreferenceStore(persistence: persistence)
        let id = UUID()
        await store.loadIfNeeded(legacyHistory: [:])
        for _ in 0..<20 { store.increasePlaybackPreference(for: id) }
        await store.waitForPendingSave()
        XCTAssertEqual(store.playbackPreference(for: id), 15)
        let loaded = TrackPreferenceStore(persistence: persistence)
        await loaded.loadIfNeeded(legacyHistory: [:])
        XCTAssertEqual(loaded.playbackPreference(for: id), 15)
        XCTAssertEqual(try TrackPreferenceImportService().parse(data: document(id: id, preference: 15, favorite: true)).first?.playbackPreference, 15)
        for _ in 0..<30 { loaded.decreasePlaybackPreference(for: id) }
        await loaded.waitForPendingSave()
        XCTAssertEqual(loaded.playbackPreference(for: id), -10)
    }

    func testLegacyHistoryMigratesOnceAndSurvivesReload() async throws {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "track-preference-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let trackID = UUID()
        let legacy = PlaybackHistory(
            trackID: trackID, isFavorite: true, playCount: 42,
            lastPlayedAt: Date(), playbackPreference: 4
        )
        let persistence = TrackPreferencePersistenceService(applicationDirectory: directory)
        let first = TrackPreferenceStore(persistence: persistence)

        await first.loadIfNeeded(legacyHistory: [trackID: legacy])

        XCTAssertTrue(first.isLoaded)
        XCTAssertTrue(first.isFavorite(trackID: trackID))
        XCTAssertEqual(first.playbackPreference(for: trackID), 4)

        let conflictingLegacy = PlaybackHistory(
            trackID: trackID, isFavorite: false, playCount: 0,
            lastPlayedAt: nil, playbackPreference: -8
        )
        let reloaded = TrackPreferenceStore(persistence: persistence)
        await reloaded.loadIfNeeded(legacyHistory: [trackID: conflictingLegacy])

        XCTAssertTrue(reloaded.isFavorite(trackID: trackID))
        XCTAssertEqual(reloaded.playbackPreference(for: trackID), 4)
    }

    func testFavoriteAndPreferencePersistTogether() async throws {
        let persistence = PreferenceMemoryPersistence()
        let trackID = UUID()
        let store = TrackPreferenceStore(persistence: persistence)
        await store.loadIfNeeded(legacyHistory: [:])

        store.toggleFavorite(trackID: trackID)
        store.increasePlaybackPreference(for: trackID)
        await store.waitForPendingSave()

        let reloaded = TrackPreferenceStore(persistence: persistence)
        await reloaded.loadIfNeeded(legacyHistory: [:])
        XCTAssertTrue(reloaded.isFavorite(trackID: trackID))
        XCTAssertEqual(reloaded.playbackPreference(for: trackID), 1)
    }

    func testChangesDuringSaveCoalesceAndPersistLatestStateWithLargeLibrary() async {
        let trackID = UUID()
        let initial = (0..<15_000).map { _ in
            TrackPreference(trackID: UUID(), playbackPreference: 0, favorite: false)
        }
        let persistence = BlockingPreferencePersistence(initial: initial)
        let store = TrackPreferenceStore(persistence: persistence)
        await store.loadIfNeeded(legacyHistory: [:])
        store.toggleFavorite(trackID: trackID)
        await persistence.waitForFirstSave()

        for _ in 0..<5 { store.increasePlaybackPreference(for: trackID) }
        store.toggleFavorite(trackID: trackID)
        XCTAssertFalse(store.isFavorite(trackID: trackID))
        XCTAssertEqual(store.playbackPreference(for: trackID), 5)
        await persistence.releaseFirstSave()
        await store.waitForPendingSave()

        let saved = await persistence.load()
        let saveCount = await persistence.saveCount
        XCTAssertEqual(saveCount, 2)
        XCTAssertEqual(saved?.count, 15_001)
        XCTAssertEqual(saved?.first(where: { $0.trackID == trackID }),
                       TrackPreference(trackID: trackID, playbackPreference: 5, favorite: false))
    }

    func testPreferenceImportMergesKnownTracksAndSurvivesReload() async throws {
        let persistence = PreferenceMemoryPersistence()
        let changedID = UUID()
        let unchangedID = UUID()
        let missingID = UUID()
        let store = TrackPreferenceStore(persistence: persistence)
        await store.loadIfNeeded(legacyHistory: [
            changedID: PlaybackHistory(trackID: changedID, isFavorite: false,
                                       playCount: 4, lastPlayedAt: nil, playbackPreference: 1),
            unchangedID: PlaybackHistory(trackID: unchangedID, isFavorite: true,
                                         playCount: 7, lastPlayedAt: nil, playbackPreference: 2)
        ])

        let report = try await store.importPreferences([
            TrackPreference(trackID: changedID, playbackPreference: -4, favorite: true),
            TrackPreference(trackID: unchangedID, playbackPreference: 2, favorite: true),
            TrackPreference(trackID: missingID, playbackPreference: 8, favorite: true)
        ], libraryTrackIDs: [changedID, unchangedID])

        XCTAssertEqual(report, TrackPreferenceImportResult(
            total: 3, updated: 1, unchanged: 1, missingTrack: 1, invalid: 0
        ))
        XCTAssertEqual(store.playbackPreference(for: changedID), -4)
        XCTAssertTrue(store.isFavorite(trackID: changedID))
        XCTAssertEqual(store.playbackPreference(for: missingID), 0)

        let reloaded = TrackPreferenceStore(persistence: persistence)
        await reloaded.loadIfNeeded(legacyHistory: [:])
        XCTAssertEqual(reloaded.entries, store.entries)
    }

    func testPreferenceImportDoesNotChangeStoreWhenSaveFails() async {
        let trackID = UUID()
        let persistence = PreferenceMemoryPersistence()
        let store = TrackPreferenceStore(persistence: persistence)
        await store.loadIfNeeded(legacyHistory: [:])
        await persistence.failNextSave()

        do {
            _ = try await store.importPreferences([
                TrackPreference(trackID: trackID, playbackPreference: 5, favorite: true)
            ], libraryTrackIDs: [trackID])
            XCTFail("Expected save failure")
        } catch { }

        XCTAssertTrue(store.entries.isEmpty)
    }

    func testPreferenceImportParserValidatesWholeV2Contract() throws {
        let id = UUID()
        let valid = document(id: id, preference: 3, favorite: true)
        XCTAssertEqual(try TrackPreferenceImportService().parse(data: valid), [
            TrackPreference(trackID: id, playbackPreference: 3, favorite: true)
        ])

        XCTAssertThrowsError(try TrackPreferenceImportService().parse(
            data: document(id: id, preference: 16, favorite: true)
        ))
        XCTAssertThrowsError(try TrackPreferenceImportService().parse(data: Data("""
            {"schemaVersion":2,"exportedAt":"2026-09-02T12:00:00Z","tracks":[
              {"trackId":"not-a-uuid","playbackPreference":0,"favorite":false}]}
            """.utf8)))
        XCTAssertThrowsError(try TrackPreferenceImportService().parse(data: Data("""
            {"schemaVersion":2,"exportedAt":"2026-09-02T12:00:00Z","tracks":[
              {"trackId":"\(id.uuidString)","playbackPreference":0,"favorite":false},
              {"trackId":"\(id.uuidString)","playbackPreference":1,"favorite":true}]}
            """.utf8)))
        XCTAssertThrowsError(try TrackPreferenceImportService().parse(data: Data("""
            {"schemaVersion":2,"exportedAt":"2026-09-02T12:00:00Z","tracks":[
              {"trackId":"\(id.uuidString)","playbackPreference":0,"favorite":false,"title":"No"}]}
            """.utf8)))
        XCTAssertThrowsError(try TrackPreferenceImportService().parse(data: Data("""
            {"schemaVersion":1,"exportedAt":"2026-09-02T12:00:00Z","tracks":[]}
            """.utf8)))
        XCTAssertThrowsError(try TrackPreferenceImportService().parse(data: Data("""
            {"schemaVersion":2,"exportedAt":"2026-09-02T12:00:00Z","tracks":[
              {"trackId":"\(id.uuidString)","playbackPreference":0,"favorite":1}]}
            """.utf8)))
        XCTAssertThrowsError(try TrackPreferenceImportService().parse(data: Data("{".utf8)))
    }

    private func document(id: UUID, preference: Int, favorite: Bool) -> Data {
        Data("""
        {"schemaVersion":2,"exportedAt":"2026-09-02T12:00:00Z","tracks":[
          {"trackId":"\(id.uuidString)","playbackPreference":\(preference),"favorite":\(favorite)}]}
        """.utf8)
    }
}

private actor PreferenceMemoryPersistence: TrackPreferencePersistenceServicing {
    private var entries: [TrackPreference]?
    private var shouldFailNextSave = false

    func load() async throws -> [TrackPreference]? { entries }
    func save(_ preferences: [TrackPreference]) async throws {
        if shouldFailNextSave {
            shouldFailNextSave = false
            throw CocoaError(.fileWriteUnknown)
        }
        entries = preferences
    }

    func failNextSave() { shouldFailNextSave = true }
}

private actor BlockingPreferencePersistence: TrackPreferencePersistenceServicing {
    private var entries: [TrackPreference]
    private(set) var saveCount = 0
    private var started: CheckedContinuation<Void, Never>?
    private var release: CheckedContinuation<Void, Never>?

    init(initial: [TrackPreference]) { entries = initial }
    func load() -> [TrackPreference]? { entries }
    func save(_ preferences: [TrackPreference]) async throws {
        saveCount += 1
        if saveCount == 1 {
            await withCheckedContinuation { continuation in
                release = continuation
                started?.resume()
                started = nil
            }
        }
        entries = preferences
    }
    func waitForFirstSave() async {
        if release != nil { return }
        await withCheckedContinuation { started = $0 }
    }
    func releaseFirstSave() {
        release?.resume()
        release = nil
    }
}
