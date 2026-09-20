import Foundation
import XCTest
@testable import MyMusic

@MainActor
final class MusicHistoryCardServiceTests: XCTestCase {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        return value
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private func track(_ name: String, artist: String = "Artist", album: String? = nil) -> Track {
        Track(id: UUID(), title: name, artistName: artist, albumTitle: album,
              duration: 180, fileURL: URL(fileURLWithPath: "/tmp/\(name).m4a"))
    }

    private func history(_ track: Track, _ dates: [Date],
                         kinds: [PlaybackStartKind] = [], sources: [PlaybackStartSource] = []) -> PlaybackHistory {
        let events = dates.enumerated().map { offset, date in
            PlaybackEvent(trackID: track.id, startedAt: date, endedAt: date,
                          listenedSeconds: 120, completionRatio: 0.8,
                          wasSkipped: false, wasFullPlayback: false,
                          startKind: kinds.indices.contains(offset) ? kinds[offset] : .manual,
                          startSource: sources.indices.contains(offset) ? sources[offset] : .unknown)
        }
        return PlaybackHistory(trackID: track.id, isFavorite: false,
                               playCount: events.count, firstPlayedAt: dates.min(), lastPlayedAt: dates.max(),
                               playbackEvents: events)
    }

    private func cards(_ tracks: [Track], _ histories: [PlaybackHistory],
                       now: Date, preferences: [Track.ID: TrackPreference] = [:],
                       features: [Track.ID: TrackFeature] = [:], limit: Int = 12) -> [MusicHistoryCardCandidate] {
        MusicHistoryCardService().makeCards(
            tracks: tracks, historyEntries: Dictionary(uniqueKeysWithValues: histories.map { ($0.trackID, $0) }),
            preferences: preferences, features: features, now: now, calendar: calendar, limit: limit
        )
    }

    private func feature(_ track: Track, calm: Double) -> TrackFeature {
        let identity = TrackFeatureSourceIdentity(relativePath: track.title, fileSize: 1,
                                                  duration: 180, modificationDate: nil,
                                                  contentHash: nil, title: nil, artist: nil, album: nil)
        let values = TrackFeatureValues(tempo: nil, energy: nil, piano: nil, ambient: nil,
                                        electronic: nil, drumAndBass: nil, aggressive: nil,
                                        calm: calm, bright: nil, dark: nil, vocal: nil,
                                        instrumental: nil, additional: nil)
        return TrackFeature(trackID: track.id, sourceIdentity: identity, analysisVersion: 1,
                            analyzedAt: date(2026, 9, 1), importedAt: date(2026, 9, 1), values: values)
    }

    func testInsufficientHistoryAndMissingLibraryAreHidden() {
        let song = track("One")
        let event = history(song, [date(2026, 9, 20)])
        XCTAssertTrue(cards([song], [event], now: date(2026, 9, 20, 18)).isEmpty)
        XCTAssertTrue(cards([], [event], now: date(2026, 9, 20, 18)).isEmpty)
    }

    func testYearAgoExactDayWinsNearbyAndLeapDayUsesCalendar() {
        let exact = track("Exact")
        let nearby = track("Nearby")
        let result = cards([exact, nearby], [history(exact, [date(2025, 9, 20)]),
                                             history(nearby, [date(2025, 9, 19), date(2025, 9, 19)])],
                           now: date(2026, 9, 20, 18))
        XCTAssertEqual(result.first { $0.type == .yearAgo }?.mainTrack?.id, exact.id)
        let leap = cards([exact], [history(exact, [date(2024, 2, 29)])], now: date(2025, 3, 1, 18))
        XCTAssertEqual(leap.first { $0.type == .yearAgo }?.mainTrack?.id, exact.id)
    }

    func testMonthTopNewTrackAndNewArtistAtMonthAndYearBoundaries() {
        let a = track("A", artist: "New")
        let b = track("B", artist: "New")
        let c = track("C", artist: "New")
        let old = track("Old", artist: "Old")
        let result = cards([a, b, c, old], [
            history(a, [date(2026, 1, 1), date(2026, 1, 2), date(2026, 1, 3)]),
            history(b, [date(2026, 1, 2), date(2026, 1, 3)]),
            history(c, [date(2026, 1, 2), date(2026, 1, 3)]),
            history(old, [date(2025, 12, 31), date(2026, 1, 1)])
        ], now: date(2026, 1, 4), limit: 12)
        XCTAssertEqual(result.first { $0.type == .monthTrack }?.mainTrack?.id, a.id)
        XCTAssertTrue(result.contains { $0.type == .newArtist })
        // The leading track can appear only once; another newly discovered track may be selected.
        XCTAssertTrue(result.contains { $0.type == .newTrack && ($0.mainTrack?.id == b.id || $0.mainTrack?.id == c.id) })
    }

