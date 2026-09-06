import XCTest
@testable import MyMusic

final class WatchPlaybackMessageTests: XCTestCase {
    func testPlaybackStateRoundTrip() throws {
        let expected = WatchPlaybackState(
            trackID: UUID(), title: "Title", artist: "Artist",
            isPlaying: true, currentTime: 12, duration: 120
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
}
