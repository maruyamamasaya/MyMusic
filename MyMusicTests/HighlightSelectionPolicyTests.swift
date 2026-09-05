import Foundation
import XCTest
@testable import MyMusic

final class HighlightSelectionPolicyTests: XCTestCase {
    func testRecentHighlightPenaltyBandsUseMostRecentOccurrence() {
        XCTAssertEqual(HighlightSelectionPolicy.recentHighlightPenalty(rank: 1), 0.20)
        XCTAssertEqual(HighlightSelectionPolicy.recentHighlightPenalty(rank: 20), 0.20)
        XCTAssertEqual(HighlightSelectionPolicy.recentHighlightPenalty(rank: 21), 0.60)
        XCTAssertEqual(HighlightSelectionPolicy.recentHighlightPenalty(rank: 50), 0.60)
        XCTAssertEqual(HighlightSelectionPolicy.recentHighlightPenalty(rank: 51), 1)
        XCTAssertEqual(HighlightSelectionPolicy.recentHighlightPenalty(rank: nil), 1)

        let repeatedID = UUID()
        let olderID = UUID()
        let histories = [
            repeatedID: history(repeatedID, events: [event(repeatedID, index: 1), event(repeatedID, index: 40)]),
            olderID: history(olderID, events: [event(olderID, index: 30)])
        ]
        let ranks = HighlightSelectionPolicy.recentHighlightRanks(histories: histories)
        XCTAssertEqual(ranks[repeatedID], 1)
        XCTAssertEqual(ranks[olderID], 2)
    }

    func testModeWeightsFavorMatchingFeaturesAndTreatMissingFeaturesAsNeutral() {
        let active = values(energy: 1, aggressive: 1, bright: 1, drumAndBass: 1)
        let relaxed = values(energy: 0, aggressive: 0, calm: 1, ambient: 1, piano: 1)
        let now = Date(timeIntervalSince1970: 2_000_000_000)

        XCTAssertGreaterThan(HighlightSelectionPolicy.modeWeight(
            mode: .upbeat, feature: active, history: nil, now: now
        ), HighlightSelectionPolicy.modeWeight(mode: .upbeat, feature: relaxed, history: nil, now: now))
        XCTAssertGreaterThan(HighlightSelectionPolicy.modeWeight(
            mode: .calm, feature: relaxed, history: nil, now: now
        ), HighlightSelectionPolicy.modeWeight(mode: .calm, feature: active, history: nil, now: now))
        XCTAssertEqual(HighlightSelectionPolicy.modeWeight(mode: .upbeat, feature: nil, history: nil, now: now), 1)
        XCTAssertEqual(HighlightSelectionPolicy.modeWeight(mode: .calm, feature: nil, history: nil, now: now), 1)
    }

    func testUpbeatAffinityWinsOverExtremePreferenceRecencyAndRandom() {
        let matching = track("Matching")
        let opposite = track("Opposite")
        let histories = [matching.id: history(matching.id, events: [event(matching.id, index: 1)])]
        let queue = HighlightSelectionPolicy.orderedTracks(
            [opposite, matching], mode: .upbeat,
            baseWeights: [matching.id: 0.01, opposite.id: 42], histories: histories,
            features: [
                matching.id: values(energy: 1, aggressive: 1, bright: 1),
                opposite.id: values(energy: 0, aggressive: 0, bright: 0)
            ],
            now: Date(timeIntervalSince1970: 2_000_000_000),
            randomValues: [matching.id: 0, opposite.id: 1]
        )
        XCTAssertEqual(queue.map(\.id), [matching.id, opposite.id])
    }

    func testCalmAffinityWinsOverExtremePreferenceRecencyAndRandom() {
        let matching = track("Matching")
        let opposite = track("Opposite")
        let histories = [matching.id: history(matching.id, events: [event(matching.id, index: 1)])]
        let queue = HighlightSelectionPolicy.orderedTracks(
            [opposite, matching], mode: .calm,
            baseWeights: [matching.id: 0.01, opposite.id: 42], histories: histories,
            features: [
                matching.id: values(calm: 1, ambient: 1, piano: 1),
                opposite.id: values(calm: 0, ambient: 0, piano: 0)
            ],
            now: Date(timeIntervalSince1970: 2_000_000_000),
            randomValues: [matching.id: 0, opposite.id: 1]
        )
        XCTAssertEqual(queue.map(\.id), [matching.id, opposite.id])
    }

    func testRandomOnlyReordersOtherwiseEquivalentCandidates() {
        let first = track("First")
        let second = track("Second")
        let commonFeature = values(energy: 0.8, aggressive: 0.8, bright: 0.8)
        let arguments: [Track.ID: TrackFeatureValues] = [first.id: commonFeature, second.id: commonFeature]
        let firstOrder = HighlightSelectionPolicy.orderedTracks(
            [first, second], mode: .upbeat, baseWeights: [first.id: 1, second.id: 1],
            histories: [:], features: arguments, randomValues: [first.id: 1, second.id: 0]
        )
        let secondOrder = HighlightSelectionPolicy.orderedTracks(
            [first, second], mode: .upbeat, baseWeights: [first.id: 1, second.id: 1],
            histories: [:], features: arguments, randomValues: [first.id: 0, second.id: 1]
        )
        XCTAssertEqual(firstOrder.first?.id, first.id)
        XCTAssertEqual(secondOrder.first?.id, second.id)
    }

