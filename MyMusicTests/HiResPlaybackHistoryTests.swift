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

    func play(url: URL) async throws {}
    func prepare(sampleRate: Double) async throws {}
    func stop() {}
    func send(_ event: HiResAudioQueueProbeEvent) { eventHandler?(event) }
}

private actor HiResHistoryPersistence: PlaybackHistoryPersistenceServicing {
    private var entries: [PlaybackHistory] = []

    func load() async throws -> [PlaybackHistory] { entries }
    func save(_ history: [PlaybackHistory]) async throws { entries = history }
}
