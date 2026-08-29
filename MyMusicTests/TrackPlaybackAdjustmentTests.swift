import XCTest
@testable import MyMusic

final class TrackPlaybackAdjustmentModelTests: XCTestCase {
    func testSanitizationRejectsInvalidBoundariesAndClampsManualAdjustment() {
        let trackID = UUID()
        let invalidOrder = TrackPlaybackAdjustment(
            trackID: trackID,
            lastPlaybackPosition: -5,
            customStartPosition: 80,
            customEndPosition: 40,
            manualNormalizationAdjustmentDB: 9
        ).sanitized(for: 60)

        XCTAssertEqual(invalidOrder.lastPlaybackPosition, 0)
        XCTAssertNil(invalidOrder.customStartPosition)
        XCTAssertEqual(invalidOrder.customEndPosition, 40)
        XCTAssertEqual(invalidOrder.manualNormalizationAdjustmentDB, 2)

        let conflicting = TrackPlaybackAdjustment(
            trackID: trackID,
            customStartPosition: 40,
            customEndPosition: 20
        ).sanitized(for: 60)
        XCTAssertNil(conflicting.customStartPosition)
        XCTAssertNil(conflicting.customEndPosition)
    }

    func testLegacyMissingFieldsDecodeWithSafeDefaults() throws {
        let trackID = UUID()
        let data = Data("{\"trackID\":\"\(trackID.uuidString)\"}".utf8)
        let decoded = try JSONDecoder().decode(TrackPlaybackAdjustment.self, from: data)

        XCTAssertEqual(decoded.lastPlaybackPosition, 0)
        XCTAssertNil(decoded.customStartPosition)
        XCTAssertNil(decoded.customEndPosition)
        XCTAssertEqual(decoded.manualNormalizationAdjustmentDB, 0)
    }
}

final class TrackPlaybackAdjustmentPersistenceTests: XCTestCase {
    func testPerTrackFileRoundTripPersistsAllValues() async throws {
        let root = FileManager.default.temporaryDirectory
            .appending(path: "TrackPlaybackAdjustmentTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let service = TrackPlaybackAdjustmentPersistenceService(rootURL: root)
        let value = TrackPlaybackAdjustment(
            trackID: UUID(),
            lastPlaybackPosition: 92,
            customStartPosition: 8,
            customEndPosition: 251,
            manualNormalizationAdjustmentDB: -0.5,
            updatedAt: Date(timeIntervalSince1970: 1_800_000_000)
        )

        try await service.save(value)
        let loaded = try await service.load(trackID: value.trackID)

        XCTAssertEqual(loaded, value)
    }
}

@MainActor
final class TrackPlaybackAdjustmentStoreTests: XCTestCase {
    func testStartEndValidationAndManualStepArePersisted() async {
        let trackID = UUID()
        let persistence = AdjustmentMemoryPersistence()
        let store = TrackPlaybackAdjustmentStore(persistence: persistence)

        let acceptedStart = await store.setCustomStart(trackID: trackID, position: 8, duration: 100)
        let rejectedEnd = await store.setCustomEnd(trackID: trackID, position: 7, duration: 100)
        let acceptedEnd = await store.setCustomEnd(trackID: trackID, position: 90, duration: 100)
        XCTAssertTrue(acceptedStart)
        XCTAssertFalse(rejectedEnd)
        XCTAssertTrue(acceptedEnd)
        await store.setManualNormalizationAdjustment(trackID: trackID, decibels: 2.4, duration: 100)

        let reloadedStore = TrackPlaybackAdjustmentStore(persistence: persistence)
        let reloaded = await reloadedStore.load(for: trackID, duration: 100)
        XCTAssertEqual(reloaded.customStartPosition, 8)
        XCTAssertEqual(reloaded.customEndPosition, 90)
        XCTAssertEqual(reloaded.manualNormalizationAdjustmentDB, 2)
    }
}

@MainActor
final class TrackPlaybackAdjustmentPlaybackTests: XCTestCase {
    func testCustomStartGainAndEndUseExistingNextTrackFlow() async throws {
        let first = makeTrack("First")
        let second = makeTrack("Second")
        let persistence = AdjustmentMemoryPersistence(values: [
            first.id: TrackPlaybackAdjustment(
                trackID: first.id,
                customStartPosition: 8,
                customEndPosition: 20,
                manualNormalizationAdjustmentDB: 0.5
            )
        ])
        let adjustments = TrackPlaybackAdjustmentStore(persistence: persistence)
        let player = AdjustmentAudioPlayerSpy()
        let store = PlayerStore(
            audioPlayer: player,
            nowPlayingService: AdjustmentNowPlayingSpy(),
            remoteCommandService: AdjustmentRemoteCommandSpy(),
            trackPlaybackAdjustmentStore: adjustments,
            normalizationMetadataProvider: { trackID in
                trackID == first.id
                    ? TrackNormalizationMetadata(automaticGainDB: 3, truePeakDBTP: -5)
                    : nil
            }
        )

        store.playQueue([first, second], startingAt: 0)
        try await waitUntil { player.playRequests.count == 1 }
        XCTAssertEqual(player.playRequests[0].start, 8)
        XCTAssertEqual(player.preparedGains, [3.5])
        XCTAssertTrue(player.fadeOutRequests.contains { $0.end == 20 && $0.reason == .automaticTrackChange })

        player.send(.timeChanged(20))
        try await waitUntil { store.currentTrack?.id == second.id && player.playRequests.count == 2 }
        XCTAssertEqual(store.currentTrack?.id, second.id)
    }