    func testDiscoveryFavorsUnplayedLowCountAndLongUnplayedTracks() {
        let now = Date(timeIntervalSince1970: 2_000_000_000)
        let low = history(UUID(), playCount: 2, lastPlayedAt: now.addingTimeInterval(-400 * 86_400))
        let frequent = history(UUID(), playCount: 20, lastPlayedAt: now.addingTimeInterval(-86_400))

        XCTAssertEqual(HighlightSelectionPolicy.modeWeight(mode: .discovery, feature: nil, history: nil, now: now), 2)
        XCTAssertGreaterThan(
            HighlightSelectionPolicy.modeWeight(mode: .discovery, feature: nil, history: low, now: now),
            HighlightSelectionPolicy.modeWeight(mode: .discovery, feature: nil, history: frequent, now: now)
        )

        let unplayed = track("Unplayed")
        let frequentTrack = track("Frequent")
        let queue = HighlightSelectionPolicy.orderedTracks(
            [frequentTrack, unplayed], mode: .discovery,
            baseWeights: [unplayed.id: 0.01, frequentTrack.id: 42],
            histories: [frequentTrack.id: frequent], features: [:], now: now,
            randomValues: [unplayed.id: 0, frequentTrack.id: 1]
        )
        XCTAssertEqual(queue.first?.id, unplayed.id)
    }

    func testFinalWeightsLayerRecentAndModeFactorsWithoutDroppingTracks() {
        let recent = track("Recent")
        let ordinary = track("Ordinary")
        let histories = [recent.id: history(recent.id, events: [event(recent.id, index: 1)])]
        let weights = HighlightSelectionPolicy.finalWeights(
            tracks: [recent, ordinary], mode: .shuffle,
            baseWeights: [recent.id: 5, ordinary.id: 1], histories: histories,
            features: [:], now: Date(timeIntervalSince1970: 2_000_000_000)
        )
        XCTAssertEqual(weights[recent.id], 1)
        XCTAssertEqual(weights[ordinary.id], 1)

        let queue = HighlightSelectionPolicy.orderedTracks(
            [recent, ordinary], mode: .shuffle, baseWeights: [recent.id: 5, ordinary.id: 1],
            histories: histories, features: [:]
        )
        XCTAssertEqual(Set(queue.map(\.id)), Set([recent.id, ordinary.id]))
        XCTAssertEqual(queue.count, 2)
    }

    func testShuffleKeepsFeatureNeutralAndUsesAdjustedBaseWeight() {
        let preferred = track("Preferred")
        let other = track("Other")
        let queue = HighlightSelectionPolicy.orderedTracks(
            [other, preferred], mode: .shuffle,
            baseWeights: [preferred.id: 2, other.id: 1], histories: [:],
            features: [other.id: values(calm: 1, ambient: 1, piano: 1)],
            randomValues: [preferred.id: 0, other.id: 1]
        )
        XCTAssertEqual(queue.first?.id, preferred.id)
    }

    @MainActor
    func testRecentHighlightHistoryDoesNotChangeRegularShuffleBaseWeight() async {
        let track = track("Recent")
        let history = history(track.id, events: [event(track.id, index: 1)])
        let store = PlaybackHistoryStore(
            persistence: HighlightSelectionHistoryPersistence(entries: [history])
        )
        await store.loadIfNeeded()
        let regularWeight = store.automaticSelectionWeights(for: [track])[track.id]
        XCTAssertEqual(regularWeight, PlaybackPreferenceWeightPolicy.weight(for: 0))

        let highlightWeight = HighlightSelectionPolicy.finalWeights(
            tracks: [track], mode: .shuffle, baseWeights: [track.id: regularWeight!],
            histories: store.entries, features: [:], now: Date()
        )[track.id]
        XCTAssertEqual(highlightWeight, regularWeight! * 0.20)
    }

    private func track(_ title: String) -> Track {
        Track(id: UUID(), title: title, artistName: "Artist", duration: 180,
              fileURL: URL(fileURLWithPath: "/tmp/\(title).m4a"))
    }

    private func history(
        _ id: Track.ID, playCount: Int = 0, lastPlayedAt: Date? = nil,
        events: [PlaybackEvent] = []
    ) -> PlaybackHistory {
        PlaybackHistory(trackID: id, isFavorite: false, playCount: playCount,
                        lastPlayedAt: lastPlayedAt, playbackEvents: events)
    }

    private func event(_ id: Track.ID, index: Int) -> PlaybackEvent {
        let started = Date(timeIntervalSince1970: 2_000_000_000 - Double(index))
        return PlaybackEvent(trackID: id, startedAt: started, endedAt: started.addingTimeInterval(10),
                             listenedSeconds: 10, completionRatio: 0.1, wasSkipped: false,
                             wasFullPlayback: false, startKind: .automatic, startSource: .highlight)
    }

    private func values(
        energy: Double? = nil, aggressive: Double? = nil, bright: Double? = nil,
        drumAndBass: Double? = nil, calm: Double? = nil, ambient: Double? = nil,
        piano: Double? = nil
    ) -> TrackFeatureValues {
        TrackFeatureValues(
            tempo: nil, energy: energy, piano: piano, ambient: ambient, electronic: nil,
            drumAndBass: drumAndBass, aggressive: aggressive, calm: calm, bright: bright,
            dark: nil, vocal: nil, instrumental: nil, additional: nil
        )
    }
}

private actor HighlightSelectionHistoryPersistence: PlaybackHistoryPersistenceServicing {
    var entries: [PlaybackHistory]
    init(entries: [PlaybackHistory]) { self.entries = entries }
    func load() async throws -> [PlaybackHistory] { entries }
    func save(_ history: [PlaybackHistory]) async throws { entries = history }
}
