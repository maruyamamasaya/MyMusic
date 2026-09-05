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

    func testDifferentModeBandCannotBeReversedByDiversity() {
        let preceding = track("Previous", artist: "Same", album: "Same Album")
        let matching = track("Matching", artist: "Same", album: "Same Album")
        let opposite = track("Opposite", artist: "Different", album: "Different Album")
        let queue = HighlightSelectionPolicy.orderedTracks(
            [opposite, matching], mode: .upbeat,
            baseWeights: [matching.id: 0.01, opposite.id: 42], histories: [:],
            features: [
                matching.id: values(energy: 1, aggressive: 1, bright: 1),
                opposite.id: values(energy: 0, aggressive: 0, bright: 0)
            ], randomValues: [matching.id: 0, opposite.id: 1], precedingTracks: [preceding]
        )
        XCTAssertEqual(queue.first?.id, matching.id)
    }

    func testSameBandAvoidsImmediateArtistAndAlbumWhenAlternativeExists() {
        let preceding = track("Previous", artist: "Same", album: "Same Album")
        let repeated = track("Repeated", artist: "Same", album: "Same Album")
        let varied = track("Varied", artist: "Different", album: "Different Album")
        let feature = values(energy: 0.8, aggressive: 0.7, bright: 0.6)
        let queue = HighlightSelectionPolicy.orderedTracks(
            [repeated, varied], mode: .upbeat,
            baseWeights: [repeated.id: 42, varied.id: 0.01], histories: [:],
            features: [repeated.id: feature, varied.id: feature],
            randomValues: [repeated.id: 1, varied.id: 0], precedingTracks: [preceding]
        )
        XCTAssertEqual(queue.map(\.id), [varied.id, repeated.id])
    }

    func testSameBandAvoidsArtistIndependentlyOfAlbum() {
        let preceding = track("Previous", artist: "Same", album: "First Album")
        let repeated = track("Repeated", artist: "Same", album: "Second Album")
        let varied = track("Varied", artist: "Different", album: "Third Album")
        let feature = values(calm: 0.8, ambient: 0.7, piano: 0.6)
        let queue = HighlightSelectionPolicy.orderedTracks(
            [repeated, varied], mode: .calm,
            baseWeights: [repeated.id: 42, varied.id: 0.01], histories: [:],
            features: [repeated.id: feature, varied.id: feature], precedingTracks: [preceding]
        )
        XCTAssertEqual(queue.first?.id, varied.id)
    }

    func testSameBandAvoidsAlbumIndependentlyOfTrackArtist() {
        let preceding = track("Previous", artist: "Singer A", album: "Compilation", albumArtist: "Various")
        let repeated = track("Repeated", artist: "Singer B", album: "Compilation", albumArtist: "Various")
        let varied = track("Varied", artist: "Singer C", album: "Other", albumArtist: "Singer C")
        let feature = values(energy: 0.8, aggressive: 0.7, bright: 0.6)
        let queue = HighlightSelectionPolicy.orderedTracks(
            [repeated, varied], mode: .upbeat,
            baseWeights: [repeated.id: 42, varied.id: 0.01], histories: [:],
            features: [repeated.id: feature, varied.id: feature], precedingTracks: [preceding]
        )
        XCTAssertEqual(queue.first?.id, varied.id)
    }

    func testArtistAndAlbumPenaltiesExpireOutsideTheirWindows() {
        let candidate = track("Candidate", artist: "Same", album: "Same Album")
        let matching = track("Old", artist: "Same", album: "Same Album")
        let other = (0..<5).map { track("Other \($0)", artist: "Other \($0)", album: "Other \($0)") }
        XCTAssertGreaterThan(
            HighlightSelectionPolicy.diversityPenalty(for: candidate, recentTracks: [matching]), 0
        )
        XCTAssertEqual(
            HighlightSelectionPolicy.diversityPenalty(for: candidate, recentTracks: [matching] + other), 0
        )
    }

    func testRepeatedArtistAndAlbumRemainSelectableWhenOnlyCandidate() {
        let preceding = track("Previous", artist: "Same", album: "Same Album")
        let only = track("Only", artist: "Same", album: "Same Album")
        let queue = HighlightSelectionPolicy.orderedTracks(
            [only], mode: .upbeat, baseWeights: [only.id: 1], histories: [:],
            features: [only.id: values(energy: 0.8)], precedingTracks: [preceding]
        )
        XCTAssertEqual(queue.map(\.id), [only.id])
    }

    func testFeatureSimilarityIsLightAndOnlyBreaksOtherwiseCloseScores() throws {
        let preceding = track("Previous", artist: "Previous")
        let similar = track("Similar", artist: "Similar")
        let varied = track("Varied", artist: "Varied")
        let previousFeature = values(energy: 0.8, aggressive: 0.5, bright: 0.7)
        let similarFeature = values(energy: 0.81, aggressive: 0.50, bright: 0.69)
        let variedFeature = values(energy: 0.9, aggressive: 0.7, bright: 0.4)
        XCTAssertLessThan(
            try XCTUnwrap(HighlightSelectionPolicy.featureDistance(previousFeature, similarFeature)),
            HighlightSelectionPolicy.featureSimilarityDistanceThreshold
        )
        XCTAssertGreaterThan(
            try XCTUnwrap(HighlightSelectionPolicy.featureDistance(previousFeature, variedFeature)),
            HighlightSelectionPolicy.featureSimilarityDistanceThreshold
        )

        let closeQueue = HighlightSelectionPolicy.orderedTracks(
            [similar, varied], mode: .upbeat,
            baseWeights: [similar.id: 1, varied.id: 1], histories: [:],
            features: [preceding.id: previousFeature, similar.id: similarFeature, varied.id: variedFeature],
            randomValues: [similar.id: 0.5, varied.id: 0.5], precedingTracks: [preceding]
        )
        XCTAssertEqual(closeQueue.first?.id, varied.id)

        let preferenceQueue = HighlightSelectionPolicy.orderedTracks(
            [similar, varied], mode: .upbeat,
            baseWeights: [similar.id: 2, varied.id: 1], histories: [:],
            features: [preceding.id: previousFeature, similar.id: similarFeature, varied.id: variedFeature],
            randomValues: [similar.id: 0, varied.id: 1], precedingTracks: [preceding]
        )
        XCTAssertEqual(preferenceQueue.first?.id, similar.id)
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

    func testBoundedSelectionHandlesFiveThousandTracksWithoutFullGreedyOrdering() {
        verifyBoundedSelectionPerformance(trackCount: 5_000)
    }

    func testBoundedSelectionHandlesTenThousandTracksWithoutFullGreedyOrdering() {
        verifyBoundedSelectionPerformance(trackCount: 10_000)
    }

    func testSmallPoolSafelyReturnsEveryUniqueTrack() {
        let tracks = (0..<12).map { track("Track \($0)", artist: "Same", album: "Same") }
        let result = HighlightSelectionPolicy.selection(
            tracks, mode: .shuffle, baseWeights: [:], histories: [:], features: [:],
            candidatePoolLimit: 150, queueLimit: 40
        )

        XCTAssertEqual(result.tracks.count, tracks.count)
        XCTAssertEqual(Set(result.tracks.map(\.id)), Set(tracks.map(\.id)))
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

    private func track(
        _ title: String, artist: String = "Artist", album: String? = nil,
        albumArtist: String? = nil
    ) -> Track {
        Track(id: UUID(), title: title, artistName: artist, albumArtistName: albumArtist,
              albumTitle: album, duration: 180,
              fileURL: URL(fileURLWithPath: "/tmp/\(title).m4a"))
    }

    private func verifyBoundedSelectionPerformance(trackCount: Int) {
        let tracks = (0..<trackCount).map { index in
            track(
                "Track \(index)",
                artist: "Artist \(index % 300)",
                album: "Album \(index % 700)"
            )
        }
        let features = Dictionary(uniqueKeysWithValues: tracks.enumerated().map { index, track in
            (track.id, values(
                energy: Double(index % 101) / 100,
                aggressive: Double((index * 3) % 101) / 100,
                bright: Double((index * 7) % 101) / 100
            ))
        })
        let randomValues = Dictionary(uniqueKeysWithValues: tracks.enumerated().map {
            ($0.element.id, Double($0.offset % 997) / 996)
        })
        let startedAt = ProcessInfo.processInfo.systemUptime
        let result = HighlightSelectionPolicy.selection(
            tracks, mode: .upbeat, baseWeights: [:], histories: [:], features: features,
            randomValues: randomValues
        )
        let elapsed = ProcessInfo.processInfo.systemUptime - startedAt

        XCTAssertEqual(result.rankingCount, trackCount)
        XCTAssertLessThanOrEqual(result.candidatePoolCount, HighlightSelectionPolicy.candidatePoolLimit)
        XCTAssertEqual(result.tracks.count, HighlightSelectionPolicy.generatedQueueLimit)
        XCTAssertEqual(Set(result.tracks.map(\.id)).count, result.tracks.count)
        XCTAssertLessThanOrEqual(
            result.greedyComparisonCount,
            HighlightSelectionPolicy.candidatePoolLimit * HighlightSelectionPolicy.generatedQueueLimit
        )
        XCTAssertLessThan(elapsed, 2, "\(trackCount) tracks took \(elapsed)s")
        print("[HighlightSelectionTest] tracks=\(trackCount) elapsed=\(elapsed)s")
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
