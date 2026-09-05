import Foundation
import XCTest
@testable import MyMusic

final class PlaybackSelectionPolicyTests: XCTestCase {
    func testShuffleFactors() {
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleOverplayFactor(overplayScore: 0), 1)
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleOverplayFactor(overplayScore: 0.25), 0.9453125)
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleOverplayFactor(overplayScore: 0.5), 0.78125)
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleOverplayFactor(overplayScore: 0.75), 0.5078125)
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleOverplayFactor(overplayScore: 1), 0.125)
    }

    func testStationFactors() {
        XCTAssertEqual(PlaybackSelectionPolicy.stationOverplayFactor(overplayScore: 0), 1)
        XCTAssertEqual(PlaybackSelectionPolicy.stationOverplayFactor(overplayScore: 0.5), 0.78125)
        XCTAssertEqual(PlaybackSelectionPolicy.stationOverplayFactor(overplayScore: 1), 0.125)
    }

    func testPreferenceAndOverplayRemainPositive() {
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleWeight(playbackPreference: 0, overplayScore: 0), 1)
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleWeight(playbackPreference: 3, overplayScore: 0), 5.5)
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleWeight(playbackPreference: 3, overplayScore: 1), 0.6875)
        XCTAssertGreaterThan(PlaybackSelectionPolicy.shuffleWeight(playbackPreference: -3, overplayScore: 1), 0)
    }

    func testFactorsClampInvalidScoresWithoutExcludingTracks() {
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleOverplayFactor(overplayScore: 2), 0.125)
        XCTAssertEqual(PlaybackSelectionPolicy.shuffleOverplayFactor(overplayScore: -.infinity), 1)
        XCTAssertGreaterThan(PlaybackSelectionPolicy.shuffleWeight(playbackPreference: -10, overplayScore: 1), 0)
    }
}

@MainActor
final class PlaybackSelectionIntegrationTests: XCTestCase {
    func testHighlightSelectionSharesEligibilityWeightsAndKeepsTracksUnique() async throws {
        let now = try date(2026, 9, 7)
        let preferred = makeTrack("Preferred")
        let overplayed = makeTrack("Overplayed")
        let bored = makeTrack("Bored")
        let permanentlyHidden = makeTrack("Hidden")
        let recovered = makeTrack("Recovered")
        let tracks = [preferred, overplayed, bored, permanentlyHidden, recovered]
        let histories = [
            PlaybackHistory(trackID: overplayed.id, isFavorite: false, playCount: 12, lastPlayedAt: now,
                            dailySummaries: ["2026-09-07": PlaybackDailySummary(playCount: 12)]),
            PlaybackHistory(trackID: bored.id, isFavorite: false, playCount: 0, lastPlayedAt: nil,
                            boredomCount: 1, boredomHiddenUntil: now.addingTimeInterval(3_600)),
            PlaybackHistory(trackID: permanentlyHidden.id, isFavorite: false, playCount: 0, lastPlayedAt: nil,
                            boredomCount: 1, isPermanentlyHiddenFromShuffle: true),
            PlaybackHistory(trackID: recovered.id, isFavorite: false, playCount: 0, lastPlayedAt: nil,
                            boredomCount: 1, boredomHiddenUntil: now.addingTimeInterval(-1))
        ]
        let preferences = tracks.map {
            TrackPreference(trackID: $0.id, playbackPreference: $0.id == preferred.id ? 3 : 0, favorite: false)
        }
        let preferenceStore = TrackPreferenceStore(
            persistence: SelectionPreferencePersistence(entries: preferences)
        )
        await preferenceStore.loadIfNeeded(legacyHistory: nil)
        let store = PlaybackHistoryStore(
            persistence: SelectionHistoryPersistence(entries: histories),
            preferenceStore: preferenceStore
        )
        await store.loadIfNeeded()

        let queue = store.highlightPlaybackTracks(from: tracks, now: now)
        XCTAssertEqual(Set(queue.map(\.id)), Set([preferred.id, overplayed.id, recovered.id]))
        XCTAssertEqual(queue.count, Set(queue.map(\.id)).count)
        for mode in HighlightSelectionMode.allCases {
            let modeQueue = HighlightSelectionPolicy.orderedTracks(
                queue, mode: mode, baseWeights: store.automaticSelectionWeights(for: queue, now: now),
                histories: store.entries, features: [:], now: now
            )
            XCTAssertEqual(Set(modeQueue.map(\.id)), Set([preferred.id, overplayed.id, recovered.id]))
        }
        XCTAssertGreaterThan(
            try XCTUnwrap(store.automaticSelectionWeights(for: tracks, now: now)[preferred.id]),
            try XCTUnwrap(store.automaticSelectionWeights(for: tracks, now: now)[overplayed.id])
        )
        XCTAssertGreaterThan(
            try XCTUnwrap(store.automaticSelectionWeights(for: tracks, now: now)[overplayed.id]),
            0
        )
    }

    func testAutomaticWeightsUseDerivedOverplayAndRecoverWithTime() async throws {
        let track = makeTrack("Burst")
        let now = try date(2026, 9, 7)
        let history = PlaybackHistory(
            trackID: track.id, isFavorite: false, playCount: 12, lastPlayedAt: now,
            playbackPreference: 3,
            dailySummaries: ["2026-09-07": PlaybackDailySummary(playCount: 12)]
        )
        let preferenceStore = TrackPreferenceStore(persistence: SelectionPreferencePersistence())
        await preferenceStore.loadIfNeeded(legacyHistory: [track.id: history])
        let store = PlaybackHistoryStore(
            persistence: SelectionHistoryPersistence(entries: [history]),
            preferenceStore: preferenceStore
        )
        await store.loadIfNeeded()

        let burstWeight = try XCTUnwrap(store.automaticSelectionWeights(for: [track], now: now)[track.id])
        let recoveredWeight = try XCTUnwrap(store.automaticSelectionWeights(
            for: [track], now: now.addingTimeInterval(70 * 86_400)
        )[track.id])
        XCTAssertLessThan(burstWeight, PlaybackPreferenceWeightPolicy.weight(for: 3))
        XCTAssertEqual(recoveredWeight, PlaybackPreferenceWeightPolicy.weight(for: 3))
        XCTAssertEqual(preferenceStore.playbackPreference(for: track.id), 3)
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

private actor SelectionPreferencePersistence: TrackPreferencePersistenceServicing {
    var entries: [TrackPreference]?
    init(entries: [TrackPreference]? = nil) { self.entries = entries }
    func load() async throws -> [TrackPreference]? { entries }
    func save(_ preferences: [TrackPreference]) async throws { entries = preferences }
}
