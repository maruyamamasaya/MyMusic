import Foundation
import XCTest
@testable import MyMusic

@MainActor
final class PlaybackEventImportTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryDirectories { try? FileManager.default.removeItem(at: url) }
        temporaryDirectories.removeAll()
    }

    func testPreviewDoesNotSaveAndConfirmedImportIsIdempotentAndKeepsPlatform() async throws {
        let root = try temporaryDirectory()
        let persistence = PlaybackHistoryPersistenceService(applicationDirectory: root)
        let track = makeTrack(id: UUID(), title: "Night Drive", duration: 100)
        let oldEvent = PlaybackEvent(
            id: "ios-existing", trackID: track.id,
            startedAt: Date(timeIntervalSince1970: 1_799_900_000),
            endedAt: Date(timeIntervalSince1970: 1_799_900_030),
            listenedSeconds: 30, completionRatio: 0.3,
            wasSkipped: false, wasFullPlayback: false,
            startKind: .manual, startSource: .library
        )
        let original = PlaybackHistory(
            trackID: track.id, isFavorite: true, playCount: 4,
            firstPlayedAt: oldEvent.startedAt, lastPlayedAt: oldEvent.startedAt,
            playbackPreference: 7, playbackEvents: [oldEvent],
            boredomCount: 2, boredomHiddenUntil: oldEvent.startedAt.addingTimeInterval(500),
            isPermanentlyHiddenFromShuffle: true
        )
        try await persistence.save([original])
        let historyStore = PlaybackHistoryStore(persistence: persistence)
        await historyStore.loadIfNeeded()
        let importStore = PlaybackEventImportStore()
        let data = playbackJSON(events: [
            eventJSON(
                id: "mac-event-1", trackID: track.id, playedAt: "2027-01-15T08:00:00Z",
                playDuration: 95, trackDuration: 100, completed: true,
                skipped: false, source: "playlist", selection: "manual", platform: "macOS"
            )
        ])

        importStore.prepare(data: data, history: historyStore.entries, libraryTrackIDs: [track.id])
        XCTAssertEqual(importStore.state, .preview)
        XCTAssertEqual(importStore.preview?.pendingInsert, 1)
        let previewPersisted = try await persistence.load()
        XCTAssertEqual(previewPersisted.first?.playbackEvents.count, 1)

        await importStore.apply(to: historyStore)
        XCTAssertEqual(importStore.result?.inserted, 1)
        var persisted = try await persistence.load()
        var saved = try XCTUnwrap(persisted.first)
        XCTAssertEqual(saved.playbackEvents.count, 2)
        XCTAssertEqual(saved.playbackEvents.last?.platform, .macOS)
        XCTAssertEqual(saved.playbackEvents.last?.endedAt.timeIntervalSince(saved.playbackEvents.last!.startedAt), 95)
        XCTAssertEqual(saved.playCount, 5)
        XCTAssertEqual(saved.fullPlaybackCount, 1)
        XCTAssertEqual(saved.manualPlayCount, 1)
        XCTAssertEqual(saved.playbackSourceCounts["playlist"], 1)
        XCTAssertEqual(saved.isFavorite, true)
        XCTAssertEqual(saved.playbackPreference, 7)
        XCTAssertEqual(saved.boredomCount, 2)
        XCTAssertEqual(saved.isPermanentlyHiddenFromShuffle, true)
        XCTAssertEqual(saved.playbackEvents.first?.platform, .iOS)

        importStore.reset()
        importStore.prepare(data: data, history: historyStore.entries, libraryTrackIDs: [track.id])
        XCTAssertEqual(importStore.preview?.duplicate, 1)
        await importStore.apply(to: historyStore)
        XCTAssertEqual(importStore.result?.inserted, 0)
        XCTAssertEqual(importStore.result?.duplicate, 1)
        persisted = try await persistence.load()
        saved = try XCTUnwrap(persisted.first)
        XCTAssertEqual(saved.playbackEvents.count, 2)
        XCTAssertEqual(saved.playCount, 5)

        let exported = try MusicDataExportService().playbackEventsJSON(
            [track.id: saved], tracks: [track]
        )
        let rootObject = try XCTUnwrap(JSONSerialization.jsonObject(with: exported.data) as? [String: Any])
        let events = try XCTUnwrap(rootObject["events"] as? [[String: Any]])
        XCTAssertEqual(events.first { $0["eventId"] as? String == "mac-event-1" }?["platform"] as? String, "macOS")
        XCTAssertEqual(events.first { $0["eventId"] as? String == "ios-existing" }?["platform"] as? String, "iOS")
    }

    func testSelectedLocalDateRangeFiltersBeforePreviewAndImport() async throws {
        let root = try temporaryDirectory()
        let persistence = PlaybackHistoryPersistenceService(applicationDirectory: root)
        let track = makeTrack(id: UUID(), title: "Date Range", duration: 100)
        let historyStore = PlaybackHistoryStore(persistence: persistence)
        await historyStore.loadIfNeeded()
        let importStore = PlaybackEventImportStore()
        let calendar = Calendar.current
        let selectedDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2027, month: 1, day: 15))
        )
        let nextDay = try XCTUnwrap(calendar.date(byAdding: .day, value: 1, to: selectedDay))
        let formatter = ISO8601DateFormatter()
        let data = playbackJSON(events: [
            eventJSON(id: "before", trackID: track.id,
                      playedAt: formatter.string(from: selectedDay.addingTimeInterval(-1)),
                      playDuration: 50, trackDuration: 100, completed: false, skipped: false,
                      source: "library", selection: "manual", platform: "macOS"),
            eventJSON(id: "selected", trackID: track.id,
                      playedAt: formatter.string(from: selectedDay.addingTimeInterval(12 * 60 * 60)),
                      playDuration: 50, trackDuration: 100, completed: false, skipped: false,
                      source: "library", selection: "manual", platform: "macOS"),
            eventJSON(id: "after", trackID: track.id,
                      playedAt: formatter.string(from: nextDay),
                      playDuration: 50, trackDuration: 100, completed: false, skipped: false,
                      source: "library", selection: "manual", platform: "macOS")
        ])

        importStore.prepare(data: data, history: [:], libraryTrackIDs: [track.id])
        importStore.updatePeriod(from: selectedDay, through: selectedDay)

        XCTAssertEqual(importStore.sourceEventCount, 3)
        XCTAssertEqual(importStore.preview?.total, 1)
        XCTAssertEqual(importStore.preview?.details.map(\.id), ["selected"])

        await importStore.apply(to: historyStore)
        XCTAssertEqual(importStore.result?.total, 1)
        XCTAssertEqual(importStore.result?.inserted, 1)
        let persisted = try await persistence.load()
        XCTAssertEqual(persisted.first?.playbackEvents.map(\.id), ["selected"])
    }

    func testAggregationUsesPlayThresholdKindsSourcesAndDailySummary() async throws {
        let root = try temporaryDirectory()
        let persistence = PlaybackHistoryPersistenceService(applicationDirectory: root)
        let track = makeTrack(id: UUID(), title: "Aggregate", duration: 100)
        let historyStore = PlaybackHistoryStore(persistence: persistence)
        await historyStore.loadIfNeeded()
        let importStore = PlaybackEventImportStore()
        let data = playbackJSON(events: [
            eventJSON(id: "manual-full", trackID: track.id, playedAt: "2027-01-15T08:00:00Z",
                      playDuration: 95, trackDuration: 100, completed: true, skipped: false,
                      source: "playlist", selection: "manual", platform: "macOS"),
            eventJSON(id: "advanced-skip", trackID: track.id, playedAt: "2027-01-15T09:00:00Z",
                      playDuration: 10, trackDuration: 100, completed: false, skipped: true,
                      source: "search", selection: "user_advanced", platform: "macOS"),
            eventJSON(id: "automatic-play", trackID: track.id, playedAt: "2027-01-15T10:00:00Z",
                      playDuration: 50, trackDuration: 100, completed: false, skipped: false,
                      source: "shuffle", selection: "automatic", platform: "macOS")
        ])
        importStore.prepare(data: data, history: [:], libraryTrackIDs: [track.id])
        await importStore.apply(to: historyStore)

        let persisted = try await persistence.load()
        let saved = try XCTUnwrap(persisted.first)
        XCTAssertEqual(saved.playCount, 2)
        XCTAssertEqual(saved.manualPlayCount, 2)
        XCTAssertEqual(saved.automaticPlayCount, 1)
        XCTAssertEqual(saved.fullPlaybackCount, 1)
        XCTAssertEqual(saved.skipCount, 1)
        XCTAssertEqual(saved.totalPlaybackDuration, 155)
        XCTAssertEqual(saved.playbackSourceCounts, ["playlist": 1, "search": 1, "shuffle": 1])
        let summary = try XCTUnwrap(saved.dailySummaries.values.first)
        XCTAssertEqual(summary.playCount, 3)
        XCTAssertEqual(summary.manualPlayCount, 2)
        XCTAssertEqual(summary.automaticPlayCount, 1)
        XCTAssertEqual(summary.fullPlaybackCount, 1)
        XCTAssertEqual(summary.skipCount, 1)
        XCTAssertEqual(summary.sourceCounts, ["playlist": 1, "search": 1, "shuffle": 1])
    }

    func testUnknownTrackIsPreviewedButNotSaved() async throws {
        let root = try temporaryDirectory()
        let persistence = PlaybackHistoryPersistenceService(applicationDirectory: root)
        let historyStore = PlaybackHistoryStore(persistence: persistence)
        await historyStore.loadIfNeeded()
        let missingID = UUID()
        let importStore = PlaybackEventImportStore()
        let data = playbackJSON(events: [
            eventJSON(id: "missing", trackID: missingID, playedAt: "2027-01-15T08:00:00Z",
                      playDuration: 10, trackDuration: 100, completed: false, skipped: false,
                      source: "library", selection: "manual", platform: "macOS")
        ])
        importStore.prepare(data: data, history: [:], libraryTrackIDs: [])
        XCTAssertEqual(importStore.preview?.unresolved, 1)
        await importStore.apply(to: historyStore)
        XCTAssertEqual(importStore.result?.unresolved, 1)
        let persisted = try await persistence.load()
        XCTAssertEqual(persisted, [])
    }

    func testStrictValidationRejectsDuplicateUnknownFieldAndCompletionContradictions() throws {
        let service = PlaybackEventImportService()
        let trackID = UUID()
        let event = eventJSON(
            id: "duplicate", trackID: trackID, playedAt: "2027-01-15T08:00:00Z",
            playDuration: 10, trackDuration: 100, completed: false, skipped: false,
            source: "library", selection: "manual", platform: "macOS"
        )
        XCTAssertThrowsError(try service.parse(data: playbackJSON(events: [event, event]))) {
            XCTAssertEqual($0 as? PlaybackEventImportError, .duplicateEventID("duplicate"))
        }
        var unknown = event
        unknown["futureField"] = true
        XCTAssertThrowsError(try service.parse(data: playbackJSON(events: [unknown])))

        let inconsistent = eventJSON(
            id: "bad-completed", trackID: trackID, playedAt: "2027-01-15T08:00:00Z",
            playDuration: 94, trackDuration: 100, completed: false, skipped: false,
            source: "library", selection: "manual", platform: "macOS"
        )
        XCTAssertThrowsError(try service.parse(data: playbackJSON(events: [inconsistent]))) {
            XCTAssertEqual($0 as? PlaybackEventImportError, .inconsistentCompletion(index: 0))
        }
        let both = eventJSON(
            id: "bad-flags", trackID: trackID, playedAt: "2027-01-15T08:00:00Z",
            playDuration: 95, trackDuration: 100, completed: true, skipped: true,
            source: "library", selection: "manual", platform: "macOS"
        )
        XCTAssertThrowsError(try service.parse(data: playbackJSON(events: [both])))
    }

    func testRepositoryRollsBackWholeImportOnFailure() throws {
        let root = try temporaryDirectory()
        let databaseURL = root.appending(path: "playback-history.sqlite3")
        struct Injected: Error {}
        let repository = PlaybackHistorySQLiteRepository(
            databaseURL: databaseURL,
            importFailureInjector: { writeCount in if writeCount == 1 { throw Injected() } }
        )
        try repository.recreateEmptyDatabase()
        let firstID = UUID()
        let secondID = UUID()
        let originalFirst = PlaybackHistory(trackID: firstID, isFavorite: true, playCount: 2, lastPlayedAt: nil)
        let originalSecond = PlaybackHistory(trackID: secondID, isFavorite: false, playCount: 3, lastPlayedAt: nil)
        try repository.replaceAll(with: [originalFirst, originalSecond])
        let candidates = [
            candidate(id: "first", trackID: firstID),
            candidate(id: "second", trackID: secondID)
        ]

        XCTAssertThrowsError(try repository.importPlaybackEvents(candidates))
        let reloaded = Dictionary(uniqueKeysWithValues: try repository.loadAll().map { ($0.trackID, $0) })
        XCTAssertEqual(reloaded[firstID]?.playCount, 2)
        XCTAssertEqual(reloaded[secondID]?.playCount, 3)
        XCTAssertEqual(reloaded[firstID]?.playbackEvents, [])
        XCTAssertEqual(reloaded[secondID]?.playbackEvents, [])
    }

    func testLegacyPlaybackEventJSONDefaultsPlatformToIOS() throws {
        let trackID = UUID()
        let json = """
        {"id":"legacy","trackID":"\(trackID.uuidString)","startedAt":0,"endedAt":1,
         "listenedSeconds":1,"completionRatio":0.1,"wasSkipped":false,"wasFullPlayback":false,
         "startKind":"manual","startSource":"library"}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let event = try decoder.decode(PlaybackEvent.self, from: Data(json.utf8))
        XCTAssertEqual(event.platform, .iOS)
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        temporaryDirectories.append(url)
        return url
    }

    private func makeTrack(id: UUID, title: String, duration: TimeInterval) -> Track {
        Track(
            id: id, title: title, artistName: "Artist", duration: duration,
            fileURL: URL(fileURLWithPath: "/tmp/\(title).m4a"),
            relativePath: "Album/\(title).m4a", fileSize: 1_024
        )
    }

    private func candidate(id: String, trackID: UUID) -> PlaybackEventImportCandidate {
        let event = PlaybackEvent(
            id: id, trackID: trackID,
            startedAt: Date(timeIntervalSince1970: 1_800_000_000),
            endedAt: Date(timeIntervalSince1970: 1_800_000_050),
            listenedSeconds: 50, completionRatio: 0.5,
            wasSkipped: false, wasFullPlayback: false,
            startKind: .manual, startSource: .library, platform: .macOS
        )
        return PlaybackEventImportCandidate(
            event: event, trackDuration: 100,
            trackTitle: "Track", artist: "Artist", album: nil
        )
    }

    private func eventJSON(
        id: String,
        trackID: UUID,
        playedAt: String,
        playDuration: Double,
        trackDuration: Double,
        completed: Bool,
        skipped: Bool,
        source: String,
        selection: String,
        platform: String
    ) -> [String: Any] {
        [
            "eventId": id, "trackId": trackID.uuidString,
            "trackTitle": "Night Drive", "artist": "Sample Artist", "album": "Midnight",
            "playedAt": playedAt, "playDuration": playDuration, "trackDuration": trackDuration,
            "completed": completed, "skipped": skipped, "playSource": source,
            "selectionType": selection, "platform": platform, "schemaVersion": 1
        ]
    }

    private func playbackJSON(events: [[String: Any]]) -> Data {
        try! JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1,
            "exportedAt": "2027-01-15T12:00:00Z",
            "events": events
        ], options: [.sortedKeys])
    }
}
