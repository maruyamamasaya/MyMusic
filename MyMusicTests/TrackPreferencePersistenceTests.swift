import Foundation
import XCTest
@testable import MyMusic

@MainActor
final class TrackPreferencePersistenceTests: XCTestCase {
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
        await persistence.waitForPreference(1)

        let reloaded = TrackPreferenceStore(persistence: persistence)
        await reloaded.loadIfNeeded(legacyHistory: [:])
        XCTAssertTrue(reloaded.isFavorite(trackID: trackID))
        XCTAssertEqual(reloaded.playbackPreference(for: trackID), 1)
    }
}

private actor PreferenceMemoryPersistence: TrackPreferencePersistenceServicing {
    private var entries: [TrackPreference]?

    func load() async throws -> [TrackPreference]? { entries }
    func save(_ preferences: [TrackPreference]) async throws { entries = preferences }

    func waitForPreference(_ value: Int) async {
        for _ in 0..<100 where entries?.first?.playbackPreference != value {
            await Task.yield()
        }
    }
}
