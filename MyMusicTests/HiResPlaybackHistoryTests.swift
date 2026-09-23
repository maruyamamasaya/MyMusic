import XCTest
@testable import MyMusic

@MainActor
final class HiResPlaybackHistoryTests: XCTestCase {
    func testManualStopRecordsHiResPlaybackForAnalytics() async {
        let service = HiResAudioQueueServiceSpy()
        let persistence = HiResHistoryPersistence()
        let history = PlaybackHistoryStore(persistence: persistence)
        await history.loadIfNeeded()
        var currentDate = Date(timeIntervalSince1970: 1_000)
        let store = HiResDirectOutputProbeStore(service: service, now: { currentDate })
        let track = makeTrack(duration: 120)

        store.play(track: track, historyStore: history)
        await Task.yield()
        service.send(.started(snapshot(for: track)))
        currentDate = currentDate.addingTimeInterval(40)
        store.stop()

        XCTAssertEqual(history.manualPlayCount(for: track.id), 1)
        XCTAssertEqual(history.playCount(for: track.id, source: .hiResLibrary), 1)
        XCTAssertEqual(history.playCount(for: track.id), 1)
        XCTAssertEqual(history.totalPlaybackDuration(for: track.id), 40, accuracy: 0.001)
        XCTAssertEqual(history.entries[track.id]?.playbackEvents.last?.endKind, .userSkipped)
        XCTAssertEqual(history.entries[track.id]?.playbackEvents.last?.listenedSeconds, 40)
    }

    func testNaturalEndRecordsFullPlaybackUsingTrackDuration() async {
        let service = HiResAudioQueueServiceSpy()
        let history = PlaybackHistoryStore(persistence: HiResHistoryPersistence())
        await history.loadIfNeeded()
        var currentDate = Date(timeIntervalSince1970: 2_000)
        let store = HiResDirectOutputProbeStore(service: service, now: { currentDate })
        let track = makeTrack(duration: 180)

        store.play(track: track, historyStore: history)
        await Task.yield()
        service.send(.started(snapshot(for: track)))
        currentDate = currentDate.addingTimeInterval(179)
        service.send(.reachedEnd)

        XCTAssertEqual(history.playCount(for: track.id), 1)
        XCTAssertEqual(history.totalPlaybackDuration(for: track.id), 180, accuracy: 0.001)
        XCTAssertEqual(history.entries[track.id]?.fullPlaybackCount, 1)
        XCTAssertEqual(history.entries[track.id]?.playbackEvents.last?.endKind, .natural)
        XCTAssertEqual(history.entries[track.id]?.playbackEvents.last?.startSource, .hiResLibrary)
    }

    func testPausedTimeIsExcludedFromPlaybackDuration() async {
        let service = HiResAudioQueueServiceSpy()
        let history = PlaybackHistoryStore(persistence: HiResHistoryPersistence())
        await history.loadIfNeeded()
        var currentDate = Date(timeIntervalSince1970: 3_000)
        let store = HiResDirectOutputProbeStore(service: service, now: { currentDate })
        let track = makeTrack(duration: 120)

        store.play(track: track, historyStore: history)
        await Task.yield()
        service.send(.started(snapshot(for: track)))
        currentDate = currentDate.addingTimeInterval(10)
        store.togglePlayPause()
        currentDate = currentDate.addingTimeInterval(100)
        store.togglePlayPause()
        currentDate = currentDate.addingTimeInterval(10)
        store.stop()

        XCTAssertEqual(service.pauseCount, 1)
        XCTAssertEqual(service.resumeCount, 1)
        XCTAssertEqual(history.totalPlaybackDuration(for: track.id), 20, accuracy: 0.001)
    }

    func testNextMovesThroughDedicatedQueue() async throws {
        let service = HiResAudioQueueServiceSpy()
        let history = PlaybackHistoryStore(persistence: HiResHistoryPersistence())
        await history.loadIfNeeded()
        let store = HiResDirectOutputProbeStore(service: service)
        let first = makeTrack(duration: 120)
        var second = makeTrack(duration: 180)
        second = Track(
            id: UUID(),
            title: "Second Hi-Res Track",
            artistName: second.artistName,
            duration: second.duration,
            fileURL: URL(fileURLWithPath: "/tmp/second-hires.m4a"),
            audioFormat: second.audioFormat
        )

        store.play(track: first, queue: [first, second], historyStore: history)
        await Task.yield()
        service.send(.started(snapshot(for: first)))
        store.next()
        try await waitUntil { service.playedURLs.last == second.fileURL }

        XCTAssertEqual(store.currentTrack?.id, second.id)
        XCTAssertEqual(store.currentIndex, 1)
        XCTAssertFalse(store.canGoNext)
        XCTAssertTrue(store.canGoPrevious)
        XCTAssertEqual(service.playedURLs.last, second.fileURL)
    }

