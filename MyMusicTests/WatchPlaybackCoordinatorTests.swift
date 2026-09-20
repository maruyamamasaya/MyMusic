import XCTest
@testable import MyMusic

@MainActor
final class WatchPlaybackCoordinatorTests: XCTestCase {
    func testRoutesPlaybackCommandsAndPublishesCurrentState() async {
        let service = WatchConnectivitySpy()
        let preferences = TrackPreferenceStore()
        let library = LibraryStore()
        var commands: [WatchPlaybackCommand] = []
        var shuffles: [WatchShuffleKind] = []
        let coordinator = WatchPlaybackCoordinator(
            service: service,
            preferenceStore: preferences,
            libraryStore: library,
            playbackCommand: { commands.append($0) },
            shuffleCommand: { kind, tracks, _ in
                shuffles.append(kind)
                XCTAssertTrue(tracks.isEmpty)
                return "対象の曲がありません"
            }
        )
        let track = Track(
            id: UUID(), title: "Title", artistName: "Artist", albumTitle: "Album",
            duration: 120, fileURL: URL(fileURLWithPath: "/tmp/watch-test.wav"),
            artworkIdentifier: "artwork"
        )

        XCTAssertTrue(service.activated)
        coordinator.updateState(track: track, isPlaying: true, currentTime: 12, duration: 120)
        XCTAssertEqual(service.publishedState, service.stateProvider?())
        XCTAssertEqual(service.publishedState?.trackID, track.id)
        XCTAssertEqual(service.publishedState?.currentTime, 12)
        XCTAssertEqual(service.publishedArtworkIdentifier, "artwork")

        for command in [WatchPlaybackCommand.play, .pause, .togglePlayPause, .next, .previous] {
            service.commandHandler?(command)
        }
        XCTAssertEqual(commands, [.play, .pause, .togglePlayPause, .next, .previous])
        let shuffleError = await service.shuffleHandler?(.favorites)
        XCTAssertEqual(shuffles, [.favorites])
        XCTAssertEqual(shuffleError, "対象の曲がありません")

        coordinator.updateState(track: nil, isPlaying: false, currentTime: 0, duration: 0)
        XCTAssertNil(service.stateProvider?().trackID)
        XCTAssertNil(service.publishedArtworkIdentifier)
    }
}

@MainActor
private final class WatchConnectivitySpy: WatchConnectivityServicing {
    var commandHandler: ((WatchPlaybackCommand) -> Void)?
    var shuffleHandler: ((WatchShuffleKind) async -> String?)?
    var stateProvider: (() -> WatchPlaybackState)?
    var activated = false
    var publishedState: WatchPlaybackState?
    var publishedArtworkIdentifier: String?

    func activate() { activated = true }

    func publish(_ state: WatchPlaybackState, artworkIdentifier: String?) {
        publishedState = state
        publishedArtworkIdentifier = artworkIdentifier
    }
}
