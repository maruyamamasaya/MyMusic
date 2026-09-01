import Foundation
import XCTest
@testable import MyMusic

@MainActor
final class PlaybackHistoryResetTests: XCTestCase {
    func testResetClearsOnlySelectedTrackPlaybackFacts() async throws {
        let targetID = UUID()
        let untouchedID = UUID()
        let target = PlaybackHistory(
            trackID: targetID,
            isFavorite: true,
            playCount: 12,
            lastPlayedAt: Date(timeIntervalSince1970: 300),
            playbackPreference: 4,
            playbackEvents: [
                playbackEvent(trackID: targetID, at: 100),
                playbackEvent(trackID: targetID, at: 200)
            ],
            boredomCount: 2,
            boredomHiddenUntil: Date(timeIntervalSince1970: 400),
            isPermanentlyHiddenFromShuffle: false
        )
        let untouched = PlaybackHistory(
            trackID: untouchedID,
            isFavorite: false,
            playCount: 3,
            lastPlayedAt: Date(timeIntervalSince1970: 250),
            playbackEvents: [playbackEvent(trackID: untouchedID, at: 250)]
        )
        let persistence = PlaybackHistoryResetPersistence(history: [target, untouched])
        let store = PlaybackHistoryStore(persistence: persistence)

        await store.loadIfNeeded()
        store.resetPlaybackHistory(for: targetID)

        let resetEntry = try XCTUnwrap(store.entries[targetID])
        XCTAssertEqual(resetEntry.playCount, 0)
        XCTAssertNil(resetEntry.lastPlayedAt)
        XCTAssertTrue(resetEntry.playbackEvents.isEmpty)
        XCTAssertTrue(resetEntry.isFavorite)
        XCTAssertEqual(resetEntry.playbackPreference, 4)
        XCTAssertEqual(resetEntry.boredomCount, 2)
        XCTAssertEqual(resetEntry.boredomHiddenUntil, Date(timeIntervalSince1970: 400))
        XCTAssertFalse(resetEntry.isPermanentlyHiddenFromShuffle)
        XCTAssertEqual(store.entries[untouchedID], untouched)

        let saved = await persistence.nextSavedHistory()
        XCTAssertEqual(saved.first(where: { $0.trackID == targetID }), resetEntry)
        XCTAssertEqual(saved.first(where: { $0.trackID == untouchedID }), untouched)
    }
}

private func playbackEvent(trackID: UUID, at timestamp: TimeInterval) -> PlaybackEvent {
    let date = Date(timeIntervalSince1970: timestamp)
    return PlaybackEvent(trackID: trackID, startedAt: date, endedAt: date, listenedSeconds: 0,
                         completionRatio: 0, wasSkipped: false, wasFullPlayback: false,
                         startKind: .manual, startSource: .unknown)
}

private actor PlaybackHistoryResetPersistence: PlaybackHistoryPersistenceServicing {
    private let initialHistory: [PlaybackHistory]
    private var savedHistory: [PlaybackHistory]?
    private var saveContinuation: CheckedContinuation<[PlaybackHistory], Never>?

    init(history: [PlaybackHistory]) {
        initialHistory = history
    }

    func load() async throws -> [PlaybackHistory] {
        initialHistory
    }

    func save(_ history: [PlaybackHistory]) async throws {
        savedHistory = history
        saveContinuation?.resume(returning: history)
        saveContinuation = nil
    }

    func nextSavedHistory() async -> [PlaybackHistory] {
        if let savedHistory { return savedHistory }
        return await withCheckedContinuation { continuation in
            saveContinuation = continuation
        }
    }
}
