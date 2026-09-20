import Foundation
import XCTest
@testable import MyMusic

final class DeepDiveSelectionServiceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)
    private let service = DeepDiveSelectionService()

    func testRecentArtistAndAlbumOfferOnlyLowPlayTracks() {
        let played = track("Played", artist: "Artist A", album: "Album A")
        let unheard = track("Unheard", artist: "Artist A", album: "Album A")
        let once = track("Once", artist: "Artist A", album: "Album A")
        let old = track("Old", artist: "Artist B", album: "Album B")
        let oldUnheard = track("Old Unheard", artist: "Artist B", album: "Album B")
        let belowThreshold = track("Almost", artist: "Artist C", album: "Album C")
        let belowThresholdUnheard = track("Low C", artist: "Artist C", album: "Album C")
        let histories = [
            played.id: history(played, playCount: 4, recentStarts: 15),
            once.id: history(once, playCount: 1, recentStarts: 0),
            old.id: history(old, playCount: 5, recentStarts: 15, daysAgo: 31),
            belowThreshold.id: history(belowThreshold, playCount: 4, recentStarts: 14)
        ]

        let options = service.options(from: [oldUnheard, once, played, unheard, old,
                                             belowThreshold, belowThresholdUnheard],
                                      histories: histories, weights: [:], now: now)
        XCTAssertEqual(options[.artist]?.map(\.title), ["Artist A"])
        XCTAssertEqual(options[.album]?.map(\.title), ["Album A"])
        let queue = options[.artist]?.first?.tracks ?? []
        XCTAssertEqual(queue.map(\.id).first, unheard.id)
        XCTAssertEqual(Set(queue.map(\.id)), Set([unheard.id, once.id]))
        XCTAssertEqual(options[.artist]?.first?.recentPlayCount, 15)
    }

    func testAlbumsWithSameTitleStaySeparateByAlbumArtist() {
        let firstPlayed = track("Played A", artist: "Artist A", album: "Shared")
        let firstLow = track("Low A", artist: "Artist A", album: "Shared")
        let secondPlayed = track("Played B", artist: "Artist B", album: "Shared")
        let secondLow = track("Low B", artist: "Artist B", album: "Shared")
        let histories = [
            firstPlayed.id: history(firstPlayed, playCount: 3, recentStarts: 16),
            secondPlayed.id: history(secondPlayed, playCount: 3, recentStarts: 15)
        ]

        let options = service.options(from: [firstPlayed, firstLow, secondPlayed, secondLow],
                                      histories: histories, weights: [:], now: now)
        let albums = options[.album] ?? []
        XCTAssertEqual(Set(albums.compactMap(\.detail)), Set(["Artist A", "Artist B"]))
        XCTAssertEqual(Set(albums.flatMap { $0.tracks.map(\.id) }), Set([firstLow.id, secondLow.id]))
    }

    func testOptionsAreLimitedToEight() {
        let pairs = (0..<10).map { index -> (Track, Track) in
            (track("Played \(index)", artist: "Artist \(index)", album: "Album \(index)"),
             track("Low \(index)", artist: "Artist \(index)", album: "Album \(index)"))
        }
        let histories = Dictionary(uniqueKeysWithValues: pairs.map {
            ($0.0.id, history($0.0, playCount: 3, recentStarts: 15))
        })

        let options = service.options(from: pairs.flatMap { [$0.0, $0.1] },
                                      histories: histories, weights: [:], now: now)
        XCTAssertEqual(options[.artist]?.count, 8)
        XCTAssertEqual(options[.album]?.count, 8)
    }

    private func track(_ title: String, artist: String, album: String) -> Track {
        Track(id: UUID(), title: title, artistName: artist, albumTitle: album, duration: 180,
              fileURL: URL(fileURLWithPath: "/tmp/\(UUID().uuidString).m4a"))
    }

    private func history(
        _ track: Track, playCount: Int, recentStarts: Int, daysAgo: Int = 0
    ) -> PlaybackHistory {
        let day = Calendar.playbackHistory.date(byAdding: .day, value: -daysAgo, to: now) ?? now
        let parts = Calendar.playbackHistory.dateComponents([.year, .month, .day], from: day)
        let dayKey = String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        return PlaybackHistory(
            trackID: track.id, isFavorite: false, playCount: playCount, lastPlayedAt: day,
            dailySummaries: [dayKey: PlaybackDailySummary(playCount: recentStarts)]
        )
    }
}
