import Foundation
import XCTest
@testable import MyMusic

final class PlaybackSelectionPolicyTests: XCTestCase {
    func testShuffleFactors() {
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleOverplayFactor(overplayScore: 0), 1)
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleOverplayFactor(overplayScore: 0.5), 0.75)
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleOverplayFactor(overplayScore: 1), 0.5)
    }

    func testStationFactors() {
        XCTAssertEqual(PlaybackSelectionPolicy.stationOverplayFactor(overplayScore: 0), 1)
        XCTAssertEqual(PlaybackSelectionPolicy.stationOverplayFactor(overplayScore: 1), 0.8)
    }

    func testPreferenceAndOverplayRemainPositive() {
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleWeight(playbackPreference: 0, overplayScore: 0), 1)
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleWeight(playbackPreference: 3, overplayScore: 0), 5.5)
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleWeight(playbackPreference: 3, overplayScore: 1), 2.75)
        XCTAssertGreaterThan(
            PlaybackSelectionPolicy.shuffleWeight(playbackPreference: 3, overplayScore: 1),
            PlaybackSelectionPolicy.shuffleWeight(playbackPreference: 0, overplayScore: 0)
        )
        XCTAssertGreaterThan(PlaybackSelectionPolicy.shuffleWeight(playbackPreference: -3, overplayScore: 1), 0)
    }

    func testFactorsClampInvalidScoresWithoutExcludingTracks() {
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleOverplayFactor(overplayScore: 2), 0.5)
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleOverplayFactor(overplayScore: -.infinity), 1)
        XCTAssertGreaterThan(PlaybackSelectionPolicy.shuffleWeight(playbackPreference: -10, overplayScore: 1), 0)
    }
}

@MainActor
final class PlaybackSelectionIntegrationTests: XCTestCase {
    func testAutomaticWeightsUseDerivedOverplayAndRecoverWithTime() async throws {
        let track = makeTrack("Burst")
        let now = try date(2026, 9, 7)
        let history = PlaybackHistory(
            trackID: track.id, isFavorite: false, playCount: 12, lastPlayedAt: now,
            playbackPreference: 3,
            dailySummaries: ["2026-09-07": PlaybackDailySummary(playCount: 12)]
        )
        let store = PlaybackHistoryStore(persistence: SelectionHistoryPersistence(entries: [history]))
        await store.loadIfNeeded()

        let burstWeight = try XCTUnwrap(store.automaticSelectionWeights(for: [track], now: now)[track.id])
        let recoveredWeight = try XCTUnwrap(store.automaticSelectionWeights(
            for: [track], now: now.addingTimeInterval(70 * 86_400)
        )[track.id])
        XCTAssertLessThan(burstWeight, PlaybackPreferenceWeightPolicy.weight(for: 3))
        XCTAssertEqual(recoveredWeight, PlaybackPreferenceWeightPolicy.weight(for: 3))
        XCTAssertEqual(store.playbackPreference(for: track.id), 3)
        XCTAssertEqual(store.boredomLevel(for: track.id), 0)
        XCTAssertEqual(store.playCount(for: track.id), 12)
    }

    private func makeTrack(_ title: String) -> Track {
        Track(id: UUID(), title: title, artistName: "Artist", duration: 180,
              fileURL: URL(fileURLWithPath: "/tmp/\(title).m4a"))
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return try XCTUnwrap(calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)))
    }
}

private actor SelectionHistoryPersistence: PlaybackHistoryPersistenceServicing {
    var entries: [PlaybackHistory]
    init(entries: [PlaybackHistory]) { self.entries = entries }
    func load() async throws -> [PlaybackHistory] { entries }
    func save(_ history: [PlaybackHistory]) async throws { entries = history }
}
