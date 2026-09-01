import Foundation
import SQLite3

enum PlaybackHistorySQLiteError: LocalizedError {
    case open(String)
    case execute(String)
    case bind(String)
    case read(String)
    case unverifiedSchema

    var errorDescription: String? {
        switch self {
        case let .open(message): "Unable to open playback history database: \(message)"
        case let .execute(message): "Playback history SQL failed: \(message)"
        case let .bind(message): "Playback history SQL binding failed: \(message)"
        case let .read(message): "Playback history SQL read failed: \(message)"
        case .unverifiedSchema: "Playback history database is not marked as verified"
        }
    }
}

/// Synchronous SQLite boundary used only from the owning persistence actor.
/// Child rows are normalized rather than embedded JSON, and each track upsert is one transaction.
nonisolated final class PlaybackHistorySQLiteRepository: @unchecked Sendable {
    private let databaseURL: URL
    private let fileManager: FileManager
    private var database: OpaquePointer?
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    init(databaseURL: URL, fileManager: FileManager = .default) {
        self.databaseURL = databaseURL
        self.fileManager = fileManager
    }

    deinit { close() }

    func recreateEmptyDatabase() throws {
        close()
        for suffix in ["", "-wal", "-shm"] {
            let url = URL(fileURLWithPath: databaseURL.path + suffix)
            if fileManager.fileExists(atPath: url.path) { try fileManager.removeItem(at: url) }
        }
        try open()
        try createSchema()
    }

    func openAndValidateVerifiedSchema() throws {
        try open()
        let statement = try prepare("SELECT value FROM playback_metadata WHERE key = 'migration_state'")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW,
              text(statement, 0) == PlaybackHistoryMigrationState.verified.rawValue else {
            throw PlaybackHistorySQLiteError.unverifiedSchema
        }
    }

    func markMigrationVerified() throws {
        try execute("INSERT OR REPLACE INTO playback_metadata(key, value) VALUES('migration_state', 'verified')")
    }

    func replaceAll(with entries: [PlaybackHistory]) throws {
        try open()
        try transaction {
            try execute("DELETE FROM playback_tracks")
            for entry in entries { try write(entry) }
        }
    }

    func upsert(_ entry: PlaybackHistory) throws {
        try open()
        try transaction { try write(entry) }
    }

    func loadAll() throws -> [PlaybackHistory] {
        try open()
        var entries: [UUID: PlaybackHistory] = [:]
        let tracks = try prepare("""
            SELECT track_id, is_favorite, play_count, first_played_at, last_played_at,
                   playback_preference, manual_play_count, automatic_play_count,
                   total_playback_duration, skip_count, full_playback_count,
                   consecutive_play_count, repeat_playback_count, boredom_count,
                   boredom_hidden_until, is_permanently_hidden_from_shuffle
            FROM playback_tracks
            """)
        defer { sqlite3_finalize(tracks) }
        while sqlite3_step(tracks) == SQLITE_ROW {
            guard let id = UUID(uuidString: text(tracks, 0)) else {
                throw PlaybackHistorySQLiteError.read("invalid track UUID")
            }
            entries[id] = PlaybackHistory(
                trackID: id,
                isFavorite: int(tracks, 1) != 0,
                playCount: int(tracks, 2),
                firstPlayedAt: date(tracks, 3),
                lastPlayedAt: date(tracks, 4),
                playbackPreference: int(tracks, 5),
                manualPlayCount: int(tracks, 6),
                automaticPlayCount: int(tracks, 7),
                totalPlaybackDuration: sqlite3_column_double(tracks, 8),
                skipCount: int(tracks, 9),
                fullPlaybackCount: int(tracks, 10),
                consecutivePlayCount: int(tracks, 11),
                repeatPlaybackCount: int(tracks, 12),
                boredomCount: int(tracks, 13),
                boredomHiddenUntil: date(tracks, 14),
                isPermanentlyHiddenFromShuffle: int(tracks, 15) != 0
            )
        }
        try loadEvents(into: &entries)
        try loadDailySummaries(into: &entries)
        try loadDailySources(into: &entries)
        try loadCumulativeSources(into: &entries)
        return Array(entries.values)
    }

    private func open() throws {
        guard database == nil else { return }
        try fileManager.createDirectory(at: databaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var handle: OpaquePointer?
        guard sqlite3_open_v2(databaseURL.path, &handle, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX, nil) == SQLITE_OK else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown error"
            if let handle { sqlite3_close(handle) }
            throw PlaybackHistorySQLiteError.open(message)
        }
        database = handle
        do {
            try execute("PRAGMA foreign_keys = ON")
            try execute("PRAGMA journal_mode = WAL")
            try execute("PRAGMA synchronous = FULL")
            sqlite3_busy_timeout(handle, 5_000)
            try createSchema()
        } catch {
            close()
            throw error
        }
    }

    private func close() {
        if let database { sqlite3_close(database) }
        database = nil
    }

    private func createSchema() throws {
        try execute("""
            CREATE TABLE IF NOT EXISTS playback_metadata (
                key TEXT PRIMARY KEY, value TEXT NOT NULL
            );
            CREATE TABLE IF NOT EXISTS playback_tracks (
                track_id TEXT PRIMARY KEY,
                is_favorite INTEGER NOT NULL, play_count INTEGER NOT NULL,
                first_played_at REAL, last_played_at REAL,
                playback_preference INTEGER NOT NULL,
                manual_play_count INTEGER NOT NULL, automatic_play_count INTEGER NOT NULL,
                total_playback_duration REAL NOT NULL, skip_count INTEGER NOT NULL,
                full_playback_count INTEGER NOT NULL, consecutive_play_count INTEGER NOT NULL,
                repeat_playback_count INTEGER NOT NULL, boredom_count INTEGER NOT NULL,
                boredom_hidden_until REAL, is_permanently_hidden_from_shuffle INTEGER NOT NULL
            );
            CREATE TABLE IF NOT EXISTS playback_daily_summaries (
                track_id TEXT NOT NULL, play_date TEXT NOT NULL, play_count INTEGER NOT NULL,
                manual_play_count INTEGER NOT NULL, automatic_play_count INTEGER NOT NULL,
                full_playback_count INTEGER NOT NULL DEFAULT 0, skip_count INTEGER NOT NULL DEFAULT 0,
                early_skip_count INTEGER NOT NULL DEFAULT 0,
                PRIMARY KEY(track_id, play_date),
                FOREIGN KEY(track_id) REFERENCES playback_tracks(track_id) ON DELETE CASCADE
            );
            CREATE TABLE IF NOT EXISTS playback_daily_sources (
                track_id TEXT NOT NULL, play_date TEXT NOT NULL, source TEXT NOT NULL, play_count INTEGER NOT NULL,
                PRIMARY KEY(track_id, play_date, source),
                FOREIGN KEY(track_id, play_date) REFERENCES playback_daily_summaries(track_id, play_date) ON DELETE CASCADE
            );
            CREATE TABLE IF NOT EXISTS playback_source_counts (
                track_id TEXT NOT NULL, source TEXT NOT NULL, play_count INTEGER NOT NULL,
                PRIMARY KEY(track_id, source),
                FOREIGN KEY(track_id) REFERENCES playback_tracks(track_id) ON DELETE CASCADE
            );
            CREATE TABLE IF NOT EXISTS playback_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT, track_id TEXT NOT NULL, played_at REAL NOT NULL,
                started_at REAL, ended_at REAL, listened_seconds REAL, completion_ratio REAL,
                was_skipped INTEGER, start_kind TEXT, start_source TEXT,
                event_id TEXT, was_full_playback INTEGER, end_kind TEXT,
                FOREIGN KEY(track_id) REFERENCES playback_tracks(track_id) ON DELETE CASCADE
            );
            CREATE INDEX IF NOT EXISTS playback_events_track_date ON playback_events(track_id, played_at);
            """)
        let originalVersion = try schemaVersion()
        if originalVersion < 2 {
            try transaction {
                if originalVersion > 0 {
                    try execute("ALTER TABLE playback_events ADD COLUMN event_id TEXT")
                    try execute("ALTER TABLE playback_events ADD COLUMN was_full_playback INTEGER")
                    try execute("ALTER TABLE playback_daily_summaries ADD COLUMN full_playback_count INTEGER NOT NULL DEFAULT 0")
                    try execute("ALTER TABLE playback_daily_summaries ADD COLUMN skip_count INTEGER NOT NULL DEFAULT 0")
                    try execute("ALTER TABLE playback_daily_summaries ADD COLUMN early_skip_count INTEGER NOT NULL DEFAULT 0")
                }
                try execute("PRAGMA user_version = 2")
            }
        }
        if originalVersion > 0, originalVersion < 3 {
            try transaction {
                try execute("ALTER TABLE playback_events ADD COLUMN end_kind TEXT")
                try execute("PRAGMA user_version = 3")
            }
        } else if originalVersion == 0 {
            try execute("PRAGMA user_version = 3")
        }
        try execute("CREATE UNIQUE INDEX IF NOT EXISTS playback_events_event_id ON playback_events(event_id) WHERE event_id IS NOT NULL")
    }

    private func write(_ entry: PlaybackHistory) throws {
        let statement = try prepare("""
            INSERT INTO playback_tracks VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(track_id) DO UPDATE SET
              is_favorite=excluded.is_favorite, play_count=excluded.play_count,
              first_played_at=excluded.first_played_at, last_played_at=excluded.last_played_at,
              playback_preference=excluded.playback_preference, manual_play_count=excluded.manual_play_count,
              automatic_play_count=excluded.automatic_play_count,
              total_playback_duration=excluded.total_playback_duration, skip_count=excluded.skip_count,
              full_playback_count=excluded.full_playback_count, consecutive_play_count=excluded.consecutive_play_count,
              repeat_playback_count=excluded.repeat_playback_count, boredom_count=excluded.boredom_count,
              boredom_hidden_until=excluded.boredom_hidden_until,
              is_permanently_hidden_from_shuffle=excluded.is_permanently_hidden_from_shuffle
            """)
        defer { sqlite3_finalize(statement) }
        try bind(entry.trackID.uuidString, to: 1, in: statement)
        bind(entry.isFavorite, to: 2, in: statement); bind(entry.playCount, to: 3, in: statement)
        bind(entry.firstPlayedAt, to: 4, in: statement); bind(entry.lastPlayedAt, to: 5, in: statement)
        bind(entry.playbackPreference, to: 6, in: statement); bind(entry.manualPlayCount, to: 7, in: statement)
        bind(entry.automaticPlayCount, to: 8, in: statement); bind(entry.totalPlaybackDuration, to: 9, in: statement)
        bind(entry.skipCount, to: 10, in: statement); bind(entry.fullPlaybackCount, to: 11, in: statement)
        bind(entry.consecutivePlayCount, to: 12, in: statement); bind(entry.repeatPlaybackCount, to: 13, in: statement)
        bind(entry.boredomCount, to: 14, in: statement); bind(entry.boredomHiddenUntil, to: 15, in: statement)
        bind(entry.isPermanentlyHiddenFromShuffle, to: 16, in: statement)
        try step(statement)

        let id = entry.trackID.uuidString
        if entry.playbackEvents.isEmpty {
            // An empty event collection is the explicit per-track reset boundary.
            try execute("DELETE FROM playback_events WHERE track_id = ?", values: [id])
        }
        if entry.dailySummaries.isEmpty {
            try execute("DELETE FROM playback_daily_summaries WHERE track_id = ?", values: [id])
        }
        if entry.playbackSourceCounts.isEmpty {
            try execute("DELETE FROM playback_source_counts WHERE track_id = ?", values: [id])
        }
        for event in entry.playbackEvents {
            try execute("""
                INSERT OR IGNORE INTO playback_events(
                    track_id, played_at, started_at, ended_at, listened_seconds, completion_ratio,
                    was_skipped, start_kind, start_source, event_id, was_full_playback, end_kind
                ) VALUES(?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """, values: [
                    id, event.endedAt.timeIntervalSince1970, event.startedAt.timeIntervalSince1970,
                    event.endedAt.timeIntervalSince1970, event.listenedSeconds, event.completionRatio,
                    event.wasSkipped ? 1 : 0, event.startKind.rawValue, event.startSource.rawValue,
                    event.id, event.wasFullPlayback ? 1 : 0, event.endKind?.rawValue ?? NSNull()
                ])
        }
        for (day, summary) in entry.dailySummaries {
            try execute("""
                INSERT INTO playback_daily_summaries VALUES(?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(track_id, play_date) DO UPDATE SET
                  play_count=excluded.play_count, manual_play_count=excluded.manual_play_count,
                  automatic_play_count=excluded.automatic_play_count, full_playback_count=excluded.full_playback_count,
                  skip_count=excluded.skip_count, early_skip_count=excluded.early_skip_count
                """, values: [id, day, summary.playCount, summary.manualPlayCount, summary.automaticPlayCount,
                                summary.fullPlaybackCount, summary.skipCount, summary.earlySkipCount])
            try execute("DELETE FROM playback_daily_sources WHERE track_id = ? AND play_date = ?", values: [id, day])
            for (source, count) in summary.sourceCounts {
                try execute("INSERT OR REPLACE INTO playback_daily_sources VALUES(?, ?, ?, ?)", values: [id, day, source, count])
            }
        }
        for (source, count) in entry.playbackSourceCounts {
            try execute("INSERT OR REPLACE INTO playback_source_counts VALUES(?, ?, ?)", values: [id, source, count])
        }
    }

    private func loadEvents(into entries: inout [UUID: PlaybackHistory]) throws {
        let statement = try prepare("""
            SELECT id, track_id, played_at, started_at, ended_at, listened_seconds, completion_ratio,
                   was_skipped, start_kind, start_source, event_id, was_full_playback
                   , end_kind
            FROM playback_events ORDER BY id
            """)
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = UUID(uuidString: text(statement, 1)), var entry = entries[id] else { continue }
            let playedAt = Date(timeIntervalSince1970: sqlite3_column_double(statement, 2))
            entry.playbackEvents.append(PlaybackEvent(
                id: nullableText(statement, 10) ?? "legacy-sqlite-\(int(statement, 0))",
                trackID: id,
                startedAt: date(statement, 3) ?? playedAt,
                endedAt: date(statement, 4) ?? playedAt,
                listenedSeconds: sqlite3_column_double(statement, 5),
                completionRatio: sqlite3_column_double(statement, 6),
                wasSkipped: int(statement, 7) != 0,
                wasFullPlayback: int(statement, 11) != 0,
                startKind: PlaybackStartKind(rawValue: nullableText(statement, 8) ?? "") ?? .manual,
                startSource: PlaybackStartSource(rawValue: nullableText(statement, 9) ?? "") ?? .unknown,
                endKind: PlaybackEndKind(rawValue: nullableText(statement, 12) ?? "")
            ))
            entries[id] = entry
        }
    }

    private func loadDailySummaries(into entries: inout [UUID: PlaybackHistory]) throws {
        let statement = try prepare("SELECT track_id, play_date, play_count, manual_play_count, automatic_play_count, full_playback_count, skip_count, early_skip_count FROM playback_daily_summaries")
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = UUID(uuidString: text(statement, 0)), var entry = entries[id] else { continue }
            entry.dailySummaries[text(statement, 1)] = PlaybackDailySummary(
                playCount: int(statement, 2), manualPlayCount: int(statement, 3), automaticPlayCount: int(statement, 4),
                fullPlaybackCount: int(statement, 5), skipCount: int(statement, 6), earlySkipCount: int(statement, 7)
            )
            entries[id] = entry
        }
    }

    private func loadDailySources(into entries: inout [UUID: PlaybackHistory]) throws {
        let statement = try prepare("SELECT track_id, play_date, source, play_count FROM playback_daily_sources")
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = UUID(uuidString: text(statement, 0)), var entry = entries[id],
                  var summary = entry.dailySummaries[text(statement, 1)] else { continue }
            summary.sourceCounts[text(statement, 2)] = int(statement, 3)
            entry.dailySummaries[text(statement, 1)] = summary
            entries[id] = entry
        }
    }

    private func loadCumulativeSources(into entries: inout [UUID: PlaybackHistory]) throws {
        let statement = try prepare("SELECT track_id, source, play_count FROM playback_source_counts")
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            guard let id = UUID(uuidString: text(statement, 0)), var entry = entries[id] else { continue }
            entry.playbackSourceCounts[text(statement, 1)] = int(statement, 2)
            entries[id] = entry
        }
    }

    private func transaction(_ operation: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE")
        do { try operation(); try execute("COMMIT") }
        catch { try? execute("ROLLBACK"); throw error }
    }

    private func execute(_ sql: String, values: [Any] = []) throws {
        if values.isEmpty {
            guard let database else { throw PlaybackHistorySQLiteError.open("database is closed") }
            var errorMessage: UnsafeMutablePointer<CChar>?
            guard sqlite3_exec(database, sql, nil, nil, &errorMessage) == SQLITE_OK else {
                let message = errorMessage.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(database))
                sqlite3_free(errorMessage)
                throw PlaybackHistorySQLiteError.execute(message)
            }
            return
        }
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        for (offset, value) in values.enumerated() { try bindAny(value, to: Int32(offset + 1), in: statement) }
        try step(statement)
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        guard let database else { throw PlaybackHistorySQLiteError.open("database is closed") }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(database, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw PlaybackHistorySQLiteError.execute(String(cString: sqlite3_errmsg(database)))
        }
        return statement
    }

    private func schemaVersion() throws -> Int {
        let statement = try prepare("PRAGMA user_version")
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return int(statement, 0)
    }

    private func step(_ statement: OpaquePointer) throws {
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw PlaybackHistorySQLiteError.execute(database.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown")
        }
    }

    private func bindAny(_ value: Any, to index: Int32, in statement: OpaquePointer) throws {
        switch value {
        case let value as String: try bind(value, to: index, in: statement)
        case let value as Int: bind(value, to: index, in: statement)
        case let value as Double: bind(value, to: index, in: statement)
        case is NSNull: sqlite3_bind_null(statement, index)
        default: throw PlaybackHistorySQLiteError.bind("unsupported value")
        }
    }

    private func bind(_ value: String, to index: Int32, in statement: OpaquePointer) throws {
        guard sqlite3_bind_text(statement, index, value, -1, Self.transient) == SQLITE_OK else {
            throw PlaybackHistorySQLiteError.bind(value)
        }
    }
    private func bind(_ value: Int, to index: Int32, in statement: OpaquePointer) { sqlite3_bind_int64(statement, index, sqlite3_int64(value)) }
    private func bind(_ value: Bool, to index: Int32, in statement: OpaquePointer) { bind(value ? 1 : 0, to: index, in: statement) }
    private func bind(_ value: Double, to index: Int32, in statement: OpaquePointer) { sqlite3_bind_double(statement, index, value) }
    private func bind(_ value: Date?, to index: Int32, in statement: OpaquePointer) {
        if let value { bind(value.timeIntervalSince1970, to: index, in: statement) } else { sqlite3_bind_null(statement, index) }
    }
    private func text(_ statement: OpaquePointer, _ index: Int32) -> String { String(cString: sqlite3_column_text(statement, index)) }
    private func nullableText(_ statement: OpaquePointer, _ index: Int32) -> String? {
        sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : text(statement, index)
    }
    private func int(_ statement: OpaquePointer, _ index: Int32) -> Int { Int(sqlite3_column_int64(statement, index)) }
    private func date(_ statement: OpaquePointer, _ index: Int32) -> Date? {
        sqlite3_column_type(statement, index) == SQLITE_NULL ? nil : Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
    }
}
