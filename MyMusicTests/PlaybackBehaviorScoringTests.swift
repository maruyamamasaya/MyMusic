import Foundation
import XCTest
@testable import MyMusic

final class PlaybackBehaviorScoringTests: XCTestCase {
    func testPreferenceWeightTable() {
        let expected = [
            0.01, 0.015, 0.02, 0.03, 0.05, 0.08, 0.12, 0.20, 0.35, 0.60,
            1.00, 1.8, 3.2, 5.5, 8.5, 12, 16, 21, 27, 34, 42
        ]
        XCTAssertEqual((-10...10).map { PlaybackPreferenceWeightPolicy.weight(for: $0) }, expected)
        XCTAssertGreaterThan(PlaybackPreferenceWeightPolicy.weight(for: -10), 0)
        XCTAssertEqual(PlaybackPreferenceWeightPolicy.weight(for: 0), 1)
        XCTAssertEqual(PlaybackPreferenceWeightPolicy.weight(for: 3), 5.5)
        XCTAssertEqual(PlaybackPreferenceWeightPolicy.weight(for: -3), 0.20)
    }

    func testOverplayIsLowWhenRecentVolumeMatchesBaseline() {
        XCTAssertLessThanOrEqual(OverplayScoring.score(recentPlayCount: 8, baselinePlayCount: 64).score, 0.2)
    }

    func testOverplayIsHighForRecentBurst() {
        XCTAssertGreaterThan(OverplayScoring.score(recentPlayCount: 12, baselinePlayCount: 0).score, 0.8)
    }

    func testTwoOrThreePlaysDoNotProduceStrongOverplay() {
        XCTAssertFalse(OverplayScoring.isCandidate(
            OverplayScoring.score(recentPlayCount: 2, baselinePlayCount: 0)
        ))
        XCTAssertFalse(OverplayScoring.isCandidate(
            OverplayScoring.score(recentPlayCount: 3, baselinePlayCount: 0)
        ))
    }

    func testBurstFallsWhenItMovesOutsideSevenDayWindow() throws {
        let track = makeTrack("Burst")
        let calendar = fixedCalendar
        let firstNow = try date(2026, 9, 7, calendar: calendar)
        let laterNow = try date(2026, 9, 15, calendar: calendar)
        let summaries = ["2026-09-01": PlaybackDailySummary(playCount: 12)]
        let history = PlaybackHistory(trackID: track.id, isFavorite: false, playCount: 12,
                                      lastPlayedAt: firstNow, dailySummaries: summaries)
        let analyzer = PlaybackBehaviorAnalyzer()
        let first = analyzer.analyze(tracks: [track], historyByTrackID: [track.id: history],
                                     now: firstNow, calendar: calendar).overplayResults[0].score.score
        let later = analyzer.analyze(tracks: [track], historyByTrackID: [track.id: history],
                                     now: laterNow, calendar: calendar).overplayResults[0].score.score
        XCTAssertGreaterThan(first, later)
    }

    func testOverplayScoreIsClamped() {
        for recent in [0, 1, 100_000] {
            let score = OverplayScoring.score(recentPlayCount: recent, baselinePlayCount: 0).score
            XCTAssertTrue((0...1).contains(score))
        }
    }

    func testGoodWithStrongHistoricalCompletionAndRecentSkipsIsCandidate() {
        let score = drift(preference: 3, recentFull: 0, recentSkip: 8, historicalFull: 16, historicalSkip: 0)
        XCTAssertGreaterThan(score.stableScore, 0.5)
        XCTAssertTrue(PreferenceDriftScoring.isCandidate(playbackPreference: 3, score: score))
    }

    func testTwoRecentSamplesAreNotCandidate() {
        let score = drift(preference: 3, recentFull: 0, recentSkip: 2, historicalFull: 16, historicalSkip: 0)
        XCTAssertFalse(PreferenceDriftScoring.isCandidate(playbackPreference: 3, score: score))
    }

    func testNeutralAndBadPreferencesAreNotCandidates() {
        for preference in [0, -3] {
            let score = drift(preference: preference, recentFull: 0, recentSkip: 8,
                              historicalFull: 16, historicalSkip: 0)
            XCTAssertFalse(PreferenceDriftScoring.isCandidate(playbackPreference: preference, score: score))
        }
    }

    func testInsufficientHistoricalSamplesAreNotCandidate() {
        let score = drift(preference: 3, recentFull: 0, recentSkip: 8, historicalFull: 7, historicalSkip: 0)
        XCTAssertEqual(score.rawScore, 0)
        XCTAssertFalse(PreferenceDriftScoring.isCandidate(playbackPreference: 3, score: score))
    }

    func testOverplayLowersStableDriftAndRecoveryRaisesIt() {
        let low = drift(preference: 3, recentFull: 0, recentSkip: 8,
                        historicalFull: 16, historicalSkip: 0, overplay: 0)
        let high = drift(preference: 3, recentFull: 0, recentSkip: 8,
                         historicalFull: 16, historicalSkip: 0, overplay: 1)
        XCTAssertLessThan(high.stableScore, low.stableScore)
        XCTAssertGreaterThan(low.stableScore, high.stableScore)
    }

    func testAnalysisDoesNotMutatePreferenceOrBoredomState() throws {
        let track = makeTrack("Unchanged")
        let now = try date(2026, 9, 1, calendar: fixedCalendar)
        let original = PlaybackHistory(
            trackID: track.id, isFavorite: false, playCount: 8, lastPlayedAt: now,
            playbackPreference: 3,
            dailySummaries: [
                "2026-09-01": PlaybackDailySummary(playCount: 8, skipCount: 8),
                "2026-07-01": PlaybackDailySummary(fullPlaybackCount: 16)
            ], boredomCount: 4, boredomHiddenUntil: now.addingTimeInterval(3600),
            isPermanentlyHiddenFromShuffle: true
        )
        let histories = [track.id: original]
        _ = PlaybackBehaviorAnalyzer().analyze(tracks: [track], historyByTrackID: histories,
                                               now: now, calendar: fixedCalendar)
        XCTAssertEqual(histories[track.id]?.playbackPreference, 3)
        XCTAssertEqual(histories[track.id]?.boredomCount, 4)
        XCTAssertEqual(histories[track.id]?.boredomHiddenUntil, original.boredomHiddenUntil)
        XCTAssertEqual(histories[track.id]?.isPermanentlyHiddenFromShuffle, true)
    }

    private func drift(
        preference: Int, recentFull: Int, recentSkip: Int, historicalFull: Int,
        historicalSkip: Int, overplay: Double = 0
    ) -> PreferenceDriftScore {
        PreferenceDriftScoring.score(
            playbackPreference: preference, recentFullPlaybackCount: recentFull,
            recentSkipCount: recentSkip, historicalFullPlaybackCount: historicalFull,
            historicalSkipCount: historicalSkip, overplayScore: overplay
        )
    }

    private var fixedCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, calendar: Calendar) throws -> Date {
        try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
    }

    private func makeTrack(_ title: String) -> Track {
        Track(id: UUID(), title: title, artistName: "Artist", albumTitle: "Album", duration: 180,
              fileURL: URL(fileURLWithPath: "/tmp/\(title).m4a"))
    }
}
