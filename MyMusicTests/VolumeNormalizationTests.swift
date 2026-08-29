import XCTest
@testable import MyMusic

final class VolumeNormalizationGainTests: XCTestCase {
    func testDecibelsConvertToLinearGainAndInvalidDataFallsBackToUnity() {
        XCTAssertEqual(VolumeNormalizationGain.linear(fromDecibels: 0), 1, accuracy: 0.000_001)
        XCTAssertEqual(VolumeNormalizationGain.linear(fromDecibels: 4), 1.584_893, accuracy: 0.000_001)
        XCTAssertEqual(VolumeNormalizationGain.linear(fromDecibels: -4), 0.630_957, accuracy: 0.000_001)
        XCTAssertEqual(VolumeNormalizationGain.linear(fromDecibels: nil), 1, accuracy: 0.000_001)
        XCTAssertEqual(VolumeNormalizationGain.linear(fromDecibels: .nan), 1, accuracy: 0.000_001)
    }
}

@MainActor
final class VolumeNormalizationSettingsTests: XCTestCase {
    func testDefaultsToOffPersistsAndAppliesToController() {
        let suiteName = "VolumeNormalizationSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let controller = NormalizationControllerSpy()

        let first = SettingsStore(volumeNormalizationController: controller, defaults: defaults)
        XCTAssertFalse(first.volumeNormalizationEnabled)
        XCTAssertEqual(controller.enabledValues, [false])

        first.setVolumeNormalizationEnabled(true)
        XCTAssertTrue(defaults.bool(forKey: "volumeNormalizationEnabled"))

        let reloadedController = NormalizationControllerSpy()
        let reloaded = SettingsStore(volumeNormalizationController: reloadedController, defaults: defaults)
        XCTAssertTrue(reloaded.volumeNormalizationEnabled)
        XCTAssertEqual(reloadedController.enabledValues, [true])
    }
}

@MainActor
final class VolumeNormalizationPlaybackTests: XCTestCase {
    func testTrackChangesPrepareTheMatchedFixedGainAndMissingDataUsesZeroDB() {
        let first = makeTrack(title: "Quiet")
        let second = makeTrack(title: "Unanalyzed")
        let player = NormalizationAudioPlayerSpy()
        let gains: [Track.ID: Double] = [first.id: 3.25]
        let store = PlayerStore(
            audioPlayer: player,
            nowPlayingService: NormalizationNowPlayingSpy(),
            remoteCommandService: NormalizationRemoteCommandSpy(),
            normalizationGainProvider: { gains[$0] }
        )

        store.playQueue([first, second], startingAt: 0)
        store.playQueueItem(at: 1)

        XCTAssertEqual(player.preparedGains, [3.25, 0])
    }

    private func makeTrack(title: String) -> Track {
        Track(
            id: UUID(), title: title, artistName: "Artist", albumTitle: "Album", duration: 120,
            fileURL: URL(fileURLWithPath: "/tmp/\(title).wav"), relativePath: "\(title).wav", fileSize: 100
        )
    }
}

@MainActor
private final class NormalizationControllerSpy: VolumeNormalizationControlling {
    var enabledValues: [Bool] = []
    func setVolumeNormalizationEnabled(_ isEnabled: Bool) { enabledValues.append(isEnabled) }
    func prepareVolumeNormalizationGain(decibels: Double?) {}
}

@MainActor
private final class NormalizationAudioPlayerSpy: AudioPlayerServicing, VolumeNormalizationControlling {
    var eventHandler: ((AudioPlaybackEvent) -> Void)?
    var preparedGains: [Double] = []

    func setVolumeNormalizationEnabled(_ isEnabled: Bool) {}
    func prepareVolumeNormalizationGain(decibels: Double?) { preparedGains.append(decibels ?? 0) }
    func play(_ track: Track) async throws {}
    func pause() {}
    func resume() async throws {}
    func seek(to time: TimeInterval) {}
    func stop() {}
}

@MainActor
private final class NormalizationNowPlayingSpy: NowPlayingServicing {
    func setTrack(_ track: Track, duration: TimeInterval, elapsedTime: TimeInterval, isPlaying: Bool) {}
    func updateDuration(_ duration: TimeInterval, elapsedTime: TimeInterval, isPlaying: Bool) {}
    func updatePlayback(elapsedTime: TimeInterval, isPlaying: Bool) {}
    func clear() {}
}

@MainActor
private final class NormalizationRemoteCommandSpy: RemoteCommandServicing {
    func configure(actions: RemoteCommandActions) {}
    func updateAvailability(hasTrack: Bool, canGoNext: Bool, canGoPrevious: Bool) {}
}
