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

    func testPlaybackEventClassificationAndDailySummaryCounters() async throws {
        let trackID = UUID()
        let store = PlaybackHistoryStore(persistence: PlaybackHistoryBehaviorPersistence())
        await store.loadIfNeeded()
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let context = PlaybackStartContext(kind: .automatic, source: .station)
        store.recordPlaybackStarted(trackID: trackID, context: context, isRepeatModeActive: false,
                                    isConsecutivePlay: false, now: startedAt)
        store.recordPlaybackFinished(trackID: trackID, startedAt: startedAt,
                                     endedAt: startedAt.addingTimeInterval(30), listenedSeconds: 30,
                                     duration: 100, context: context, isFullPlayback: false, isSkipped: true)

        let event = try XCTUnwrap(store.entries[trackID]?.playbackEvents.single)
        XCTAssertEqual(event.listenedSeconds, 30)
        XCTAssertEqual(event.completionRatio, 0.3, accuracy: 0.0001)
        XCTAssertTrue(event.isEarlySkip)
        XCTAssertEqual(event.startKind, .automatic)
        XCTAssertEqual(event.startSource, .station)
        let summary = try XCTUnwrap(store.dailySummaries(for: trackID).values.first)
        XCTAssertEqual(summary.skipCount, 1)
        XCTAssertEqual(summary.earlySkipCount, 1)
        XCTAssertEqual(summary.fullPlaybackCount, 0)

        let fullStartedAt = startedAt.addingTimeInterval(120)
        store.recordPlaybackStarted(trackID: trackID, context: .manualUnknown,
                                    isRepeatModeActive: false, isConsecutivePlay: false, now: fullStartedAt)
        store.recordPlaybackFinished(trackID: trackID, startedAt: fullStartedAt,
                                     endedAt: fullStartedAt.addingTimeInterval(100), listenedSeconds: 100,
                                     duration: 100, context: .manualUnknown,
                                     isFullPlayback: true, isSkipped: false)
        XCTAssertEqual(store.dailySummaries(for: trackID).values.first?.fullPlaybackCount, 1)

        let thirtyOneSecondSkip = PlaybackEvent(
            trackID: trackID, startedAt: startedAt, endedAt: startedAt.addingTimeInterval(31),
            listenedSeconds: 31, completionRatio: 0.31, wasSkipped: true, wasFullPlayback: false,
            startKind: .manual, startSource: .search
        )
        XCTAssertFalse(thirtyOneSecondSkip.isEarlySkip)
        let fullPlayback = PlaybackEvent(
            trackID: trackID, startedAt: startedAt, endedAt: startedAt.addingTimeInterval(100),
            listenedSeconds: 100, completionRatio: 1, wasSkipped: true, wasFullPlayback: true,
            startKind: .manual, startSource: .library
        )
        XCTAssertFalse(fullPlayback.wasSkipped)
    }

    func testPlayerFinalizesOnlyOneEventForDuplicateEndedSignal() async throws {
        let track = makeTrack("Only")
        let historyStore = PlaybackHistoryStore(persistence: PlaybackHistoryBehaviorPersistence())
        let player = PlaybackHistoryAudioPlayerSpy()
        let store = PlayerStore(audioPlayer: player, playbackHistoryStore: historyStore,
                                nowPlayingService: PlaybackHistoryNowPlayingSpy(),
                                remoteCommandService: PlaybackHistoryRemoteCommandSpy(),
                                trackPlaybackAdjustmentStore: TrackPlaybackAdjustmentStore(
                                    persistence: PlaybackHistoryAdjustmentPersistence()))
        await historyStore.loadIfNeeded()
        store.playQueue([track], startingAt: 0)
        try await waitUntil { historyStore.manualPlayCount(for: track.id) == 1 }
        player.send(.ended)
        player.send(.ended)
        XCTAssertEqual(historyStore.entries[track.id]?.playbackEvents.count, 1)
    }

    func testNextButtonMarksDestinationAsUserAdvancedRatherThanDirectSelection() async throws {
        let first = makeTrack("First")
        let second = makeTrack("Second")
        let historyStore = PlaybackHistoryStore(persistence: PlaybackHistoryBehaviorPersistence())
        let store = PlayerStore(
            audioPlayer: PlaybackHistoryAudioPlayerSpy(),
            playbackHistoryStore: historyStore,
            nowPlayingService: PlaybackHistoryNowPlayingSpy(),
            remoteCommandService: PlaybackHistoryRemoteCommandSpy(),
            trackPlaybackAdjustmentStore: TrackPlaybackAdjustmentStore(
                persistence: PlaybackHistoryAdjustmentPersistence()
            )
        )
        await historyStore.loadIfNeeded()

        store.playQueue([first, second], startingAt: 0)
        try await waitUntil { historyStore.manualPlayCount(for: first.id) == 1 }
        store.next()
        try await waitUntil { historyStore.manualPlayCount(for: second.id) == 1 }
        store.previous()
        try await waitUntil { historyStore.entries[second.id]?.playbackEvents.count == 1 }

        XCTAssertEqual(historyStore.entries[second.id]?.playbackEvents.first?.startKind, .userAdvanced)
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

private extension Array {
    var single: Element? { count == 1 ? first : nil }
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
