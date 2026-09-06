import XCTest
@testable import MyMusic

final class WatchPlaybackMessageTests: XCTestCase {
    func testPlaybackStateRoundTrip() throws {
        let expected = WatchPlaybackState(
            trackID: UUID(), title: "Title", artist: "Artist", album: "Album",
            isPlaying: true, currentTime: 12, duration: 120,
            isFavorite: true, playbackPreference: -4, hasArtwork: true
        )
        XCTAssertEqual(WatchPlaybackState(message: expected.message), expected)
    }

    func testAllCommandsRoundTrip() {
        for command in WatchPlaybackCommand.allCases {
            XCTAssertEqual(
                WatchPlaybackState.command(from: WatchPlaybackState.commandMessage(command)),
                command
            )
        }
    }

    func testMalformedStateIsRejected() {
        XCTAssertNil(WatchPlaybackState(message: ["kind": "playbackState", "version": 1]))
    }

    func testVersionOneStateWithoutNewFieldsUsesBackwardCompatibleDefaults() throws {
        let message: [String: Any] = [
            "kind": "playbackState", "version": 1, "trackID": UUID().uuidString,
            "title": "Title", "artist": "Artist", "isPlaying": false,
            "currentTime": 0.0, "duration": 30.0
        ]
        let state = try XCTUnwrap(WatchPlaybackState(message: message))
        XCTAssertFalse(state.isFavorite)
        XCTAssertEqual(state.album, "")
        XCTAssertEqual(state.playbackPreference, 0)
        XCTAssertFalse(state.hasArtwork)
    }

    func testArtworkMetadataRoundTrip() {
        let trackID = UUID()
        XCTAssertEqual(
            WatchArtworkFileMetadata.trackID(from: WatchArtworkFileMetadata.message(trackID: trackID)),
            trackID
        )
    }
}
