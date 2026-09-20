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
        XCTAssertEqual(first.map(\.id), [recent.id, favorite.id, new.id, old.id])
        XCTAssertEqual(first.map(\.id), second.map(\.id))
        XCTAssertEqual(first.map(\.id), all[.daily]?.map(\.id))
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

    private func track(_ title: String) -> Track {
        Track(id: UUID(), title: title, artistName: "Artist", duration: 180,
              fileURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).m4a"))
    }

    private func history(_ track: Track, count: Int, daysAgo: TimeInterval) -> PlaybackHistory {
        PlaybackHistory(trackID: track.id, isFavorite: false, playCount: count,
                        lastPlayedAt: now.addingTimeInterval(-daysAgo * 86_400))
    }
}
