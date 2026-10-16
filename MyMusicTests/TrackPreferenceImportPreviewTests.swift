import XCTest
@testable import MyMusic

@MainActor
final class TrackPreferenceImportPreviewTests: XCTestCase {
    func testPreviewShowsRatingHeartUnchangedDefaultsAndMissingWithoutWriting() async throws {
        let (store, persistence) = makeStore()
        await store.loadIfNeeded(legacyHistory: [:])
        let tracks = (0..<4).map { makeTrack("Song \($0)") }
        store.increasePlaybackPreference(for: tracks[0].id)
        await store.waitForPendingSave()
        let before = try await persistence.load()
        let incoming = [
            TrackPreference(trackID: tracks[0].id, playbackPreference: 15, favorite: false),
            TrackPreference(trackID: tracks[1].id, playbackPreference: 0, favorite: true),
            TrackPreference(trackID: tracks[2].id, playbackPreference: 0, favorite: false),
            TrackPreference(trackID: UUID(), playbackPreference: -10, favorite: true)
        ]
        let preview = try store.prepareImportPreview(incoming, tracks: tracks)
        XCTAssertEqual(preview.changedCount, 2)
        XCTAssertEqual(preview.unchangedCount, 1)
        XCTAssertEqual(preview.missingCount, 1)
        XCTAssertEqual(preview.rows[0].current?.playbackPreference, 1)
        XCTAssertEqual(preview.rows[0].incoming.playbackPreference, 15)
        XCTAssertEqual(preview.rows[1].current?.favorite, false)
        XCTAssertEqual(preview.rows[1].incoming.favorite, true)
        XCTAssertNil(preview.rows[3].current)
        let after = try await persistence.load()
        XCTAssertEqual(before, after) // Preparing/cancelling never persists.
        XCTAssertEqual(store.entries.count, 1)
    }

    func testApplyRechecksRatingAndHeartAndKeepsUnrelatedChanges() async throws {
        for changesHeart in [false, true] {
            let (store, _) = makeStore()
            await store.loadIfNeeded(legacyHistory: [:])
            let track = makeTrack("Target")
            let incoming = TrackPreference(trackID: track.id, playbackPreference: 15, favorite: true)
            let preview = try store.prepareImportPreview([incoming], tracks: [track])
            if changesHeart { store.toggleFavorite(trackID: track.id) }
            else { store.increasePlaybackPreference(for: track.id) }
            await store.waitForPendingSave()
            let before = store.entries
            do {
                _ = try await store.importPreferences(preview, libraryTrackIDs: [track.id])
                XCTFail("Expected stale preview rejection")
            } catch is TrackPreferenceImportPreviewError { }
            XCTAssertEqual(store.entries, before)
        }
        let (store, _) = makeStore()
        await store.loadIfNeeded(legacyHistory: [:])
        let target = makeTrack("Target"), other = makeTrack("Other")
        let preview = try store.prepareImportPreview([
            TrackPreference(trackID: target.id, playbackPreference: 15, favorite: true)
        ], tracks: [target, other])
        store.increasePlaybackPreference(for: other.id)
        _ = try await store.importPreferences(preview, libraryTrackIDs: [target.id, other.id])
        XCTAssertEqual(store.playbackPreference(for: target.id), 15)
        XCTAssertTrue(store.isFavorite(trackID: target.id))
        XCTAssertEqual(store.playbackPreference(for: other.id), 1)
    }

    func testChangedLibraryMembershipRequiresFreshPreview() async throws {
        let (store, _) = makeStore()
        await store.loadIfNeeded(legacyHistory: [:])
        let track = makeTrack("Target")
        let incoming = [TrackPreference(trackID: track.id, playbackPreference: 15, favorite: true)]
        for wasMatched in [true, false] {
            let preview = try store.prepareImportPreview(incoming, tracks: wasMatched ? [track] : [])
            do {
                _ = try await store.importPreferences(preview, libraryTrackIDs: wasMatched ? [] : [track.id])
                XCTFail("Expected changed mapping rejection")
            } catch is TrackPreferenceImportPreviewError { }
        }
        XCTAssertTrue(store.entries.isEmpty)
    }

    func testUnchangedDefaultDoesNotSaveAndFailedApplyPreservesState() async throws {
        let (store, persistence) = makeStore()
        await store.loadIfNeeded(legacyHistory: [:])
        let track = makeTrack("Target")
        let unchanged = try store.prepareImportPreview([
            TrackPreference(trackID: track.id, playbackPreference: 0, favorite: false)
        ], tracks: [track])
        let countBefore = await persistence.saveCount
        let report = try await store.importPreferences(unchanged, libraryTrackIDs: [track.id])
        XCTAssertEqual(report.updated, 0)
        XCTAssertEqual(report.unchanged, 1)
        let countAfter = await persistence.saveCount
        XCTAssertEqual(countAfter, countBefore)
        let changed = try store.prepareImportPreview([
            TrackPreference(trackID: track.id, playbackPreference: 15, favorite: true)
        ], tracks: [track])
        await persistence.failNextSave()
        do {
            _ = try await store.importPreferences(changed, libraryTrackIDs: [track.id])
            XCTFail("Expected save failure")
        } catch { }
        XCTAssertTrue(store.entries.isEmpty)
        XCTAssertFalse(store.isImporting)
        _ = try await store.importPreferences(changed, libraryTrackIDs: [track.id])
        XCTAssertEqual(store.playbackPreference(for: track.id), 15)
    }

    func testPreviewDoesNotTruncateChangesAfterOneHundredRows() {
        let tracks = (0..<105).map { makeTrack("Song \($0)") }
        let incoming = tracks.map { TrackPreference(trackID: $0.id, playbackPreference: 15, favorite: true) }
        let preview = TrackPreferenceImportPreview(imported: incoming, entries: [:], tracks: tracks)
        XCTAssertEqual(preview.changedCount, 105)
        XCTAssertEqual(preview.rows.count, 105)
    }

    private func makeTrack(_ title: String) -> Track {
        Track(id: UUID(), title: title, artistName: "Artist", duration: 180, fileURL: URL(fileURLWithPath: "/tmp/fixture.mp3"))
    }
    private func makeStore() -> (TrackPreferenceStore, PreviewPreferencePersistence) {
        let persistence = PreviewPreferencePersistence()
        return (TrackPreferenceStore(persistence: persistence), persistence)
    }
}

private actor PreviewPreferencePersistence: TrackPreferencePersistenceServicing {
    private var values: [TrackPreference]?
    private var shouldFail = false
    private(set) var saveCount = 0
    func failNextSave() { shouldFail = true }
    func load() async throws -> [TrackPreference]? { values }
    func save(_ preferences: [TrackPreference]) async throws {
        if shouldFail { shouldFail = false; throw CocoaError(.fileWriteUnknown) }
        saveCount += 1
        values = preferences
    }
}
