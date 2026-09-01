import Foundation
import XCTest
@testable import MyMusic

final class LibraryCleanupCandidateServiceTests: XCTestCase {
    private let service = LibraryCleanupCandidateService()

    func testTwoEarlySkipsAreNotCandidateAndThreeAreCandidate() {
        let two = makeTrack("Two")
        let three = makeTrack("Three")
        let result = service.candidates(
            tracks: [two, three],
            historyByTrackID: [two.id: history(two, earlySkips: 2), three.id: history(three, earlySkips: 3)]
        )
        XCTAssertEqual(result.map(\.id), [three.id])
    }

    func testManualPlayIsRequiredAndUnplayedTracksAreExcluded() {
        let automaticOnly = makeTrack("Automatic")
        let missingHistory = makeTrack("Unplayed")
        let result = service.candidates(
            tracks: [automaticOnly, missingHistory],
            historyByTrackID: [automaticOnly.id: history(automaticOnly, earlySkips: 3, manualPlays: 0)]
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testPreferenceDoesNotAffectEligibilityIncludingAlreadyBadTrack() {
        let tracks = [makeTrack("Neutral"), makeTrack("Bad"), makeTrack("Good")]
        let preferences = [0, -3, 2]
        let histories = Dictionary(uniqueKeysWithValues: zip(tracks, preferences).map {
            ($0.0.id, history($0.0, earlySkips: 3, preference: $0.1))
        })
        let result = service.candidates(tracks: tracks, historyByTrackID: histories)
        XCTAssertEqual(Set(result.map(\.playbackPreference)), Set(preferences))
        XCTAssertEqual(Set(result.map(\.id)), Set(tracks.map(\.id)))
    }

    func testCandidatesSortByEarlySkipsThenMostRecentPlayback() {
        let older = makeTrack("Older")
        let newer = makeTrack("Newer")
        let mostSkipped = makeTrack("Most")
        let result = service.candidates(tracks: [older, mostSkipped, newer], historyByTrackID: [
            older.id: history(older, earlySkips: 3, lastPlayedAt: Date(timeIntervalSince1970: 100)),
            newer.id: history(newer, earlySkips: 3, lastPlayedAt: Date(timeIntervalSince1970: 200)),
            mostSkipped.id: history(mostSkipped, earlySkips: 5, lastPlayedAt: Date(timeIntervalSince1970: 50))
        ])
        XCTAssertEqual(result.map(\.id), [mostSkipped.id, newer.id, older.id])
    }

    func testAnalysisDoesNotMutatePreferenceBoredomHideOrEarlySkips() {
        let track = makeTrack("Unchanged")
        let original = history(track, earlySkips: 4, preference: -3, boredom: 2, permanentlyHidden: true)
        let histories = [track.id: original]

        _ = service.candidates(tracks: [track], historyByTrackID: histories)

        XCTAssertEqual(histories[track.id]?.playbackPreference, -3)
        XCTAssertEqual(histories[track.id]?.boredomCount, 2)
        XCTAssertEqual(histories[track.id]?.isPermanentlyHiddenFromShuffle, true)
        XCTAssertEqual(histories[track.id]?.dailySummaries.values.reduce(0) { $0 + $1.earlySkipCount }, 4)
    }

    func testPreferenceChangeDoesNotChangeEarlySkipCountOrRemoveCandidate() {
        let track = makeTrack("Rated")
        var updated = history(track, earlySkips: 3, preference: 0)
        let before = service.candidates(tracks: [track], historyByTrackID: [track.id: updated])
        updated.playbackPreference = -1
        let after = service.candidates(tracks: [track], historyByTrackID: [track.id: updated])

        XCTAssertEqual(before.first?.earlySkipCount, 3)
        XCTAssertEqual(after.first?.earlySkipCount, 3)
        XCTAssertEqual(after.first?.playbackPreference, -1)
    }

    private func makeTrack(_ title: String) -> Track {
        Track(id: UUID(), title: title, artistName: "Artist", albumTitle: "Album", duration: 180,
              fileURL: URL(fileURLWithPath: "/tmp/\(title).m4a"))
    }

    private func history(
        _ track: Track, earlySkips: Int, manualPlays: Int = 1, preference: Int = 0,
        lastPlayedAt: Date = Date(timeIntervalSince1970: 100), boredom: Int = 0,
        permanentlyHidden: Bool = false
    ) -> PlaybackHistory {
        PlaybackHistory(
            trackID: track.id, isFavorite: false, playCount: 1, lastPlayedAt: lastPlayedAt,
            playbackPreference: preference,
            dailySummaries: ["2026-09-01": PlaybackDailySummary(earlySkipCount: earlySkips)],
            manualPlayCount: manualPlays, skipCount: earlySkips, boredomCount: boredom,
            isPermanentlyHiddenFromShuffle: permanentlyHidden
        )
    }
}
