import Foundation
import XCTest
@testable import MyMusic

final class MixSelectionServiceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let selector = MixSelectionService()

    func testDailyMixInterleavesFourSourcesAndIsStableWithinDay() {
        let recent = track("Recent")
        let favorite = track("Favorite")
        let new = track("New")
        let old = track("Old")
        let tracks = [old, new, favorite, recent]
        let histories = [
            recent.id: history(recent, count: 4, daysAgo: 2),
            old.id: history(old, count: 8, daysAgo: 100)
        ]
        let preferences = [favorite.id: TrackPreference(trackID: favorite.id, playbackPreference: 0, favorite: true)]

        let first = selector.tracks(for: .daily, from: tracks, histories: histories,
                                    preferences: preferences, weights: [:], now: now)
        let second = selector.tracks(for: .daily, from: tracks.reversed(), histories: histories,
                                     preferences: preferences, weights: [:], now: now)
        let all = selector.allQueues(from: tracks, histories: histories,
                                     preferences: preferences, weights: [:], now: now)
        XCTAssertEqual(first.map(\.id), [recent.id, new.id, old.id, favorite.id])
        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertEqual(first.map(\.id), all[.daily]?.map(\.id))
    }

    func testDailyMixAvoidsFavoritesFrontWhenOtherTracksCanFillQueue() {
        let favorites = (0..<25).map { track("Favorite \($0)") }
        let others = (0..<30).map { track("Other \($0)") }
        let preferences = Dictionary(uniqueKeysWithValues: favorites.map {
            ($0.id, TrackPreference(trackID: $0.id, playbackPreference: 1, favorite: true))
        })

        let queues = selector.allQueues(from: favorites + others, histories: [:],
                                        preferences: preferences, weights: [:], now: now)
        let dailyIDs = Set((queues[.daily] ?? []).map(\.id))
        let favoriteIDs = Set((queues[.favorites] ?? []).map(\.id))
        XCTAssertEqual(dailyIDs.count, 25)
        XCTAssertTrue(dailyIDs.isDisjoint(with: favoriteIDs))
    }

    func testDailyMixFillsFromFavoritesFrontWhenOtherTracksAreInsufficient() {
        let favorites = (0..<25).map { track("Favorite \($0)") }
        let others = (0..<5).map { track("Other \($0)") }
        let preferences = Dictionary(uniqueKeysWithValues: favorites.map {
            ($0.id, TrackPreference(trackID: $0.id, playbackPreference: 1, favorite: true))
        })

        let queues = selector.allQueues(from: favorites + others, histories: [:],
                                        preferences: preferences, weights: [:], now: now)
        let dailyIDs = Set((queues[.daily] ?? []).map(\.id))
        let favoriteIDs = Set((queues[.favorites] ?? []).map(\.id))
        XCTAssertEqual(dailyIDs.count, 25)
        XCTAssertTrue(Set(others.map(\.id)).isSubset(of: dailyIDs))
        XCTAssertEqual(dailyIDs.intersection(favoriteIDs).count, 20)
    }

    func testRediscoveryRequiresRepeatedPastListeningAndSixtyDaysAway() {
        let old = track("Old")
        let recent = track("Recent")
        let once = track("Once")
        let never = track("Never")
        let histories = [
            old.id: history(old, count: 3, daysAgo: 90),
            recent.id: history(recent, count: 8, daysAgo: 15),
            once.id: history(once, count: 1, daysAgo: 90)
        ]
        let result = selector.tracks(for: .rediscovery, from: [old, recent, once, never],
                                     histories: histories, preferences: [:], weights: [:], now: now)
        XCTAssertEqual(result.map(\.id), [old.id])
    }

    func testFavoritesIncludesFavoriteOrGoodAndLimitsQueue() {
        let tracks = (0..<30).map { track("Track \($0)") }
        var preferences: [Track.ID: TrackPreference] = [:]
        for (index, item) in tracks.enumerated() {
            preferences[item.id] = TrackPreference(trackID: item.id,
                                                   playbackPreference: index == 0 ? -1 : 1,
                                                   favorite: index == 0)
        }
        let result = selector.tracks(for: .favorites, from: tracks, histories: [:],
                                     preferences: preferences, weights: [:], now: now)
        XCTAssertEqual(result.count, 25)
        XCTAssertEqual(Set(result.map(\.id)).count, 25)
    }

    func testFlowMixStartsFromMostRecentAnalyzedTrackAndFollowsNearestFeatures() {
        let distant = track("Distant")
        let seed = track("Seed")
        let nearest = track("Nearest")
        let middle = track("Middle")
        let histories = [seed.id: history(seed, count: 2, daysAgo: 1)]
        let features = [
            seed.id: feature(energy: 0.20, calm: 0.80),
            nearest.id: feature(energy: 0.25, calm: 0.75),
            middle.id: feature(energy: 0.55, calm: 0.45),
            distant.id: feature(energy: 0.90, calm: 0.10)
        ]

        let result = selector.tracks(
            for: .flow,
            from: [distant, middle, nearest, seed],
            histories: histories,
            preferences: [:],
            weights: [:],
            features: features,
            now: now
        )

        XCTAssertEqual(result.map(\.id), [seed.id, nearest.id, middle.id, distant.id])
    }

    func testFlowMixIsHiddenWhenFewerThanThreeTracksHaveUsableFeatures() {
        let first = track("First")
        let second = track("Second")
        let result = selector.tracks(
            for: .flow,
            from: [first, second],
            histories: [:],
            preferences: [:],
            weights: [:],
            features: [
                first.id: feature(energy: 0.2, calm: 0.8),
                second.id: feature(energy: 0.3, calm: 0.7)
            ],
            now: now
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testTimeCapsuleUsesSameSeasonFromPriorYearsAndExcludesRecentTracks() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let anniversary = track("Anniversary")
        let outsideWindow = track("Outside")
        let recentlyPlayed = track("Recent")
        let oneYearAgo = try XCTUnwrap(calendar.date(byAdding: .year, value: -1, to: now))
        let histories = [
            anniversary.id: history(
                anniversary,
                eventDates: [oneYearAgo.addingTimeInterval(10 * 86_400)],
                lastPlayedAt: oneYearAgo
            ),
            outsideWindow.id: history(
                outsideWindow,
                eventDates: [oneYearAgo.addingTimeInterval(80 * 86_400)],
                lastPlayedAt: oneYearAgo
            ),
            recentlyPlayed.id: history(
                recentlyPlayed,
                eventDates: [oneYearAgo],
                lastPlayedAt: now.addingTimeInterval(-10 * 86_400)
            )
        ]

        let result = selector.tracks(
            for: .timeCapsule,
            from: [outsideWindow, recentlyPlayed, anniversary],
            histories: histories,
            preferences: [:],
            weights: [:],
            now: now,
            calendar: calendar
        )

        XCTAssertEqual(result.map(\.id), [anniversary.id])
    }

    private func track(_ title: String) -> Track {
        Track(id: UUID(), title: title, artistName: "Artist", duration: 180,
              fileURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).m4a"))
    }

    private func history(_ track: Track, count: Int, daysAgo: TimeInterval) -> PlaybackHistory {
        PlaybackHistory(trackID: track.id, isFavorite: false, playCount: count,
                        lastPlayedAt: now.addingTimeInterval(-daysAgo * 86_400))
    }

    private func history(
        _ track: Track,
        eventDates: [Date],
        lastPlayedAt: Date
    ) -> PlaybackHistory {
        PlaybackHistory(
            trackID: track.id,
            isFavorite: false,
            playCount: eventDates.count,
            firstPlayedAt: eventDates.min(),
            lastPlayedAt: lastPlayedAt,
            playbackEvents: eventDates.map {
                PlaybackEvent(
                    trackID: track.id,
                    startedAt: $0,
                    endedAt: $0.addingTimeInterval(180),
                    listenedSeconds: 180,
                    completionRatio: 1,
                    wasSkipped: false,
                    wasFullPlayback: true,
                    startKind: .manual,
                    startSource: .home,
                    endKind: .natural
                )
            }
        )
    }

    private func feature(energy: Double, calm: Double) -> TrackFeatureValues {
        TrackFeatureValues(
            tempo: nil,
            energy: energy,
            piano: nil,
            ambient: nil,
            electronic: nil,
            drumAndBass: nil,
            aggressive: nil,
            calm: calm,
            bright: nil,
            dark: nil,
            vocal: nil,
            instrumental: nil,
            additional: nil
        )
    }
}
