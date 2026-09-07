import Foundation
import SQLite3

nonisolated struct ExternalBackupManifest: Codable, Equatable, Sendable {
    nonisolated struct FileEntry: Codable, Equatable, Sendable {
        let path: String
        let byteCount: Int64
    }

    let formatVersion: Int
    let schemaVersion: Int
    let appVersion: String
    let createdAt: Date
    let files: [FileEntry]
}

nonisolated struct ExternalBackupStatus: Equatable, Sendable {
    let destinationName: String?
    let lastBackupDate: Date?
    let hasRestorableBackup: Bool
}

enum ExternalBackupError: LocalizedError {
    case destinationUnavailable
    case unsupportedFormat
    case missingManifest
    case missingFile(String)
    case invalidJSON(String)
    case invalidDatabase
    case invalidTrackIdentifier(String)

    var errorDescription: String? {
        switch self {
        case .destinationUnavailable: "バックアップ保存先へアクセスできません。もう一度選択してください。"
        case .unsupportedFormat: "このバックアップ形式には対応していません。"
        case .missingManifest: "manifest.jsonが見つかりません。"
        case let .missingFile(path): "バックアップ内のファイルがありません: \(path)"
        case let .invalidJSON(path): "JSONファイルが壊れています: \(path)"
        case .invalidDatabase: "再生履歴データベースの整合性を確認できません。"
        case let .invalidTrackIdentifier(value): "Track IDが不正です: \(value)"
        }
    }
}