    func testRediscoveredLongTermRecurringAndNightBoundary() {
        let returning = track("Returning")
        let faithful = track("Faithful")
        let night = track("Night")
        let result = cards([returning, faithful, night], [
            history(returning, [date(2025, 1, 1), date(2025, 1, 2), date(2025, 1, 3), date(2026, 9, 10), date(2026, 9, 12)]),
            history(faithful, [date(2025, 10, 1), date(2025, 12, 1), date(2026, 2, 1), date(2026, 4, 1), date(2026, 6, 1), date(2026, 9, 18)]),
            history(night, [date(2026, 8, 1, 22), date(2026, 8, 2, 4, 59), date(2026, 8, 3, 23), date(2026, 8, 4, 1), date(2026, 8, 5, 5)])
        ], now: date(2026, 9, 20))
        XCTAssertTrue(result.contains { $0.type == .rediscovered })
        XCTAssertTrue(result.contains { $0.type == .longTerm || $0.type == .recurring })
        XCTAssertTrue(result.contains { $0.type == .night && $0.mainTrack?.id == night.id })
    }

    func testAutomaticToManualRequiresKnownFirstSource() {
        let found = track("Found")
        let unknown = track("Unknown")
        let dates = [1, 2, 3, 4].map { date(2026, 8, $0) }
        let kinds: [PlaybackStartKind] = [.automatic, .manual, .manual, .automatic]
        let foundHistory = history(found, dates, kinds: kinds, sources: [.shuffle, .search, .library, .shuffle])
        let unknownHistory = history(unknown, dates, kinds: kinds)
        let preferences = [found.id: TrackPreference(trackID: found.id, playbackPreference: 1, favorite: false)]
        let result = cards([found, unknown], [foundHistory, unknownHistory], now: date(2026, 9, 20), preferences: preferences)
        XCTAssertEqual(result.first { $0.type == .shuffleDiscovery }?.mainTrack?.id, found.id)
    }

    func testBusiestDayAlbumAndDuplicateHeroSuppression() {
        let a = track("A", album: "Collection")
        let b = track("B", album: "Collection")
        let c = track("C", album: "Other")
        let result = cards([a, b, c], [
            history(a, [date(2026, 8, 1), date(2026, 9, 14), date(2026, 9, 14, 14), date(2026, 9, 15)]),
            history(b, [date(2026, 8, 1), date(2026, 9, 14), date(2026, 9, 14, 15)]),
            history(c, [date(2026, 8, 1), date(2026, 9, 14)])
        ], now: date(2026, 9, 20))
        XCTAssertTrue(result.contains { $0.type == .busiestDay })
        XCTAssertTrue(result.contains { $0.type == .monthAlbum })
        let heroes = result.compactMap { $0.mainTrack?.id }
        XCTAssertEqual(heroes.count, Set(heroes).count)
    }

    func testMissingFeaturesDoNotMakeSoundCard() {
        let songs = (0..<5).map { track("Song\($0)") }
        let histories = songs.map { history($0, [date(2026, 9, 1), date(2026, 9, 2)]) }
        let result = cards(songs, histories, now: date(2026, 9, 20))
        XCTAssertFalse(result.contains { $0.type == .monthSound })
    }

    func testRecurringMonthsWithoutRecentPlayAndLongTermWithRecentPlay() {
        let recurring = track("Recurring")
        let longTerm = track("LongTerm")
        let result = cards([recurring, longTerm], [
            history(recurring, [date(2026, 1, 10), date(2026, 2, 10), date(2026, 3, 10),
                                date(2026, 4, 10), date(2026, 5, 10), date(2026, 6, 10)]),
            history(longTerm, [date(2025, 12, 10), date(2026, 1, 10), date(2026, 2, 10),
                               date(2026, 3, 10), date(2026, 4, 10), date(2026, 5, 10),
                               date(2026, 6, 10), date(2026, 7, 10), date(2026, 8, 10), date(2026, 9, 19)])
        ], now: date(2026, 9, 20))
        XCTAssertEqual(result.first { $0.type == .recurring }?.mainTrack?.id, recurring.id)
        XCTAssertEqual(result.first { $0.type == .longTerm }?.mainTrack?.id, longTerm.id)
    }

    func testNightWindowExcludesFiveOClockAndTieIsStable() {
        let morning = track("Morning")
        let first = track("First")
        let second = track("Second")
        let histories = [
            history(morning, (1...5).map { date(2026, 8, $0, 5) }),
            history(first, [date(2026, 9, 1), date(2026, 9, 2)]),
            history(second, [date(2026, 9, 1), date(2026, 9, 2)])
        ]
        let one = cards([morning, first, second], histories, now: date(2026, 9, 20))
        let two = cards([morning, first, second], histories, now: date(2026, 9, 20))
        XCTAssertFalse(one.contains { $0.type == .night })
        XCTAssertEqual(one.map(\.id), two.map(\.id))
    }

    func testMonthSoundUsesRelativeFeaturesAndSkipsUnfeaturedTracks() {
        let current = (0..<5).map { track("Current\($0)") }
        let baseline = (0..<5).map { track("Baseline\($0)") }
        let all = current + baseline
        let features = Dictionary(uniqueKeysWithValues: all.map { song in
            (song.id, feature(song, calm: current.contains(where: { $0.id == song.id }) ? 0.9 : 0.1))
        })
        let result = cards(all, current.map { history($0, [date(2026, 9, 1), date(2026, 9, 2)]) },
                           now: date(2026, 9, 20), features: features)
        XCTAssertTrue(result.contains { $0.type == .monthSound && $0.subtitle.contains("Calm") })
    }
}
