import Foundation
import XCTest
@testable import MyMusic

final class LibraryCleanupCandidateServiceTests: XCTestCase {
    private let service = LibraryCleanupCandidateService()

    func testNoEventsAndFewerThanFiveClassifiedEventsAreExcluded() {
        let none = makeTrack("None")
        let four = makeTrack("Four")
        let histories = [
            none.id: PlaybackHistory(trackID: none.id, isFavorite: false, playCount: 0, lastPlayedAt: nil),
            four.id: history(four, events: makeEvents(track: four, count: 4, skipped: 4, ratio: 0.05))
        ]
        XCTAssertTrue(service.candidates(tracks: [none, four], historyByTrackID: histories).isEmpty)
    }

    func testZeroQualifiedPlayCountCanStillBeCandidateFromPlaybackEvents() throws {
        let track = makeTrack("Zero Count")
        let events = makeEvents(track: track, count: 5, skipped: 3, ratio: 0.08)
        let result = try XCTUnwrap(service.candidates(
            tracks: [track], historyByTrackID: [track.id: history(track, playCount: 0, events: events)]
        ).first)
        XCTAssertEqual(result.evaluatedEventCount, 5)
        XCTAssertEqual(result.userSkipCount, 3)
        XCTAssertEqual(result.userSkipRate, 0.6, accuracy: 0.0001)
        XCTAssertEqual(result.averagePlaybackRatio, 0.08, accuracy: 0.0001)
    }

    func testFiftyPercentSkipAndTenPercentAverageAreInclusive() {
        let track = makeTrack("Boundary")
        let events = makeEvents(track: track, count: 10, skipped: 5, ratio: 0.10)
        XCTAssertEqual(service.candidates(
            tracks: [track], historyByTrackID: [track.id: history(track, events: events)]
        ).map(\.id), [track.id])
    }

    func testBothUnhealthyConditionsAreRequired() {
        let lowSkip = makeTrack("Low Skip")
        let wellListened = makeTrack("Well Listened")
        let histories = [
            lowSkip.id: history(lowSkip, events: makeEvents(track: lowSkip, count: 10, skipped: 4, ratio: 0.05)),
            wellListened.id: history(wellListened, events: makeEvents(track: wellListened, count: 10, skipped: 9, ratio: 0.11))
        ]
        XCTAssertTrue(service.candidates(tracks: [lowSkip, wellListened], historyByTrackID: histories).isEmpty)
    }

    func testOnlyLatestTwentyClassifiedEventsAreEvaluated() throws {
        let track = makeTrack("Recent Window")
        let oldHealthy = makeEvents(track: track, count: 10, skipped: 0, ratio: 1, startingAt: 100)
        let recentPoor = makeEvents(track: track, count: 20, skipped: 10, ratio: 0.05, startingAt: 1_000)
        let candidate = try XCTUnwrap(service.candidates(
            tracks: [track], historyByTrackID: [track.id: history(track, events: oldHealthy + recentPoor)]
        ).first)
        XCTAssertEqual(candidate.evaluatedEventCount, 20)
        XCTAssertEqual(candidate.userSkipCount, 10)
        XCTAssertEqual(candidate.averagePlaybackRatio, 0.05, accuracy: 0.0001)
    }

    func testLegacyEventsWithoutEndKindAreExcluded() {
        let track = makeTrack("Legacy")
        let legacy = makeEvents(track: track, count: 10, skipped: 10, ratio: 0.01, endKindKnown: false)
        XCTAssertTrue(service.candidates(
            tracks: [track], historyByTrackID: [track.id: history(track, events: legacy)]
        ).isEmpty)
    }

    func testWorkSizedTracksAreExcluded() {
        let track = makeTrack("Work", duration: Track.longFormMinimumDuration)
        let events = makeEvents(track: track, count: 10, skipped: 10, ratio: 0.01)
        XCTAssertTrue(service.candidates(
            tracks: [track], historyByTrackID: [track.id: history(track, events: events)]
        ).isEmpty)
    }

    private func makeTrack(_ title: String, duration: TimeInterval = 180) -> Track {
        Track(id: UUID(), title: title, artistName: "Artist", albumTitle: "Album", duration: duration,
              fileURL: URL(fileURLWithPath: "/tmp/\(title).m4a"))
    }

    private func history(_ track: Track, playCount: Int = 1, events: [PlaybackEvent]) -> PlaybackHistory {
        PlaybackHistory(
            trackID: track.id, isFavorite: false, playCount: playCount,
            lastPlayedAt: events.map(\.endedAt).max(), playbackEvents: events
        )
    }

    private func makeEvents(
        track: Track,
        count: Int,
        skipped: Int,
        ratio: Double,
        startingAt: TimeInterval = 100,
        endKindKnown: Bool = true
    ) -> [PlaybackEvent] {
        (0..<count).map { index in
            let start = Date(timeIntervalSince1970: startingAt + Double(index * 10))
            let isSkipped = index < skipped
            return PlaybackEvent(
                trackID: track.id, startedAt: start,
                endedAt: start.addingTimeInterval(track.duration * ratio),
                listenedSeconds: track.duration * ratio, completionRatio: ratio,
                wasSkipped: isSkipped, wasFullPlayback: false,
                startKind: .automatic, startSource: .shuffle,
                endKind: endKindKnown ? (isSkipped ? .userSkipped : .other) : nil
            )
        }
    }
}