/// Creates an app-external, two-generation snapshot. Application Support remains authoritative.
nonisolated final class ExternalBackupService: @unchecked Sendable {
    static let formatVersion = 1
    static let schemaVersion = 1

    private let fileManager: FileManager
    private let applicationRoot: URL
    private let defaults: UserDefaults
    private let now: () -> Date
    private let appVersion: () -> String
    private let bookmarkKey = "externalBackupDestinationBookmark"
    private let lastBackupKey = "externalBackupLastSuccessfulDate"
    private let settingsKeys = [
        "equalizerSettings", "customEqualizerPresets", "playbackTransitionSettings",
        "volumeNormalizationEnabled", "library.disabledGenreNames", "library.genreDisplayPresets",
        "library.songsDisplayMode", "library.albumsDisplayMode", "library.artistsDisplayMode"
    ]
    private let paths = [
        "playback-history.sqlite3", "track-preferences.json", "playlists.json",
        "track-identities.json", "track-features.json", "TrackPlaybackAdjustments",
        "library-favorites.json", "highlights.json"
    ]

    init(
        applicationRoot: URL? = nil,
        defaults: UserDefaults = .standard,
        fileManager: FileManager = .default,
        now: @escaping () -> Date = Date.init,
        appVersion: @escaping () -> String = {
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        }
    ) {
        self.fileManager = fileManager
        self.applicationRoot = applicationRoot ?? fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appending(path: "MyMusic", directoryHint: .isDirectory)
        self.defaults = defaults
        self.now = now
        self.appVersion = appVersion
    }

    func saveDestination(_ url: URL) throws {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard accessing || fileManager.isWritableFile(atPath: url.path) else { throw ExternalBackupError.destinationUnavailable }
        let data = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        defaults.set(data, forKey: bookmarkKey)
    }

    func resolvedDestination() throws -> URL? {
        guard let data = defaults.data(forKey: bookmarkKey) else { return nil }
        var stale = false
        let url = try URL(resolvingBookmarkData: data, options: .withoutUI, relativeTo: nil, bookmarkDataIsStale: &stale)
        if stale { try saveDestination(url) }
        return url
    }

    func status() -> ExternalBackupStatus {
        let destination = try? resolvedDestination()
        let hasBackup = destination.flatMap { destination in
            try? withAccess(to: destination) {
                fileManager.fileExists(atPath: destination.appending(path: "MyMusic Backup/latest/manifest.json").path)
            }
        } ?? false
        return ExternalBackupStatus(
            destinationName: destination?.lastPathComponent,
            lastBackupDate: defaults.object(forKey: lastBackupKey) as? Date,
            hasRestorableBackup: hasBackup
        )
    }

    @discardableResult
    func createBackup(at selectedDestination: URL? = nil) throws -> ExternalBackupManifest {
        let destination: URL
        if let selectedDestination { destination = selectedDestination }
        else if let saved = try resolvedDestination() { destination = saved }
        else { throw ExternalBackupError.destinationUnavailable }
        return try withAccess(to: destination) {
            let root = destination.appending(path: "MyMusic Backup", directoryHint: .isDirectory)
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            let staging = root.appending(path: ".staging-\(UUID().uuidString)", directoryHint: .isDirectory)
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            do {
                try writeSnapshot(to: staging)
                let manifest = try makeManifest(in: staging)
                try encode(manifest).write(to: staging.appending(path: "manifest.json"), options: .atomic)
                _ = try validateBackup(at: staging)
                try rotate(staging: staging, root: root)
                defaults.set(manifest.createdAt, forKey: lastBackupKey)
                return manifest
            } catch {
                try? fileManager.removeItem(at: staging)
                throw error
            }
        }
    }

    @discardableResult
    func restore(from selectedURL: URL) throws -> ExternalBackupManifest {
        try withAccess(to: selectedURL) {
            let source = backupDirectory(from: selectedURL)
            let manifest = try validateBackup(at: source)
            let staging = applicationRoot.deletingLastPathComponent().appending(path: ".MyMusic-restore-\(UUID().uuidString)")
            let pending = pendingRestoreURL
            try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
            do {
                try copyPayload(from: source, to: staging, manifest: manifest)
                try fileManager.copyItem(at: source.appending(path: "manifest.json"), to: staging.appending(path: "manifest.json"))
                _ = try validateBackup(at: staging)
                if fileManager.fileExists(atPath: pending.path) { try fileManager.removeItem(at: pending) }
                try fileManager.moveItem(at: staging, to: pending)
                return manifest
            } catch {
                try? fileManager.removeItem(at: staging)
                throw error
            }
        }
    }

    /// Applies a fully validated restore before stores open their files. Calling this at
    /// process startup avoids replacing a live WAL database or racing pending Store writes.
    func applyPendingRestoreIfNeeded() throws -> Bool {
        let pending = pendingRestoreURL
        guard fileManager.fileExists(atPath: pending.path) else { return false }
        _ = try validateBackup(at: pending)
        let rollback = applicationRoot.deletingLastPathComponent().appending(path: ".MyMusic-rollback-\(UUID().uuidString)")
        if fileManager.fileExists(atPath: applicationRoot.path) { try fileManager.moveItem(at: applicationRoot, to: rollback) }
        do {
            try fileManager.moveItem(at: pending, to: applicationRoot)
            try restoreSettings(from: applicationRoot.appending(path: "settings.plist"))
            try? fileManager.removeItem(at: applicationRoot.appending(path: "manifest.json"))
            try? fileManager.removeItem(at: rollback)
            return true
        } catch {
            try? fileManager.removeItem(at: applicationRoot)
            if fileManager.fileExists(atPath: rollback.path) { try? fileManager.moveItem(at: rollback, to: applicationRoot) }
            throw error
        }
    }

    func validateBackup(at url: URL) throws -> ExternalBackupManifest {
        let manifestURL = url.appending(path: "manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else { throw ExternalBackupError.missingManifest }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(ExternalBackupManifest.self, from: Data(contentsOf: manifestURL))
        guard manifest.formatVersion == Self.formatVersion, manifest.schemaVersion == Self.schemaVersion else {
            throw ExternalBackupError.unsupportedFormat
        }
        try validatePayload(in: url, manifest: manifest)
        return manifest
    }

    private func writeSnapshot(to staging: URL) throws {
        for path in paths {
            let source = applicationRoot.appending(path: path)
            guard fileManager.fileExists(atPath: source.path) else { continue }
            let target = staging.appending(path: path)
            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if path == "playback-history.sqlite3" { try snapshotDatabase(from: source, to: target) }
            else { try fileManager.copyItem(at: source, to: target) }
        }
        var settings: [String: Any] = [:]
        for key in settingsKeys { if let value = defaults.object(forKey: key) { settings[key] = value } }
        let data = try PropertyListSerialization.data(fromPropertyList: settings, format: .binary, options: 0)
        try data.write(to: staging.appending(path: "settings.plist"), options: .atomic)
    }

    private func makeManifest(in directory: URL) throws -> ExternalBackupManifest {
        let files = try recursiveFiles(in: directory).map {
            ExternalBackupManifest.FileEntry(path: $0.path.replacingOccurrences(of: directory.path + "/", with: ""), byteCount: (try $0.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init) ?? 0)
        }.sorted { $0.path < $1.path }
        return ExternalBackupManifest(formatVersion: Self.formatVersion, schemaVersion: Self.schemaVersion,
                                      appVersion: appVersion(), createdAt: now(), files: files)
    }

    private func validatePayload(in directory: URL, manifest: ExternalBackupManifest) throws {
        guard manifest.files.contains(where: { $0.path == "settings.plist" }) else { throw ExternalBackupError.missingFile("settings.plist") }
        for entry in manifest.files {
            let url = try safeFileURL(for: entry.path, in: directory)
            guard fileManager.fileExists(atPath: url.path) else { throw ExternalBackupError.missingFile(entry.path) }
            let values = try url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey])
            guard values.isRegularFile == true, values.isSymbolicLink != true else { throw ExternalBackupError.missingFile(entry.path) }
            let actualSize = values.fileSize.map(Int64.init) ?? -1
            guard actualSize == entry.byteCount else { throw ExternalBackupError.missingFile(entry.path) }
            if entry.path.hasSuffix(".json") {
                do {
                    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
                    try validateTrackIdentifiers(in: object, identityDocument: entry.path == "track-identities.json")
                }
                catch let error as ExternalBackupError { throw error }
                catch { throw ExternalBackupError.invalidJSON(entry.path) }
            }
            if entry.path.hasPrefix("TrackPlaybackAdjustments/"), entry.path.hasSuffix(".json") {
                let value = url.deletingPathExtension().lastPathComponent
                guard UUID(uuidString: value) != nil else { throw ExternalBackupError.invalidTrackIdentifier(value) }
            }
        }
        if manifest.files.contains(where: { $0.path == "playback-history.sqlite3" }) {
            try checkDatabase(directory.appending(path: "playback-history.sqlite3"))
        }
        _ = try PropertyListSerialization.propertyList(from: Data(contentsOf: directory.appending(path: "settings.plist")), options: [], format: nil)
    }

    private func rotate(staging: URL, root: URL) throws {
        let latest = root.appending(path: "latest"), previous = root.appending(path: "previous")
        let oldPrevious = root.appending(path: ".old-previous-\(UUID().uuidString)")
        var movedLatest = false
        do {
            if fileManager.fileExists(atPath: previous.path) { try fileManager.moveItem(at: previous, to: oldPrevious) }
            if fileManager.fileExists(atPath: latest.path) {
                try fileManager.moveItem(at: latest, to: previous)
                movedLatest = true
            }
            try fileManager.moveItem(at: staging, to: latest)
            try? fileManager.removeItem(at: oldPrevious)
        } catch {
            if movedLatest { try? fileManager.moveItem(at: previous, to: latest) }
            if fileManager.fileExists(atPath: oldPrevious.path) { try? fileManager.moveItem(at: oldPrevious, to: previous) }
            throw error
        }
    }

    private var pendingRestoreURL: URL {
        applicationRoot.deletingLastPathComponent().appending(path: ".MyMusic-pending-restore")
    }

    private func copyPayload(from source: URL, to destination: URL, manifest: ExternalBackupManifest) throws {
        for entry in manifest.files {
            let url = try safeFileURL(for: entry.path, in: source)
            let target = try safeFileURL(for: entry.path, in: destination)
            try fileManager.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fileManager.copyItem(at: url, to: target)
        }
    }

    private func safeFileURL(for relativePath: String, in root: URL) throws -> URL {
        guard !relativePath.isEmpty, !relativePath.hasPrefix("/") else { throw ExternalBackupError.missingFile(relativePath) }
        let standardizedRoot = root.standardizedFileURL
        let candidate = standardizedRoot.appending(path: relativePath).standardizedFileURL
        guard candidate.path.hasPrefix(standardizedRoot.path + "/") else { throw ExternalBackupError.missingFile(relativePath) }
        return candidate
    }

    private func restoreSettings(from url: URL) throws {
        guard let values = try PropertyListSerialization.propertyList(from: Data(contentsOf: url), options: [], format: nil) as? [String: Any] else {
            throw ExternalBackupError.invalidJSON("settings.plist")
        }
        for key in settingsKeys { defaults.removeObject(forKey: key) }
        for (key, value) in values where settingsKeys.contains(key) { defaults.set(value, forKey: key) }
        try? fileManager.removeItem(at: url)
    }

    private func validateTrackIdentifiers(in value: Any, identityDocument: Bool) throws {
        if let dictionary = value as? [String: Any] {
            for (key, child) in dictionary {
                if (key == "trackID" || key == "trackId" || (identityDocument && key == "id")),
                   let text = child as? String, UUID(uuidString: text) == nil {
                    throw ExternalBackupError.invalidTrackIdentifier(text)
                }
                if key == "trackIDs", let values = child as? [String] {
                    for text in values where UUID(uuidString: text) == nil { throw ExternalBackupError.invalidTrackIdentifier(text) }
                }
                try validateTrackIdentifiers(in: child, identityDocument: identityDocument)
            }
        } else if let array = value as? [Any] {
            for child in array { try validateTrackIdentifiers(in: child, identityDocument: identityDocument) }
        }
    }

    private func backupDirectory(from url: URL) -> URL {
        if fileManager.fileExists(atPath: url.appending(path: "manifest.json").path) { return url }
        if fileManager.fileExists(atPath: url.appending(path: "latest/manifest.json").path) { return url.appending(path: "latest") }
        return url.appending(path: "MyMusic Backup/latest")
    }

    private func withAccess<T>(to url: URL, _ work: () throws -> T) throws -> T {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        guard accessing || fileManager.isReadableFile(atPath: url.path) else { throw ExternalBackupError.destinationUnavailable }
        return try work()
    }

    private func recursiveFiles(in directory: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey]
        guard let iterator = fileManager.enumerator(at: directory, includingPropertiesForKeys: keys) else { return [] }
        return iterator.compactMap { $0 as? URL }.filter { (try? $0.resourceValues(forKeys: Set(keys)).isRegularFile) == true }
    }

    private func encode(_ manifest: ExternalBackupManifest) throws -> Data {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .iso8601; encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(manifest)
    }

    private func snapshotDatabase(from source: URL, to destination: URL) throws {
        var sourceDB: OpaquePointer?, destinationDB: OpaquePointer?
        guard sqlite3_open_v2(source.path, &sourceDB, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              sqlite3_open_v2(destination.path, &destinationDB, SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE, nil) == SQLITE_OK,
              let sourceDB, let destinationDB else { throw ExternalBackupError.invalidDatabase }
        defer { sqlite3_close(sourceDB); sqlite3_close(destinationDB) }
        guard let backup = sqlite3_backup_init(destinationDB, "main", sourceDB, "main") else { throw ExternalBackupError.invalidDatabase }
        defer { sqlite3_backup_finish(backup) }
        guard sqlite3_backup_step(backup, -1) == SQLITE_DONE else { throw ExternalBackupError.invalidDatabase }
    }

    private func checkDatabase(_ url: URL) throws {
        var db: OpaquePointer?
        guard sqlite3_open_v2(url.path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else { throw ExternalBackupError.invalidDatabase }
        defer { sqlite3_close(db) }
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, "PRAGMA integrity_check", -1, &statement, nil) == SQLITE_OK, let statement else { throw ExternalBackupError.invalidDatabase }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW, String(cString: sqlite3_column_text(statement, 0)) == "ok" else { throw ExternalBackupError.invalidDatabase }
    }
}
