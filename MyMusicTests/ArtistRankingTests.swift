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

    func testWeeklyMondayBoundariesAndCombinedGenres() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Tokyo")!
        let monday = calendar.date(from: DateComponents(year: 2026, month: 10, day: 26))!
        let week = ArtistRankingService.week(containing: monday.addingTimeInterval(3 * 86400), calendar: calendar)
        XCTAssertEqual(week.start, monday)
        XCTAssertEqual(ArtistRankingService.week(containing: week.end.addingTimeInterval(-1), calendar: calendar), week)
        XCTAssertEqual(ArtistRankingService.week(containing: week.end, offset: -1, calendar: calendar), week)
        let tracks = [makeTrack("A", genre: "Vocal"), makeTrack("B", genre: "Jazz")]
        func event(_ track: Track, _ date: Date, _ seconds: Double) -> PlaybackEvent {
            PlaybackEvent(trackID: track.id, startedAt: date, endedAt: date.addingTimeInterval(seconds),
                          listenedSeconds: seconds, completionRatio: 0, wasSkipped: true,
                          wasFullPlayback: false, startKind: .manual, startSource: .artist)
        }
        let histories = Dictionary(uniqueKeysWithValues: tracks.map { track in
            (track.id, PlaybackHistory(trackID: track.id, isFavorite: false, playCount: 999, lastPlayedAt: nil,
                playbackEvents: [event(track, monday.addingTimeInterval(-1), 120),
                                 event(track, monday, 30), event(track, monday.addingTimeInterval(100), 10),
                                 event(track, week.end, 120)]))
        })
        let pages = ArtistRankingService.pages(tracks: tracks, histories: histories, preferences: [:],
                                              settings: ArtistRankingSettings(), week: week)
        let rows = try XCTUnwrap(pages[.instrumental]?.byCount)
        XCTAssertEqual(rows.count, 2)
        XCTAssertTrue(rows.allSatisfy { $0.playCount == 1 && $0.seconds == 40 && abs($0.score - (80 + 20.0 / 7)) < 0.001 })
        XCTAssertTrue(pages[.vocal]?.byScore.isEmpty == true)
    }

    func testWeeklyMovementUsesRankDifferenceAndNewEntries() throws {
        let tracks = [makeTrack("A"), makeTrack("B"), makeTrack("C"), makeTrack("D")]
        let prefs = Dictionary(uniqueKeysWithValues: tracks.map {
            ($0.id, TrackPreference(trackID: $0.id, playbackPreference: 1, favorite: false))
        })
        let page = ArtistRankingService.pages(tracks: tracks, histories: [:], preferences: prefs,
                                             settings: jazzSettings())
        let rows = try XCTUnwrap(page[.instrumental]?.byScore)
        let changes = ArtistRankingService.movements(current: [rows[1], rows[0], rows[2], rows[3]],
                                                     previous: Array(rows.prefix(3)))
        XCTAssertEqual(changes["B"], .change(1))
        XCTAssertEqual(changes["A"], .change(-1))
        XCTAssertEqual(changes["C"], .change(0))
        XCTAssertEqual(changes["D"], .newEntry)
        XCTAssertEqual(ArtistRankingService.movements(current: rows, previous: []) ["A"], .newEntry)
        XCTAssertTrue(ArtistRankingService.movements(current: [], previous: rows).isEmpty)
    }

    @MainActor
    func testWeeklyStoreComparesPreviousWeekAndClearsComparisonForAllTime() async throws {
        let a = makeTrack("A"), b = makeTrack("B")
        let week = ArtistRankingService.week(containing: Date())
        func event(_ track: Track, _ start: Date, _ seconds: Double) -> PlaybackEvent {
            PlaybackEvent(trackID: track.id, startedAt: start, endedAt: start.addingTimeInterval(seconds),
                listenedSeconds: seconds, completionRatio: 0, wasSkipped: true,
                wasFullPlayback: false, startKind: .manual, startSource: .artist)
        }
        let histories = [
            a.id: PlaybackHistory(trackID: a.id, isFavorite: false, playCount: 3, lastPlayedAt: nil,
                playbackEvents: [event(a, week.start.addingTimeInterval(-86400), 100),
                                 event(a, week.start, 30)]),
            b.id: PlaybackHistory(trackID: b.id, isFavorite: false, playCount: 3, lastPlayedAt: nil,
                playbackEvents: [event(b, week.start.addingTimeInterval(-86400), 30),
                                 event(b, week.start, 100), event(b, week.start.addingTimeInterval(200), 30)])
        ]
        let store = ArtistRankingStore()
        var input = ArtistRankingInput(tracks: [a, b], histories: histories, preferences: [:],
                                       settings: jazzSettings(), week: week)
        await store.refresh(input)
        XCTAssertEqual(store.movements[.count]?["B"], .change(1))
        XCTAssertEqual(store.movements[.time]?["B"], .change(1))
        XCTAssertEqual(store.movements[.score]?["A"], .change(-1))
        input.week = nil
        await store.refresh(input)
        XCTAssertTrue(store.movements.isEmpty)
        XCTAssertNil(store.week)
    }

    func testWeeklyIgnoresPreferencesAndUsesFiftyThirtyTwentyWeights() throws {
        let a = makeTrack("A"), b = makeTrack("B"), unplayed = makeTrack("Unplayed")
        let week = ArtistRankingService.week(containing: Date())
        func event(_ track: Track, _ seconds: Double) -> PlaybackEvent {
            PlaybackEvent(trackID: track.id, startedAt: week.start, endedAt: week.start.addingTimeInterval(seconds),
                listenedSeconds: seconds, completionRatio: 0, wasSkipped: true,
                wasFullPlayback: false, startKind: .manual, startSource: .artist)
        }
        let histories = [
            a.id: PlaybackHistory(trackID: a.id, isFavorite: false, playCount: 2, lastPlayedAt: nil,
                playbackEvents: [event(a, 30), event(a, 30)]),
            b.id: PlaybackHistory(trackID: b.id, isFavorite: false, playCount: 1, lastPlayedAt: nil,
                playbackEvents: [event(b, 120)])
        ]
        let prefs = [unplayed.id: TrackPreference(trackID: unplayed.id, playbackPreference: 15, favorite: true)]
        let weekly = ArtistRankingService.pages(tracks: [a, b, unplayed], histories: histories,
            preferences: prefs, settings: jazzSettings(), week: week)
        let rows = try XCTUnwrap(weekly[.instrumental]?.byScore)
        XCTAssertEqual(rows.map(\.id), ["A", "B"])
        XCTAssertEqual(rows[0].score, 65 + 20.0 / 7, accuracy: 0.001)
        XCTAssertEqual(rows[1].score, 55 + 20.0 / 7, accuracy: 0.001)
        let withoutPreferences = ArtistRankingService.pages(tracks: [a, b, unplayed], histories: histories,
            preferences: [:], settings: jazzSettings(), week: week)
        XCTAssertEqual(weekly, withoutPreferences)
        let allTime = ArtistRankingService.pages(tracks: [a, b, unplayed], histories: histories,
            preferences: prefs, settings: jazzSettings())
        XCTAssertTrue(allTime[.instrumental]?.byScore.contains { $0.id == "Unplayed" && $0.score == 50 } == true)
    }

    func testWeeklyListeningDaysHaveSevenStepsAndDeduplicateAcrossTracks() throws {
        let a = makeTrack("A"), anotherA = makeTrack("A")
        let week = ArtistRankingService.week(containing: Date())
        func event(_ track: Track, day: Int, seconds: Double = 30) -> PlaybackEvent {
            let start = Calendar.current.date(byAdding: .day, value: day, to: week.start)!
            return PlaybackEvent(trackID: track.id, startedAt: start, endedAt: start.addingTimeInterval(seconds),
                listenedSeconds: seconds, completionRatio: 0, wasSkipped: true,
                wasFullPlayback: false, startKind: .manual, startSource: .artist)
        }
        for days in 1...7 {
            let events = (0..<days).map { event(a, day: $0) }
            let histories = [
                a.id: PlaybackHistory(trackID: a.id, isFavorite: false, playCount: 99, lastPlayedAt: nil,
                    playbackEvents: events + [event(a, day: 0), event(a, day: 7), event(a, day: -1)]),
                anotherA.id: PlaybackHistory(trackID: anotherA.id, isFavorite: false, playCount: 99, lastPlayedAt: nil,
                    playbackEvents: [event(anotherA, day: 0)] + (0..<7).map { event(anotherA, day: $0, seconds: 1) })
            ]
            let pages = ArtistRankingService.pages(tracks: [a, anotherA], histories: histories,
                preferences: [:], settings: ArtistRankingSettings(), week: week)
            let row = try XCTUnwrap(pages[.instrumental]?.byScore.first)
            XCTAssertEqual(row.listeningDays, days)
            XCTAssertEqual(row.dayPoints * 0.2, Double(days) / 7 * 20, accuracy: 0.001)
            XCTAssertEqual(row.score, 80 + Double(days) / 7 * 20, accuracy: 0.001)
        }
    }

    @MainActor
    func testWeeklyPeriodUsesJapaneseDateAndWeekday() throws {
        let start = try XCTUnwrap(Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 26)))
        let end = try XCTUnwrap(Calendar.current.date(byAdding: .day, value: 7, to: start))
        XCTAssertEqual(ArtistRankingFormatting.weekPeriod(DateInterval(start: start, end: end)),
                       "2026年10月26日（月）〜2026年11月1日（日）")
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
