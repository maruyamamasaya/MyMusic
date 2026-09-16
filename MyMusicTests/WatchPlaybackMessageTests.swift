import XCTest
@testable import MyMusic

final class WatchPlaybackMessageTests: XCTestCase {
    func testPlaybackStateRoundTrip() throws {
        let expected = WatchPlaybackState(
            trackID: UUID(), title: "Title", artist: "Artist", album: "Album",
            isPlaying: true, currentTime: 12, duration: 120,
            isFavorite: true, playbackPreference: -4, hasArtwork: true,
            artworkIdentifier: "artwork-v2"
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

    func testShuffleCommandsRoundTripAndRejectUnknownValues() throws {
        for kind in WatchShuffleKind.allCases {
            let data = try PropertyListSerialization.data(fromPropertyList: kind.message, format: .binary, options: 0)
            let message = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
            XCTAssertEqual(WatchShuffleKind(message: message), kind)
            XCTAssertNil(WatchPlaybackState.command(from: message))
        }
        XCTAssertNil(WatchShuffleKind(message: ["kind": "shuffle", "version": 1, "shuffle": "unknown"]))
        XCTAssertNil(WatchShuffleKind(message: ["kind": "shuffle", "version": 2, "shuffle": "normal"]))
        XCTAssertNil(WatchShuffleKind(message: WatchPlaybackState.commandMessage(.play)))
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
        XCTAssertNil(state.artworkIdentifier)
    }

    func testArtworkMetadataRoundTrip() {
        let trackID = UUID()
        XCTAssertEqual(
            WatchArtworkFileMetadata.trackID(from: WatchArtworkFileMetadata.message(trackID: trackID, identifier: "artwork-v2")),
            trackID
        )
        XCTAssertEqual(
            WatchArtworkFileMetadata.identifier(from: WatchArtworkFileMetadata.message(trackID: trackID, identifier: "artwork-v2")),
            "artwork-v2"
        )
    }
}