    func testRepeatOneRestartsCurrentTrackAfterNaturalEnd() async throws {
        let service = HiResAudioQueueServiceSpy()
        let history = PlaybackHistoryStore(persistence: HiResHistoryPersistence())
        await history.loadIfNeeded()
        let store = HiResDirectOutputProbeStore(service: service)
        let track = makeTrack(duration: 120)

        store.play(track: track, historyStore: history)
        try await waitUntil { service.playedURLs.count == 1 }
        service.send(.started(snapshot(for: track)))
        store.cycleRepeatMode()
        store.cycleRepeatMode()
        service.send(.reachedEnd)
        try await waitUntil { service.playedURLs.count == 2 }

        XCTAssertEqual(store.repeatMode, .one)
        XCTAssertEqual(store.currentTrack?.id, track.id)
        XCTAssertEqual(service.playedURLs, [track.fileURL, track.fileURL])
    }

    func testRepeatAllWrapsToFirstTrack() async throws {
        let service = HiResAudioQueueServiceSpy()
        let history = PlaybackHistoryStore(persistence: HiResHistoryPersistence())
        await history.loadIfNeeded()
        let store = HiResDirectOutputProbeStore(service: service)
        let first = makeTrack(duration: 120)
        let second = Track(
            id: UUID(),
            title: "Second Hi-Res Track",
            artistName: "Artist",
            duration: 180,
            fileURL: URL(fileURLWithPath: "/tmp/second-hires.m4a"),
            audioFormat: first.audioFormat
        )

        store.play(track: second, queue: [first, second], historyStore: history)
        try await waitUntil { service.playedURLs.count == 1 }
        service.send(.started(snapshot(for: second)))
        store.cycleRepeatMode()
        service.send(.reachedEnd)
        try await waitUntil { service.playedURLs.count == 2 }

        XCTAssertEqual(store.repeatMode, .all)
        XCTAssertEqual(store.currentTrack?.id, first.id)
        XCTAssertEqual(service.playedURLs.last, first.fileURL)
    }

    func testShuffleKeepsInternalQueueAndCurrentTrack() async {
        let service = HiResAudioQueueServiceSpy()
        let history = PlaybackHistoryStore(persistence: HiResHistoryPersistence())
        await history.loadIfNeeded()
        let store = HiResDirectOutputProbeStore(service: service)
        let track = makeTrack(duration: 120)

        store.play(track: track, historyStore: history)
        store.toggleShuffle()

        XCTAssertTrue(store.isShuffleEnabled)
        XCTAssertEqual(store.queue.map(\.id), [track.id])
        XCTAssertEqual(store.currentTrack?.id, track.id)
    }

    private func waitUntil(_ condition: @escaping @MainActor () -> Bool) async throws {
        for _ in 0..<100 {
            if condition() { return }
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTFail("Timed out waiting for the Hi-Res playback request.")
    }

    private func makeTrack(duration: TimeInterval) -> Track {
        Track(
            id: UUID(),
            title: "Hi-Res Track",
            artistName: "Artist",
            duration: duration,
            fileURL: URL(fileURLWithPath: "/tmp/hires.m4a"),
            audioFormat: AudioFormat(
                codec: .alac,
                bitRate: nil,
                sampleRate: 192_000,
                bitDepth: 24,
                channels: 2
            )
        )
    }

    private func snapshot(for track: Track) -> HiResAudioQueueProbeSnapshot {
        HiResAudioQueueProbeSnapshot(
            fileName: track.fileURL.lastPathComponent,
            sourceSampleRate: 192_000,
            sessionSampleRate: 192_000,
            queueHardwareSampleRate: 192_000,
            outputName: "Tea Pro",
            outputPortType: "Headphones"
        )
    }
}

@MainActor
private final class HiResAudioQueueServiceSpy: HiResAudioQueueProbeServicing {
    var eventHandler: ((HiResAudioQueueProbeEvent) -> Void)?
    var playedURLs: [URL] = []
    var pauseCount = 0
    var resumeCount = 0
    var seekTimes: [TimeInterval] = []

    func play(url: URL) async throws { playedURLs.append(url) }
    func prepare(sampleRate: Double) async throws {}
    func pause() throws { pauseCount += 1 }
    func resume() throws { resumeCount += 1 }
    func seek(to time: TimeInterval) throws { seekTimes.append(time) }
    func stop() {}
    func send(_ event: HiResAudioQueueProbeEvent) { eventHandler?(event) }
}

private actor HiResHistoryPersistence: PlaybackHistoryPersistenceServicing {
    private var entries: [PlaybackHistory] = []

    func load() async throws -> [PlaybackHistory] { entries }
    func save(_ history: [PlaybackHistory]) async throws { entries = history }
}
