import Foundation

nonisolated final class PlaybackHistoryBackupService: @unchecked Sendable {
    private let dailyDirectory: URL
    private let metadataURL: URL
    private let fileManager: FileManager
    private let now: @Sendable () -> Date
    private let interval: TimeInterval = 24 * 60 * 60
    private let retainedDailyGenerations = 7

    init(rootDirectory: URL, fileManager: FileManager = .default, now: @escaping @Sendable () -> Date = Date.init) {
        dailyDirectory = rootDirectory.appending(path: "Daily")
        metadataURL = rootDirectory.appending(path: "last-daily-backup.txt")
        self.fileManager = fileManager
        self.now = now
    }

    func createDailyBackupIfNeeded(entries: [PlaybackHistory]) throws {
        let currentDate = now()
        if let data = try? Data(contentsOf: metadataURL),
           let value = String(data: data, encoding: .utf8),
           let timestamp = TimeInterval(value),
           currentDate.timeIntervalSince1970 - timestamp < interval {
            return
        }

        try fileManager.createDirectory(at: dailyDirectory, withIntermediateDirectories: true)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        let destination = dailyDirectory.appending(path: "playback-history-\(formatter.string(from: currentDate)).json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try writeAtomicallyWithoutOverwriting(
            encoder.encode(entries.sorted { $0.trackID.uuidString < $1.trackID.uuidString }),
            to: destination
        )
        try Data(String(currentDate.timeIntervalSince1970).utf8).write(to: metadataURL, options: .atomic)
        try rotateDailyBackups()
    }

    private func writeAtomicallyWithoutOverwriting(_ data: Data, to destination: URL) throws {
        let temporaryURL = destination.deletingLastPathComponent().appending(
            path: ".\(destination.lastPathComponent).\(UUID().uuidString).tmp"
        )
        do {
            try data.write(to: temporaryURL, options: .atomic)
            try fileManager.moveItem(at: temporaryURL, to: destination)
        } catch {
            try? fileManager.removeItem(at: temporaryURL)
            throw error
        }
    }

    private func rotateDailyBackups() throws {
        let backups = try fileManager.contentsOfDirectory(
            at: dailyDirectory,
            includingPropertiesForKeys: nil
        ).filter { $0.lastPathComponent.hasPrefix("playback-history-") && $0.pathExtension == "json" }
            .sorted { $0.lastPathComponent > $1.lastPathComponent }
        for expired in backups.dropFirst(retainedDailyGenerations) {
            try fileManager.removeItem(at: expired)
        }
    }
}
