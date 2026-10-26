import Foundation
import XCTest
@testable import MyMusic

final class ArtistRankingTests: XCTestCase {
    func testDepartmentMembershipAndEmptySettings() {
        let track = makeTrack("A", genre: "Jazz;Vocal")
        let prefs = [track.id: TrackPreference(trackID: track.id, playbackPreference: 15, favorite: true)]
        let empty = ArtistRankingService.pages(tracks: [track], histories: [:], preferences: prefs,
                                               settings: ArtistRankingSettings())
        XCTAssertTrue(empty[.instrumental]?.byScore.isEmpty == true)
        var settings = ArtistRankingSettings()
        settings.instrumental.genres = ["Jazz"]
        settings.vocal.genres = ["Vocal"]
        let pages = ArtistRankingService.pages(tracks: [track], histories: [:], preferences: prefs, settings: settings)
        XCTAssertEqual(pages[.instrumental]?.byScore.first?.good, 15)
        XCTAssertEqual(pages[.vocal]?.byScore.first?.favorites, 1)
        XCTAssertEqual(pages[.vocal]?.byScore.first?.score, 50)
    }

    func testAllRegisteredTracksSupplyDenominatorButOnlyRegularDivisionTracksSupplyCount() throws {
        let first = makeTrack("A")
        var tracks = [first]
        tracks += (0..<8).map { _ in makeTrack("A", genre: Track.workPlaybackGenre) }
        let histories = Dictionary(uniqueKeysWithValues: tracks.map {
            ($0.id, PlaybackHistory(trackID: $0.id, isFavorite: false, playCount: 10, lastPlayedAt: nil))
        })
        let pages = ArtistRankingService.pages(tracks: tracks, histories: histories, preferences: [:], settings: jazzSettings())
        let row = try XCTUnwrap(pages[.instrumental]?.byScore.first)
        XCTAssertEqual(row.totalTrackCount, 9)
        XCTAssertEqual(row.playCount, 10)
        XCTAssertEqual(row.divisor, 3)
        XCTAssertEqual(row.score, 40)
    }

    func testDetailedTimeDoesNotInferLegacyDurationAndBadDoesNotSubtract() {
        let track = makeTrack("A")
        let entry = PlaybackHistory(trackID: track.id, isFavorite: false, playCount: 1,
                                    lastPlayedAt: nil, totalPlaybackDuration: 500)
        let pages = ArtistRankingService.pages(tracks: [track], histories: [track.id: entry],
            preferences: [track.id: TrackPreference(trackID: track.id, playbackPreference: -10, favorite: false)],
            settings: jazzSettings())
        XCTAssertTrue(pages[.instrumental]?.byTime.isEmpty == true)
        XCTAssertEqual(pages[.instrumental]?.byScore.first?.good, 0)
    }

    func testTop100AndStableNaturalTieOrder() {
        let tracks = (1...110).reversed().map { makeTrack("Artist \($0)") }
        let prefs = Dictionary(uniqueKeysWithValues: tracks.map {
            ($0.id, TrackPreference(trackID: $0.id, playbackPreference: 1, favorite: false))
        })
        let pages = ArtistRankingService.pages(tracks: tracks, histories: [:], preferences: prefs, settings: jazzSettings())
        XCTAssertEqual(pages[.instrumental]?.byScore.count, 100)
        XCTAssertEqual(pages[.instrumental]?.byScore.first?.title, "Artist 1")
        XCTAssertEqual(pages[.instrumental]?.byScore.last?.title, "Artist 100")
    }

    func testAllFourComponentsReach100WithDetailedTime() throws {
        let track = makeTrack("A")
        let now = Date(timeIntervalSince1970: 1_000)
        let event = PlaybackEvent(trackID: track.id, startedAt: now,
            endedAt: now.addingTimeInterval(120), listenedSeconds: 120, completionRatio: 1,
            wasSkipped: false, wasFullPlayback: true, startKind: .manual, startSource: .artist)
        let history = PlaybackHistory(trackID: track.id, isFavorite: false, playCount: 1,
                                      lastPlayedAt: now, playbackEvents: [event])
        let pages = ArtistRankingService.pages(tracks: [track], histories: [track.id: history],
            preferences: [track.id: TrackPreference(trackID: track.id, playbackPreference: 5, favorite: true)],
            settings: jazzSettings())
        let row = try XCTUnwrap(pages[.instrumental]?.byScore.first)
        XCTAssertEqual(row.seconds, 120)
        XCTAssertEqual(row.score, 100)
        XCTAssertEqual(row.countPoints * 0.4, 40)
        XCTAssertEqual(row.timePoints * 0.1, 10)
        XCTAssertEqual(row.goodPoints * 0.3, 30)
        XCTAssertEqual(row.favoritePoints * 0.2, 20)
    }

    private func jazzSettings() -> ArtistRankingSettings {
        var settings = ArtistRankingSettings()
        settings.instrumental.genres = ["Jazz"]
        return settings
    }

    private func makeTrack(_ artist: String, genre: String = "Jazz") -> Track {
        Track(id: UUID(), title: "Song", artistName: artist, duration: 180,
              fileURL: URL(fileURLWithPath: "/tmp/ranking-fixture.wav"), genre: genre)
    }
}
