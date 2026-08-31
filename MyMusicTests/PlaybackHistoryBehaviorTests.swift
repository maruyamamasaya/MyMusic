import Foundation
import XCTest
@testable import MyMusic

@MainActor
final class PlaybackHistoryBehaviorTests: XCTestCase {
    func testFirstPlayedAtDailySummariesAndRecentCounts() async throws {
        let trackID = UUID()
        let persistence = PlaybackHistoryBehaviorPersistence()
        let store = PlaybackHistoryStore(persistence: persistence)
        await store.loadIfNeeded()

        let first = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 30, hour: 10)))
        let second = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 30, hour: 12)))
        let third = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 8, day: 31, hour: 9)))
        let now = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 9)))

        store.recordPlaybackStarted(
            trackID: trackID,
            context: PlaybackStartContext(kind: .manual, source: .search),
            isRepeatModeActive: false,
            isConsecutivePlay: false,
            now: first
        )
        store.recordPlaybackStarted(
            trackID: trackID,
            context: PlaybackStartContext(kind: .automatic, source: .shuffle),
            isRepeatModeActive: false,
            isConsecutivePlay: true,
            now: second
        )
        store.recordPlaybackStarted(
            trackID: trackID,
            context: PlaybackStartContext(kind: .manual, source: .station),
            isRepeatModeActive: false,
            isConsecutivePlay: false,
            now: third
        )

        XCTAssertEqual(store.firstPlayedAt(for: trackID), first)
        XCTAssertEqual(store.lastPlayedAt(for: trackID), third)
        XCTAssertEqual(store.playbackCount(for: trackID, inLastDays: 7, now: now), 3)
        XCTAssertEqual(store.playbackCount(for: trackID, inLastDays: 30, now: now), 3)
        XCTAssertEqual(store.manualPlayCount(for: trackID), 2)
        XCTAssertEqual(store.automaticPlayCount(for: trackID), 1)
        XCTAssertEqual(store.playCount(for: trackID, source: .search), 1)
        XCTAssertEqual(store.playCount(for: trackID, source: .shuffle), 1)
        XCTAssertEqual(store.playCount(for: trackID, source: .station), 1)
        XCTAssertEqual(store.dailySummaries(for: trackID).count, 2)
    }

    func testLegacyPlaybackHistoryDecodesWithDerivedHistoryFields() throws {
        let trackID = UUID()
        let first = Date(timeIntervalSince1970: 1_000)
        let second = Date(timeIntervalSince1970: 90_000)
        let payload = """
        {
          "trackID": "\(trackID.uuidString)",
          "isFavorite": false,
          "playCount": 2,
          "lastPlayedAt": \(second.timeIntervalSince1970),
          "playbackEvents": [\(first.timeIntervalSince1970), \(second.timeIntervalSince1970)]
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970

        let decoded = try decoder.decode(PlaybackHistory.self, from: Data(payload.utf8))

        XCTAssertEqual(decoded.firstPlayedAt, first)
        XCTAssertEqual(decoded.dailySummaries.values.reduce(0) { $0 + $1.playCount }, 2)
        XCTAssertEqual(decoded.manualPlayCount, 0)
        XCTAssertEqual(decoded.automaticPlayCount, 0)
        XCTAssertTrue(decoded.playbackSourceCounts.isEmpty)
    }

    func testPlayerStoreRecordsStationShuffleAndRepeatStartsOnce() async throws {
        let first = makeTrack("First")
        let second = makeTrack("Second")
        let historyPersistence = PlaybackHistoryBehaviorPersistence()
        let historyStore = PlaybackHistoryStore(persistence: historyPersistence)
        let player = PlaybackHistoryAudioPlayerSpy()
        let store = PlayerStore(
            audioPlayer: player,
            playbackHistoryStore: historyStore,
            nowPlayingService: PlaybackHistoryNowPlayingSpy(),
            remoteCommandService: PlaybackHistoryRemoteCommandSpy(),
            trackPlaybackAdjustmentStore: TrackPlaybackAdjustmentStore(
                persistence: PlaybackHistoryAdjustmentPersistence()
            )
        )

        await historyStore.loadIfNeeded()
        store.playQueue(
            [first, second],
            startingAt: 0,
            startContext: PlaybackStartContext(kind: .manual, source: .station)
        )
        try await waitUntil { historyStore.playCount(for: first.id, source: .station) == 1 }

        store.setShuffleEnabled(true)
        player.send(.ended)
        try await waitUntil { historyStore.playCount(for: second.id, source: .shuffle) == 1 }

        store.cycleRepeatMode()
        store.cycleRepeatMode()
        player.send(.ended)
        try await waitUntil { historyStore.playCount(for: second.id, source: .repeatPlayback) == 1 }

        XCTAssertEqual(historyStore.manualPlayCount(for: first.id), 1)
        XCTAssertEqual(historyStore.automaticPlayCount(for: second.id), 2)
        XCTAssertEqual(historyStore.repeatPlaybackCount(for: second.id), 1)
    }

    private func makeTrack(_ title: String) -> Track {
        Track(
            id: UUID(),
            title: title,
            artistName: "Artist",
            duration: 120,
            fileURL: URL(fileURLWithPath: "/tmp/\(title).wav"),
            relativePath: "\(title).wav"
        )
    }

    private func waitUntil(_ condition: @escaping @MainActor () async -> Bool) async throws {
        for _ in 0..<100 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for player state")
    }
}

private actor PlaybackHistoryBehaviorPersistence: PlaybackHistoryPersistenceServicing {
    private let initialHistory: [PlaybackHistory]
    private var savedHistory: [PlaybackHistory] = []

    init(history: [PlaybackHistory] = []) {
        initialHistory = history
    }

    func load() async throws -> [PlaybackHistory] { initialHistory }
    func save(_ history: [PlaybackHistory]) async throws { savedHistory = history }
    func saved() -> [PlaybackHistory] { savedHistory }
}

private actor PlaybackHistoryAdjustmentPersistence: TrackPlaybackAdjustmentPersistenceServicing {
    func load(trackID: Track.ID) async throws -> TrackPlaybackAdjustment? { nil }
    func save(_ adjustment: TrackPlaybackAdjustment) async throws {}
}

@MainActor
private final class PlaybackHistoryAudioPlayerSpy: AudioPlayerServicing, PlaybackTransitionAudioControlling {
    var eventHandler: ((AudioPlaybackEvent) -> Void)?

    func play(_ track: Track) async throws {
        eventHandler?(.ready(duration: track.duration))
        eventHandler?(.playingChanged(true))
    }

    func play(_ track: Track, transition: PlaybackTransitionReason) async throws {
        try await play(track)
    }

    func play(
        _ track: Track,
        startingAt playbackTime: TimeInterval,
        endingAt playbackEndTime: TimeInterval?,
        transition: PlaybackTransitionReason
    ) async throws {
        try await play(track)
    }

    func pause() { eventHandler?(.playingChanged(false)) }
    func resume() async throws { eventHandler?(.playingChanged(true)) }
    func seek(to time: TimeInterval) { eventHandler?(.timeChanged(time)) }
    func seek(to time: TimeInterval, transition: PlaybackTransitionReason) async throws { seek(to: time) }
    func seek(
        to time: TimeInterval,
        endingAt playbackEndTime: TimeInterval?,
        transition: PlaybackTransitionReason
    ) async throws { seek(to: time) }
    func scheduleFadeOut(endingAt playbackTime: TimeInterval, reason: PlaybackTransitionReason) {}
    func stop() {}

    func send(_ event: AudioPlaybackEvent) {
        eventHandler?(event)
    }
}

@MainActor
private final class PlaybackHistoryNowPlayingSpy: NowPlayingServicing {
    func setTrack(_ track: Track, duration: TimeInterval, elapsedTime: TimeInterval, isPlaying: Bool) {}
    func updateDuration(_ duration: TimeInterval, elapsedTime: TimeInterval, isPlaying: Bool) {}
    func updatePlayback(elapsedTime: TimeInterval, isPlaying: Bool) {}
    func clear() {}
}

@MainActor
private final class PlaybackHistoryRemoteCommandSpy: RemoteCommandServicing {
    func configure(actions: RemoteCommandActions) {}
    func updateAvailability(hasTrack: Bool, canGoNext: Bool, canGoPrevious: Bool) {}
}
