import Foundation
import SQLite3
import Testing
@testable import MyMusic

struct ExternalBackupServiceTests {
    @Test func emptyBackupHasValidManifestAndSettings() throws {
        let fixture = try Fixture()
        let manifest = try fixture.service.createBackup(at: fixture.destination)

        #expect(manifest.formatVersion == 1)
        #expect(manifest.files.map(\.path) == ["settings.plist"])
        #expect(try fixture.service.validateBackup(at: fixture.latest) == manifest)
    }

    @Test func roundTripPreservesUnicodeSettingsAndState() throws {
        let fixture = try Fixture()
        try FileManager.default.createDirectory(at: fixture.applicationRoot, withIntermediateDirectories: true)
        try Data("[{\"id\":\"3D1D3EA7-936E-4AE2-B1B5-E581ECB4819F\",\"name\":\"朝の音楽\",\"trackIDs\":[]}]".utf8)
            .write(to: fixture.applicationRoot.appending(path: "playlists.json"))
        fixture.defaults.set(["クラシック"], forKey: "library.disabledGenreNames")
        _ = try fixture.service.createBackup(at: fixture.destination)

        try Data("[]".utf8).write(to: fixture.applicationRoot.appending(path: "playlists.json"), options: .atomic)
        fixture.defaults.set([], forKey: "library.disabledGenreNames")
        _ = try fixture.service.restore(from: fixture.latest)
        #expect(try fixture.service.applyPendingRestoreIfNeeded())

        let restored = try String(contentsOf: fixture.applicationRoot.appending(path: "playlists.json"), encoding: .utf8)
        #expect(restored.contains("朝の音楽"))
        #expect(fixture.defaults.stringArray(forKey: "library.disabledGenreNames") == ["クラシック"])
    }

    @Test func successfulBackupsRotateTwoGenerations() throws {
        let fixture = try Fixture()
        try FileManager.default.createDirectory(at: fixture.applicationRoot, withIntermediateDirectories: true)
        let file = fixture.applicationRoot.appending(path: "playlists.json")
        try Data("[]".utf8).write(to: file)
        _ = try fixture.service.createBackup(at: fixture.destination)
        try Data("[{\"id\":\"3D1D3EA7-936E-4AE2-B1B5-E581ECB4819F\",\"name\":\"二世代目\",\"trackIDs\":[]}]".utf8).write(to: file, options: .atomic)
        _ = try fixture.service.createBackup(at: fixture.destination)

        #expect(FileManager.default.fileExists(atPath: fixture.latest.appending(path: "manifest.json").path))
        #expect(FileManager.default.fileExists(atPath: fixture.backupRoot.appending(path: "previous/manifest.json").path))
    }

    @Test func liveWALDatabaseIsSnapshottedAndValidated() throws {
        let fixture = try Fixture()
        try FileManager.default.createDirectory(at: fixture.applicationRoot, withIntermediateDirectories: true)
        let databaseURL = fixture.applicationRoot.appending(path: "playback-history.sqlite3")
        var database: OpaquePointer?
        #expect(sqlite3_open(databaseURL.path, &database) == SQLITE_OK)
        let openedDatabase = try #require(database)
        defer { sqlite3_close(openedDatabase) }
        #expect(sqlite3_exec(openedDatabase, "PRAGMA journal_mode = WAL", nil, nil, nil) == SQLITE_OK)
        #expect(sqlite3_exec(openedDatabase, "CREATE TABLE playback_test(value TEXT NOT NULL)", nil, nil, nil) == SQLITE_OK)
        #expect(sqlite3_exec(openedDatabase, "INSERT INTO playback_test VALUES('kept')", nil, nil, nil) == SQLITE_OK)

        let manifest = try fixture.service.createBackup(at: fixture.destination)

        #expect(manifest.files.contains { $0.path == "playback-history.sqlite3" })
        #expect(try fixture.service.validateBackup(at: fixture.latest) == manifest)
        let backupURL = fixture.latest.appending(path: "playback-history.sqlite3")
        var backupDatabase: OpaquePointer?
        #expect(sqlite3_open_v2(backupURL.path, &backupDatabase, SQLITE_OPEN_READONLY, nil) == SQLITE_OK)
        let openedBackup = try #require(backupDatabase)
        defer { sqlite3_close(openedBackup) }
        var statement: OpaquePointer?
        #expect(sqlite3_prepare_v2(openedBackup, "SELECT value FROM playback_test", -1, &statement, nil) == SQLITE_OK)
        let preparedStatement = try #require(statement)
        defer { sqlite3_finalize(preparedStatement) }
        #expect(sqlite3_step(preparedStatement) == SQLITE_ROW)
        #expect(String(cString: sqlite3_column_text(preparedStatement, 0)) == "kept")
    }

