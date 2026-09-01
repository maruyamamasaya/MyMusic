import Foundation
import os

enum PlaybackHistoryMigrationState: String, Codable, Sendable {
    case notStarted = "not_started"
    case inProgress = "in_progress"
    case verified
    case failed
}

private struct PlaybackHistoryMigrationStateDocument: Codable {
    let state: PlaybackHistoryMigrationState
    let updatedAt: Date
    let failureReason: String?
}

enum PlaybackHistoryMigrationError: LocalizedError {
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case let .validationFailed(reason): "Playback history migration validation failed: \(reason)"
        }
    }
}

nonisolated struct PlaybackHistoryMigrationValidator {
    static func validate(source: [PlaybackHistory], imported: [PlaybackHistory]) throws {
        guard source.count == imported.count else {
            throw PlaybackHistoryMigrationError.validationFailed("track count differs (\(source.count) / \(imported.count))")
        }
        let lhs = Dictionary(uniqueKeysWithValues: source.map { ($0.trackID, $0) })
        let rhs = Dictionary(uniqueKeysWithValues: imported.map { ($0.trackID, $0) })
        guard lhs.keys == rhs.keys else {
            throw PlaybackHistoryMigrationError.validationFailed("track ID set differs")
        }
        for (trackID, sourceEntry) in lhs {
            guard rhs[trackID] == sourceEntry else {
                throw PlaybackHistoryMigrationError.validationFailed("fields differ for track \(trackID.uuidString)")
            }
        }
    }
}

/// The state sidecar deliberately lives outside SQLite: an interrupted or corrupt DB
/// can never be mistaken for a verified migration merely because the DB file exists.
nonisolated final class PlaybackHistoryMigrationService: @unchecked Sendable {
    private let legacyJSONURL: URL
    private let migrationBackupURL: URL
    private let stateURL: URL
    private let repository: PlaybackHistorySQLiteRepository
    private let fileManager: FileManager
    private let logger = Logger(subsystem: "MyMusic", category: "PlaybackHistoryMigration")

    init(
        legacyJSONURL: URL,
        migrationBackupURL: URL,
        stateURL: URL,
        repository: PlaybackHistorySQLiteRepository,
        fileManager: FileManager = .default
    ) {
        self.legacyJSONURL = legacyJSONURL
        self.migrationBackupURL = migrationBackupURL
        self.stateURL = stateURL
        self.repository = repository
        self.fileManager = fileManager
    }

    func prepareAuthoritativeStore() throws {
        if try readState() == .verified {
            try repository.openAndValidateVerifiedSchema()
            return
        }

        guard fileManager.fileExists(atPath: legacyJSONURL.path) else {
            try writeState(.inProgress)
            do {
                try repository.recreateEmptyDatabase()
                try repository.markMigrationVerified()
                try writeState(.verified)
                logger.info("Playback migration verified for a new installation")
            } catch {
                try? writeState(.failed, reason: error.localizedDescription)
                throw error
            }
            return
        }

        logger.info("Playback migration started")
        try writeState(.inProgress)
        do {
            let sourceData = try Data(contentsOf: legacyJSONURL)
            try preserveMigrationBackup(sourceData)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let source = try decoder.decode([PlaybackHistory].self, from: sourceData)
            logger.info("Source JSON entries: \(source.count)")

            // Any unverified DB is disposable. The original JSON and permanent copy
            // remain untouched, making this operation safely repeatable after a crash.
            try repository.recreateEmptyDatabase()
            try repository.replaceAll(with: source)
            let imported = try repository.loadAll()
            try PlaybackHistoryMigrationValidator.validate(source: source, imported: imported)
            logger.info("SQLite inserted tracks: \(imported.count); validation passed")
            try repository.markMigrationVerified()
            try writeState(.verified)
            logger.info("Migration verified")
        } catch {
            try? writeState(.failed, reason: error.localizedDescription)
            logger.error("Playback migration failed; stage data remains JSON-authoritative: \(error.localizedDescription)")
            throw error
        }
    }

    private func preserveMigrationBackup(_ data: Data) throws {
        guard !fileManager.fileExists(atPath: migrationBackupURL.path) else { return }
        try fileManager.createDirectory(at: migrationBackupURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: migrationBackupURL, options: [.atomic, .withoutOverwriting])
    }

    private func readState() throws -> PlaybackHistoryMigrationState {
        guard fileManager.fileExists(atPath: stateURL.path) else { return .notStarted }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PlaybackHistoryMigrationStateDocument.self, from: Data(contentsOf: stateURL)).state
    }

    private func writeState(_ state: PlaybackHistoryMigrationState, reason: String? = nil) throws {
        try fileManager.createDirectory(at: stateURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let document = PlaybackHistoryMigrationStateDocument(state: state, updatedAt: Date(), failureReason: reason)
        try encoder.encode(document).write(to: stateURL, options: .atomic)
    }
}
