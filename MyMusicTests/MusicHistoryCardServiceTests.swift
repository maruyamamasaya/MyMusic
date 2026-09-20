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

    private func queue(_ card: MusicHistoryCardCandidate, available: [Track],
                       playable: (Track) -> Bool = { _ in true }) -> [Track] {
        MusicHistoryCardService().tracksForPlayback(card, availableTracks: available, isPlayable: playable)
    }

    private func manualCard(_ representative: Track, ids: [Track.ID]) -> MusicHistoryCardCandidate {
        MusicHistoryCardCandidate(type: .monthTrack, title: "Test", subtitle: "Test", priority: 1,
                                  score: 1, tracks: [representative], playbackTrackIDs: ids,
                                  artistNames: [], albumTitle: nil, date: nil, validUntil: date(2026, 10, 1))
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

    func testQueueCapsAtTenDeduplicatesAndResolvesCurrentLibrary() {
        let songs = (0..<14).map { track("Queue\($0)") }
        let ids = [songs[0].id, songs[0].id] + songs.dropFirst().map(\.id)
        let card = manualCard(songs[0], ids: ids)
        let refreshed = Track(id: songs[0].id, title: "Renamed", artistName: "Artist",
                              duration: 180, fileURL: songs[0].fileURL)
        let resolved = queue(card, available: [refreshed] + Array(songs.dropFirst()))
        XCTAssertEqual(resolved.count, 10)
        XCTAssertEqual(resolved.first?.id, songs[0].id)
        XCTAssertEqual(resolved.first?.title, "Renamed")
        XCTAssertEqual(Set(resolved.map(\.id)).count, 10)
    }

    func testQueueOmitsDeletedAndUnreadableTracksAndCanBeEmpty() {
        let songs = (0..<4).map { track("Unavailable\($0)") }
        let card = manualCard(songs[0], ids: songs.map(\.id))
        let resolved = queue(card, available: [songs[0], songs[2], songs[3]]) { $0.id != songs[2].id }
        XCTAssertEqual(resolved.map(\.id), [songs[0].id, songs[3].id])
        XCTAssertTrue(queue(card, available: []).isEmpty)
        XCTAssertTrue(queue(card, available: songs) { _ in false }.isEmpty)
    }

    func testPlaybackServiceChecksFilesImmediatelyBeforeQueueCreation() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let presentURL = folder.appendingPathComponent("present.m4a")
        try Data([0]).write(to: presentURL)
        let present = Track(id: UUID(), title: "Present", artistName: "Artist", duration: 180, fileURL: presentURL)
        let missing = Track(id: UUID(), title: "Missing", artistName: "Artist", duration: 180,
                            fileURL: folder.appendingPathComponent("missing.m4a"))
        let card = manualCard(present, ids: [present.id, missing.id])
        let service = MusicHistoryCardPlaybackService()
        XCTAssertEqual(service.tracksForPlayback(card, availableTracks: [present, missing]).map(\.id), [present.id])
        try FileManager.default.removeItem(at: presentURL)
        XCTAssertTrue(service.tracksForPlayback(card, availableTracks: [present, missing]).isEmpty)
    }

    func testYearAgoQueueUsesExactThenNearbyDays() throws {
        let exact = track("Exact")
        let oneDay = track("OneDay")
        let threeDays = track("ThreeDays")
        let result = cards([exact, oneDay, threeDays], [
            history(exact, [date(2025, 9, 20)]),
            history(oneDay, [date(2025, 9, 19), date(2025, 9, 19, 14)]),
            history(threeDays, [date(2025, 9, 23), date(2025, 9, 23, 14), date(2025, 9, 23, 16)])
        ], now: date(2026, 9, 20))
        let card = try XCTUnwrap(result.first { $0.type == .yearAgo })
        XCTAssertEqual(queue(card, available: [exact, oneDay, threeDays]).map(\.id),
                       [exact.id, oneDay.id, threeDays.id])
    }

    func testMonthTopQueueUsesPlayCountAndTenTrackLimit() throws {
        let songs = (0..<12).map { track("Month\($0)") }
        let histories = songs.enumerated().map { offset, song in
            history(song, Array(repeating: date(2026, 9, 1), count: offset + 1))
        }
        let card = try XCTUnwrap(cards(songs, histories, now: date(2026, 9, 20))
            .first { $0.type == .monthTrack })
        XCTAssertEqual(queue(card, available: songs).map(\.id), Array(songs.reversed().prefix(10)).map(\.id))
    }

    func testNewTrackAndArtistQueuesStayInTheirDiscoveryContext() throws {
        let old = track("Old", artist: "Established")
        let fresh = (0..<4).map { track("Fresh\($0)", artist: "New") }
        let all = [old] + fresh
        let histories = [history(old, [date(2025, 12, 1)] + Array(repeating: date(2026, 1, 2), count: 8))]
            + fresh.map { history($0, [date(2026, 1, 2), date(2026, 1, 3)]) }
        let result = cards(all, histories, now: date(2026, 1, 4))
        let newTrack = try XCTUnwrap(result.first { $0.type == .newTrack })
        let newArtist = try XCTUnwrap(result.first { $0.type == .newArtist })
        XCTAssertEqual(queue(newTrack, available: all).count, 4)
        XCTAssertFalse(queue(newTrack, available: all).contains { $0.id == old.id })
        XCTAssertEqual(queue(newArtist, available: all).count, 4)
        XCTAssertTrue(queue(newArtist, available: all).allSatisfy { $0.artistName == "New" })
    }

    func testRediscoveredAndNightQueuesContainOnlyMatchingTracks() throws {
        let returned = (0..<3).map { track("Returned\($0)") }
        let night = (0..<3).map { track("NightQueue\($0)") }
        let day = track("DayOnly")
        let histories = returned.enumerated().map { offset, song in
            history(song, [date(2025, 1, 1), date(2025, 1, 2), date(2025, 1, 3),
                           date(2026, 9, 10 + offset), date(2026, 9, 14 + offset)])
        } + night.enumerated().map { offset, song in
            history(song, [date(2026, 8, 1 + offset, 22), date(2026, 8, 2 + offset, 4, 59),
                           date(2026, 8, 3 + offset, 23), date(2026, 8, 4 + offset, 1),
                           date(2026, 8, 5 + offset, 12)])
        } + [history(day, (1...6).map { date(2026, 8, $0, 12) })]
        let all = returned + night + [day]
        let result = cards(all, histories, now: date(2026, 9, 20))
        let rediscovered = try XCTUnwrap(result.first { $0.type == .rediscovered })
        let nightCard = try XCTUnwrap(result.first { $0.type == .night })
        XCTAssertEqual(queue(rediscovered, available: all).count, 3)
        XCTAssertTrue(queue(rediscovered, available: all).allSatisfy { returned.map(\.id).contains($0.id) })
        XCTAssertEqual(queue(nightCard, available: all).count, 3)
        XCTAssertTrue(queue(nightCard, available: all).allSatisfy { night.map(\.id).contains($0.id) })
    }

    func testAlbumQueueContainsOnlyPlayedAlbumTracks() throws {
        let album = (0..<4).map { track("Album\($0)", album: "Collection") }
        let other = track("Other", album: "Elsewhere")
        let histories = album.map { history($0, [date(2026, 8, 1), date(2026, 9, 3), date(2026, 9, 4)]) }
            + [history(other, [date(2026, 8, 1)] + Array(repeating: date(2026, 9, 3), count: 10))]
        let result = cards(album + [other], histories, now: date(2026, 9, 20))
        let card = try XCTUnwrap(result.first { $0.type == .monthAlbum })
        XCTAssertEqual(queue(card, available: album + [other]).count, 4)
        XCTAssertTrue(queue(card, available: album + [other]).allSatisfy { $0.albumTitle == "Collection" })
    }

    func testFeatureQueueUsesOnlyFeaturedTracksPlayedThisMonth() throws {
        let featured = (0..<6).map { track("Featured\($0)") }
        let baseline = (0..<5).map { track("BaselineQueue\($0)") }
        let unfeatured = track("Unfeatured")
        let all = featured + baseline + [unfeatured]
        let features = Dictionary(uniqueKeysWithValues: (featured + baseline).map { song in
            (song.id, feature(song, calm: featured.contains(where: { $0.id == song.id }) ? 0.9 : 0.1))
        })
        let histories = featured.map { history($0, [date(2026, 9, 1), date(2026, 9, 2)]) }
            + [history(unfeatured, Array(repeating: date(2026, 9, 2), count: 12))]
        let result = cards(all, histories, now: date(2026, 9, 20), features: features)
        let card = try XCTUnwrap(result.first { $0.type == .monthSound })
        let resolved = queue(card, available: all)
        XCTAssertEqual(resolved.count, 6)
        XCTAssertTrue(resolved.allSatisfy { featured.map(\.id).contains($0.id) })
    }

    func testLongTermAndRecurringQueuesUseOnlyQualifiedTracks() throws {
        let long = (0..<2).map { track("LongQueue\($0)") }
        let recurring = (0..<2).map { track("RecurringQueue\($0)") }
        let longDates = [date(2025, 12, 10), date(2026, 1, 10), date(2026, 2, 10),
                         date(2026, 3, 10), date(2026, 4, 10), date(2026, 5, 10),
                         date(2026, 6, 10), date(2026, 7, 10), date(2026, 8, 10), date(2026, 9, 19)]
        let recurringDates = [date(2026, 1, 10), date(2026, 2, 10), date(2026, 3, 10),
                              date(2026, 4, 10), date(2026, 5, 10), date(2026, 6, 10)]
        let all = long + recurring
        let result = cards(all, long.map { history($0, longDates) } + recurring.map { history($0, recurringDates) },
                           now: date(2026, 9, 20))
        let longCard = try XCTUnwrap(result.first { $0.type == .longTerm })
        let recurringCard = try XCTUnwrap(result.first { $0.type == .recurring })
        XCTAssertEqual(queue(longCard, available: all).count, 2)
        XCTAssertTrue(queue(longCard, available: all).allSatisfy { long.map(\.id).contains($0.id) })
        XCTAssertGreaterThanOrEqual(queue(recurringCard, available: all).count, 2)
        XCTAssertEqual(queue(recurringCard, available: all).first?.id, recurringCard.mainTrack?.id)
    }

    func testShuffleQueueExcludesUnknownInitialSource() throws {
        let discovered = (0..<3).map { track("Discovered\($0)") }
        let unknown = track("UnknownQueue")
        let dates = [1, 2, 3, 4].map { date(2026, 8, $0) }
        let kinds: [PlaybackStartKind] = [.automatic, .manual, .manual, .automatic]
        let histories = discovered.enumerated().map { offset, song in
            history(song, dates, kinds: kinds, sources: [offset == 0 ? .shuffle : .station,
                                                          .search, .library, .shuffle])
        } + [history(unknown, dates, kinds: kinds)]
        let prefs = Dictionary(uniqueKeysWithValues: discovered.map {
            ($0.id, TrackPreference(trackID: $0.id, playbackPreference: 1, favorite: false))
        })
        let all = discovered + [unknown]
        let card = try XCTUnwrap(cards(all, histories, now: date(2026, 9, 20), preferences: prefs)
            .first { $0.type == .shuffleDiscovery })
        XCTAssertEqual(queue(card, available: all).count, 3)
        XCTAssertFalse(queue(card, available: all).contains { $0.id == unknown.id })
    }

    func testBusiestDayQueueContainsThatDaysTracksOnly() throws {
        let peak = (0..<5).map { track("Peak\($0)") }
        let other = track("OtherDay")
        let histories = peak.enumerated().map { offset, song in
            history(song, [date(2026, 8, 1)] + Array(repeating: date(2026, 9, 14), count: offset + 1))
        } + [history(other, [date(2026, 8, 1), date(2026, 9, 15)])]
        let all = peak + [other]
        let card = try XCTUnwrap(cards(all, histories, now: date(2026, 9, 20))
            .first { $0.type == .busiestDay })
        let resolved = queue(card, available: all)
        XCTAssertEqual(resolved.count, 5)
        XCTAssertFalse(resolved.contains { $0.id == other.id })
        XCTAssertEqual(resolved.first?.id, card.mainTrack?.id)
    }

    func testHistoryStartContextAndQueuePreparationDoNotMutateSources() throws {
        let a = track("SourceA")
        let b = track("SourceB")
        let historyA = history(a, [date(2026, 9, 1), date(2026, 9, 2)])
        let historyB = history(b, [date(2026, 9, 1)])
        let histories = [a.id: historyA, b.id: historyB]
        let playlist = Playlist(id: UUID(), name: "Saved", trackIDs: [b.id, a.id],
                                createdAt: date(2026, 9, 1), updatedAt: date(2026, 9, 1))
        let originalPlaylist = playlist
        let card = try XCTUnwrap(cards([a, b], [historyA, historyB], now: date(2026, 9, 20))
            .first { $0.type == .monthTrack })
        _ = queue(card, available: [a, b])
        XCTAssertEqual(MusicHistoryCardService.playbackStartContext.kind, .manual)
        XCTAssertEqual(MusicHistoryCardService.playbackStartContext.source, .history)
        XCTAssertEqual(histories[a.id], historyA)
        XCTAssertEqual(histories[b.id], historyB)
        XCTAssertEqual(playlist, originalPlaylist)
    }
}