    @Test func invalidNewSnapshotDoesNotReplaceLatest() throws {
        let fixture = try Fixture()
        try FileManager.default.createDirectory(at: fixture.applicationRoot, withIntermediateDirectories: true)
        let file = fixture.applicationRoot.appending(path: "playlists.json")
        try Data("[]".utf8).write(to: file)
        let original = try fixture.service.createBackup(at: fixture.destination)
        try Data("not-json".utf8).write(to: file, options: .atomic)

        #expect(throws: Error.self) { try fixture.service.createBackup(at: fixture.destination) }
        #expect(try fixture.service.validateBackup(at: fixture.latest) == original)
    }

    @Test func rejectsUnsupportedMissingAndCorruptBackup() throws {
        let fixture = try Fixture()
        _ = try fixture.service.createBackup(at: fixture.destination)
        let manifestURL = fixture.latest.appending(path: "manifest.json")
        var manifest = try JSONDecoder.iso8601.decode(ExternalBackupManifest.self, from: Data(contentsOf: manifestURL))
        manifest = ExternalBackupManifest(formatVersion: 99, schemaVersion: manifest.schemaVersion, appVersion: manifest.appVersion, createdAt: manifest.createdAt, files: manifest.files)
        try JSONEncoder.iso8601.encode(manifest).write(to: manifestURL, options: .atomic)
        #expect(throws: ExternalBackupError.self) { try fixture.service.validateBackup(at: fixture.latest) }

        try FileManager.default.removeItem(at: manifestURL)
        #expect(throws: ExternalBackupError.self) { try fixture.service.validateBackup(at: fixture.latest) }
    }

    @Test func rejectedRestoreKeepsCurrentData() throws {
        let fixture = try Fixture()
        try FileManager.default.createDirectory(at: fixture.applicationRoot, withIntermediateDirectories: true)
        let current = fixture.applicationRoot.appending(path: "playlists.json")
        try Data("[]".utf8).write(to: current)
        _ = try fixture.service.createBackup(at: fixture.destination)
        try Data("current-data".utf8).write(to: current, options: .atomic)
        try Data("broken".utf8).write(to: fixture.latest.appending(path: "settings.plist"), options: .atomic)

        #expect(throws: Error.self) { try fixture.service.restore(from: fixture.latest) }
        #expect(try String(contentsOf: current, encoding: .utf8) == "current-data")
    }
}

private struct Fixture {
    let root: URL
    let applicationRoot: URL
    let destination: URL
    let defaults: UserDefaults
    let service: ExternalBackupService
    var backupRoot: URL { destination.appending(path: "MyMusic Backup") }
    var latest: URL { backupRoot.appending(path: "latest") }

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "ExternalBackupTests-\(UUID().uuidString)")
        applicationRoot = root.appending(path: "Application Support/MyMusic")
        destination = root.appending(path: "Files")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        defaults = UserDefaults(suiteName: "ExternalBackupTests-\(UUID().uuidString)")!
        service = ExternalBackupService(applicationRoot: applicationRoot, defaults: defaults, now: { Date(timeIntervalSince1970: 1_800_000_000) }, appVersion: { "1.0-test" })
    }
}

private extension JSONDecoder {
    static var iso8601: JSONDecoder { let value = JSONDecoder(); value.dateDecodingStrategy = .iso8601; return value }
}

private extension JSONEncoder {
    static var iso8601: JSONEncoder { let value = JSONEncoder(); value.dateEncodingStrategy = .iso8601; return value }
}
