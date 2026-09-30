import Foundation
import XCTest
@testable import MyMusic

@MainActor
final class WatchSessionManagerTests: XCTestCase {
    func testLiveStateRecoversControlsAfterCommunicationError() {
        var reachable = false
        let manager = WatchSessionManager(session: nil, reachabilityProvider: { reachable })
        manager.send(.requestState)
        XCTAssertFalse(manager.isPhoneReachable)
        XCTAssertNotNil(manager.errorMessage)

        reachable = true
        manager.apply(state().message)
        XCTAssertTrue(manager.isPhoneReachable)
        XCTAssertNil(manager.errorMessage)
    }

    func testCachedStateDoesNotClaimOfflinePhoneIsReachable() {
        let manager = WatchSessionManager(session: nil, reachabilityProvider: { false })
        let cached = state()
        manager.apply(cached.message)
        XCTAssertEqual(manager.playbackState, cached)
        XCTAssertFalse(manager.isPhoneReachable)
    }

    func testMalformedMessageDoesNotClearCommunicationError() {
        let manager = WatchSessionManager(session: nil, reachabilityProvider: { true })
        manager.send(.requestState)
        manager.apply(["kind": "playbackState"])
        XCTAssertNotNil(manager.errorMessage)
        XCTAssertFalse(manager.isPhoneReachable)
    }

    func testArtworkIsCapturedBeforeTemporaryFileDisappears() async throws {
        let manager = WatchSessionManager(session: nil)
        let current = state()
        manager.apply(current.message)
        let data = try XCTUnwrap(Data(base64Encoded:
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1kAAAAASUVORK5CYII="))
        let url = FileManager.default.temporaryDirectory.appending(path: "watch-artwork-\(UUID()).png")
        try data.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        manager.receiveArtworkFile(at: url, trackID: try XCTUnwrap(current.trackID), identifier: "current")
        // Emulate WCSession deleting its temporary file as soon as the callback returns.
        try FileManager.default.removeItem(at: url)
        for _ in 0..<100 where manager.artworkData == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        XCTAssertEqual(manager.artworkData, data)
    }

    func testOldArtworkIsRejectedAfterIdentifierChangesForSameTrack() throws {
        let manager = WatchSessionManager(session: nil)
        var current = state()
        manager.apply(current.message)
        current.artworkIdentifier = "replacement"
        manager.apply(current.message)
        manager.applyArtwork(Data(), trackID: try XCTUnwrap(current.trackID), identifier: "current")
        XCTAssertNil(manager.artworkData)
    }

    private func state() -> WatchPlaybackState {
        WatchPlaybackState(trackID: UUID(), title: "Track", artist: "Artist",
                           isPlaying: true, currentTime: 10, duration: 120,
                           hasArtwork: true, artworkIdentifier: "current")
    }
}
