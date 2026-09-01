import Foundation

protocol PlaybackHistoryPersistenceServicing: Sendable {
    func load() async throws -> [PlaybackHistory]
    func save(_ history: [PlaybackHistory]) async throws
    func save(_ entry: PlaybackHistory) async throws
}

extension PlaybackHistoryPersistenceServicing {
    /// Compatibility path for test doubles and alternate repositories. The production
    /// SQLite repository overrides this method and only writes the supplied track.
    func save(_ entry: PlaybackHistory) async throws {
        var entries = Dictionary(uniqueKeysWithValues: try await load().map { ($0.trackID, $0) })
        entries[entry.trackID] = entry
        try await save(Array(entries.values))
    }
}

/// Playback history repository. SQLite becomes authoritative only after the legacy
/// JSON has been copied, imported, read back, and semantically validated.
actor PlaybackHistoryPersistenceService: PlaybackHistoryPersistenceServicing {
    private let repository: PlaybackHistorySQLiteRepository
    private let migration: PlaybackHistoryMigrationService
    private let backup: PlaybackHistoryBackupService
    private var prepared = false

    init(
        applicationDirectory: URL? = nil,
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        let root = applicationDirectory ?? FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        )[0].appending(path: "MyMusic")
        let repository = PlaybackHistorySQLiteRepository(databaseURL: root.appending(path: "playback-history.sqlite3"))
        self.repository = repository
        migration = PlaybackHistoryMigrationService(
            legacyJSONURL: root.appending(path: "playback-history.json"),
            migrationBackupURL: root.appending(path: "Backups/Migration/playback-history-pre-sqlite.json"),
            stateURL: root.appending(path: "playback-history-migration-state.json"),
            repository: repository
        )
        backup = PlaybackHistoryBackupService(rootDirectory: root.appending(path: "Backups"), now: now)
    }

    func load() async throws -> [PlaybackHistory] {
        try prepareIfNeeded()
        let entries = try repository.loadAll()
        try backup.createDailyBackupIfNeeded(entries: entries)
        return entries
    }

    /// Full replacement is retained for import/test compatibility. Normal Store writes
    /// use `save(_ entry:)`, so this does not run for ordinary playback changes.
    func save(_ history: [PlaybackHistory]) async throws {
        try prepareIfNeeded()
        try repository.replaceAll(with: history)
    }

    func save(_ entry: PlaybackHistory) async throws {
        try prepareIfNeeded()
        try repository.upsert(entry)
    }

    private func prepareIfNeeded() throws {
        guard !prepared else { return }
        try migration.prepareAuthoritativeStore()
        prepared = true
    }
}
