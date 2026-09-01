import Foundation
import SQLite3
import XCTest
@testable import MyMusic

final class PlaybackHistorySQLitePersistenceTests: XCTestCase {
    private var temporaryDirectories: [URL] = []

    override func tearDownWithError() throws {
        for url in temporaryDirectories { try? FileManager.default.removeItem(at: url) }
        temporaryDirectories.removeAll()
    }

    func testNewUserCreatesVerifiedSQLiteWithoutLegacyJSON() async throws {
        let root = try temporaryDirectory()
        let service = PlaybackHistoryPersistenceService(applicationDirectory: root)

        let loaded = try await service.load()
        XCTAssertEqual(loaded, [])
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appending(path: "playback-history.sqlite3").path))
        XCTAssertEqual(try migrationState(in: root), .verified)
    }

    func testLegacyJSONMigratesEveryFieldAndPreservesOriginalAndPermanentCopy() async throws {
        let root = try temporaryDirectory()
        let originalURL = root.appending(path: "playback-history.json")
        let source = [completeHistory()]
        let originalData = try encoded(source)
        try originalData.write(to: originalURL)
        let service = PlaybackHistoryPersistenceService(applicationDirectory: root)

        let imported = try await service.load()

        XCTAssertNoThrow(try PlaybackHistoryMigrationValidator.validate(source: source, imported: imported))
        XCTAssertEqual(try Data(contentsOf: originalURL), originalData)
        XCTAssertEqual(
            try Data(contentsOf: root.appending(path: "Backups/Migration/playback-history-pre-sqlite.json")),
            originalData
        )
        XCTAssertEqual(try migrationState(in: root), .verified)
    }

    func testCorruptJSONFailsClosedAndLeavesOriginalUntouched() async throws {
        let root = try temporaryDirectory()
        let originalURL = root.appending(path: "playback-history.json")
        let corrupt = Data("not-json".utf8)
        try corrupt.write(to: originalURL)
        let service = PlaybackHistoryPersistenceService(applicationDirectory: root)

        do {
            _ = try await service.load()
            XCTFail("Corrupt legacy JSON must not activate SQLite")
        } catch {}

        XCTAssertEqual(try Data(contentsOf: originalURL), corrupt)
        XCTAssertEqual(try Data(contentsOf: root.appending(path: "Backups/Migration/playback-history-pre-sqlite.json")), corrupt)
        XCTAssertEqual(try migrationState(in: root), .failed)
    }

    func testUnverifiedLeftoverDatabaseIsRebuiltFromJSONOnNextLaunch() async throws {
        let root = try temporaryDirectory()
        let source = [completeHistory()]
        try encoded(source).write(to: root.appending(path: "playback-history.json"))
        try Data(#"{"state":"in_progress","updatedAt":"2026-09-01T00:00:00Z"}"#.utf8)
            .write(to: root.appending(path: "playback-history-migration-state.json"))
        try Data("incomplete database".utf8).write(to: root.appending(path: "playback-history.sqlite3"))

        let imported = try await PlaybackHistoryPersistenceService(applicationDirectory: root).load()

        XCTAssertNoThrow(try PlaybackHistoryMigrationValidator.validate(source: source, imported: imported))
        XCTAssertEqual(try migrationState(in: root), .verified)
    }

    func testVerifiedStoreUsesDifferentialTrackUpsert() async throws {
        let root = try temporaryDirectory()
        let service = PlaybackHistoryPersistenceService(applicationDirectory: root)
        _ = try await service.load()
        var first = completeHistory()
        let second = PlaybackHistory(trackID: UUID(), isFavorite: true, playCount: 1, lastPlayedAt: .now)
        try await service.save([first, second])
        first.playCount = 99
        try await service.save(first)

        let reloaded = try await service.load()
        XCTAssertEqual(reloaded.first { $0.trackID == first.trackID }?.playCount, 99)
        let reloadedSecond = try XCTUnwrap(reloaded.first { $0.trackID == second.trackID })
        var normalizedReloadedSecond = reloadedSecond
        normalizedReloadedSecond.lastPlayedAt = second.lastPlayedAt
        XCTAssertEqual(normalizedReloadedSecond, second)
        XCTAssertEqual(
            try XCTUnwrap(reloadedSecond.lastPlayedAt).timeIntervalSince1970,
            try XCTUnwrap(second.lastPlayedAt).timeIntervalSince1970,
            accuracy: 0.001
        )
    }

    func testDailyBackupRunsOnceWithinTwentyFourHours() async throws {
        let root = try temporaryDirectory()
        let instant = Date(timeIntervalSince1970: 1_788_220_800)
        let service = PlaybackHistoryPersistenceService(applicationDirectory: root, now: { instant })
        _ = try await service.load()
        _ = try await service.load()

        let daily = root.appending(path: "Backups/Daily")
        let files = try FileManager.default.contentsOfDirectory(at: daily, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
        XCTAssertEqual(files.count, 1)
    }

    func testPlaybackEventRoundTripsAndOrdinaryUpsertDoesNotDuplicateIt() async throws {
        let root = try temporaryDirectory()
        let service = PlaybackHistoryPersistenceService(applicationDirectory: root)
        _ = try await service.load()
        let trackID = UUID()
        let startedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let event = PlaybackEvent(
            trackID: trackID, startedAt: startedAt, endedAt: startedAt.addingTimeInterval(24),
            listenedSeconds: 24, completionRatio: 0.2, wasSkipped: true, wasFullPlayback: false,
            startKind: .manual, startSource: .search, endKind: .userSkipped
        )
        var history = PlaybackHistory(trackID: trackID, isFavorite: true, playCount: 1,
                                      lastPlayedAt: startedAt, playbackPreference: 5,
                                      playbackEvents: [event], boredomCount: 2)
        try await service.save(history)
        history.playbackPreference = 6
        try await service.save(history)

        let loaded = try await service.load()
        let reloaded = try XCTUnwrap(loaded.first)
        XCTAssertEqual(reloaded.playbackEvents, [event])
        XCTAssertEqual(reloaded.playbackPreference, 6)
    }

    func testVerifiedVersionTwoDatabaseMigratesEndKindColumnToVersionThree() async throws {
        let root = try temporaryDirectory()
        do {
            let service = PlaybackHistoryPersistenceService(applicationDirectory: root)
            _ = try await service.load()
        }
        let databaseURL = root.appending(path: "playback-history.sqlite3")
        try executeSQL("ALTER TABLE playback_events DROP COLUMN end_kind; PRAGMA user_version = 2", at: databaseURL)

        _ = try await PlaybackHistoryPersistenceService(applicationDirectory: root).load()

        XCTAssertEqual(try scalarInt("PRAGMA user_version", at: databaseURL), 3)
        XCTAssertEqual(try scalarInt(
            "SELECT count(*) FROM pragma_table_info('playback_events') WHERE name = 'end_kind'",
            at: databaseURL
        ), 1)
    }

    private func completeHistory() -> PlaybackHistory {
        let trackID = UUID()
        let first = Date(timeIntervalSince1970: 1_700_000_000)
        let last = first.addingTimeInterval(300)
        return PlaybackHistory(
            trackID: trackID, isFavorite: true, playCount: 7,
            firstPlayedAt: first, lastPlayedAt: last, playbackPreference: -3,
            playbackEvents: [
                PlaybackEvent(trackID: trackID, startedAt: first, endedAt: first, listenedSeconds: 0,
                              completionRatio: 0, wasSkipped: false, wasFullPlayback: false,
                              startKind: .manual, startSource: .unknown),
                PlaybackEvent(trackID: trackID, startedAt: last, endedAt: last, listenedSeconds: 0,
                              completionRatio: 0, wasSkipped: false, wasFullPlayback: false,
                              startKind: .manual, startSource: .unknown)
            ],
            dailySummaries: ["2023-11-14": PlaybackDailySummary(
                playCount: 2, manualPlayCount: 1, automaticPlayCount: 1,
                sourceCounts: [PlaybackStartSource.search.rawValue: 1, PlaybackStartSource.station.rawValue: 1]
            )],
            manualPlayCount: 4, automaticPlayCount: 3,
            playbackSourceCounts: [PlaybackStartSource.search.rawValue: 4, PlaybackStartSource.shuffle.rawValue: 3],
            totalPlaybackDuration: 1234.5, skipCount: 2, fullPlaybackCount: 5,
            consecutivePlayCount: 3, repeatPlaybackCount: 2, boredomCount: 2,
            boredomHiddenUntil: last.addingTimeInterval(86_400), isPermanentlyHiddenFromShuffle: true
        )
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        temporaryDirectories.append(url)
        return url
    }

    private func encoded(_ entries: [PlaybackHistory]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(entries)
    }

    private func migrationState(in root: URL) throws -> PlaybackHistoryMigrationState {
        struct State: Decodable { let state: PlaybackHistoryMigrationState }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(
            State.self,
            from: Data(contentsOf: root.appending(path: "playback-history-migration-state.json"))
        ).state
    }

    private func executeSQL(_ sql: String, at databaseURL: URL) throws {
        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK, let database else {
            throw NSError(domain: "SQLiteTest", code: 1)
        }
        defer { sqlite3_close(database) }
        guard sqlite3_exec(database, sql, nil, nil, nil) == SQLITE_OK else {
            throw NSError(domain: "SQLiteTest", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: String(cString: sqlite3_errmsg(database))])
        }
    }

    private func scalarInt(_ sql: String, at databaseURL: URL) throws -> Int {
        var database: OpaquePointer?
        guard sqlite3_open(databaseURL.path, &database) == SQLITE_OK, let database else {
            throw NSError(domain: "SQLiteTest", code: 3)
        }
        defer { sqlite3_close(database) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw NSError(domain: "SQLiteTest", code: 4)
        }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { throw NSError(domain: "SQLiteTest", code: 5) }
        return Int(sqlite3_column_int64(statement, 0))
    }
}