    func testLifecycleFlushSavesCurrentPosition() async throws {
        let track = makeTrack("Position")
        let persistence = AdjustmentMemoryPersistence()
        let adjustments = TrackPlaybackAdjustmentStore(persistence: persistence)
        let player = AdjustmentAudioPlayerSpy()
        let store = PlayerStore(
            audioPlayer: player,
            nowPlayingService: AdjustmentNowPlayingSpy(),
            remoteCommandService: AdjustmentRemoteCommandSpy(),
            trackPlaybackAdjustmentStore: adjustments
        )

        store.play(track)
        try await waitUntil { player.playRequests.count == 1 }
        player.send(.timeChanged(12))
        store.persistPlaybackPositionForLifecycle()
        try await waitUntil { await persistence.value(for: track.id)?.lastPlaybackPosition == 12 }
    }

    private func makeTrack(_ title: String) -> Track {
        Track(
            id: UUID(), title: title, artistName: "Artist", duration: 120,
            fileURL: URL(fileURLWithPath: "/tmp/\(title).wav"), relativePath: "\(title).wav"
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

final class ArtworkDisplayStateTests: XCTestCase {
    func testArtworkPanelsCycleThroughAllThreeStates() {
        XCTAssertEqual(ArtworkDisplayState.artwork.next, .audioInformation)
        XCTAssertEqual(ArtworkDisplayState.audioInformation.next, .trackAdjustments)
        XCTAssertEqual(ArtworkDisplayState.trackAdjustments.next, .artwork)
    }
}

private actor AdjustmentMemoryPersistence: TrackPlaybackAdjustmentPersistenceServicing {
    private var values: [Track.ID: TrackPlaybackAdjustment]

    init(values: [Track.ID: TrackPlaybackAdjustment] = [:]) {
        self.values = values
    }

    func load(trackID: Track.ID) async throws -> TrackPlaybackAdjustment? { values[trackID] }
    func save(_ adjustment: TrackPlaybackAdjustment) async throws { values[adjustment.trackID] = adjustment }
    func value(for trackID: Track.ID) -> TrackPlaybackAdjustment? { values[trackID] }
}

@MainActor
private final class AdjustmentAudioPlayerSpy: AudioPlayerServicing, PlaybackTransitionAudioControlling,
    VolumeNormalizationControlling {
    struct PlayRequest {
        let trackID: Track.ID
        let start: TimeInterval
        let end: TimeInterval?
    }

    var eventHandler: ((AudioPlaybackEvent) -> Void)?
    var playRequests: [PlayRequest] = []
    var fadeOutRequests: [(end: TimeInterval, reason: PlaybackTransitionReason)] = []
    var preparedGains: [Double] = []

    func play(_ track: Track) async throws { playRequests.append(.init(trackID: track.id, start: 0, end: nil)) }
    func play(_ track: Track, transition: PlaybackTransitionReason) async throws {
        try await play(track, startingAt: 0, endingAt: nil, transition: transition)
    }
    func play(
        _ track: Track,
        startingAt playbackTime: TimeInterval,
        endingAt playbackEndTime: TimeInterval?,
        transition: PlaybackTransitionReason
    ) async throws {
        playRequests.append(.init(trackID: track.id, start: playbackTime, end: playbackEndTime))
        eventHandler?(.ready(duration: track.duration))
        eventHandler?(.playingChanged(true))
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
    func scheduleFadeOut(endingAt playbackTime: TimeInterval, reason: PlaybackTransitionReason) {
        fadeOutRequests.append((playbackTime, reason))
    }
    func stop() {}
    func setVolumeNormalizationEnabled(_ isEnabled: Bool) {}
    func prepareVolumeNormalizationGain(decibels: Double?) { preparedGains.append(decibels ?? 0) }
    func send(_ event: AudioPlaybackEvent) { eventHandler?(event) }
}

@MainActor
private final class AdjustmentNowPlayingSpy: NowPlayingServicing {
    func setTrack(_ track: Track, duration: TimeInterval, elapsedTime: TimeInterval, isPlaying: Bool) {}
    func updateDuration(_ duration: TimeInterval, elapsedTime: TimeInterval, isPlaying: Bool) {}
    func updatePlayback(elapsedTime: TimeInterval, isPlaying: Bool) {}
    func clear() {}
}

@MainActor
private final class AdjustmentRemoteCommandSpy: RemoteCommandServicing {
    func configure(actions: RemoteCommandActions) {}
    func updateAvailability(hasTrack: Bool, canGoNext: Bool, canGoPrevious: Bool) {}
}
