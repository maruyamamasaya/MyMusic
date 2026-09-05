import Foundation
import UniformTypeIdentifiers
import ZIPFoundation

struct AnalyticsArchiveExportService: Sendable {
    nonisolated func archive(
        files: [MusicExportFile],
        exportedAt: Date = Date(),
        timeZone: TimeZone = .current
    ) async throws -> MusicExportFile {
        try await Task.detached(priority: .userInitiated) {
            let fileManager = FileManager.default
            let root = fileManager.temporaryDirectory
                .appending(path: UUID().uuidString, directoryHint: .isDirectory)
            let source = root.appending(path: "Analytics", directoryHint: .isDirectory)
            let archiveURL = root.appending(path: "Analytics.zip")

            defer { try? fileManager.removeItem(at: root) }

            try fileManager.createDirectory(at: source, withIntermediateDirectories: true)
            for file in files {
                try file.data.write(
                    to: source.appending(path: file.filename),
                    options: .atomic
                )
            }
            try fileManager.zipItem(
                at: source,
                to: archiveURL,
                shouldKeepParent: false,
                compressionMethod: .deflate
            )

            return MusicExportFile(
                data: try Data(contentsOf: archiveURL),
                filename: "MyMusic-Analytics-\(AnalyticsArchiveExportService.filenameDate(exportedAt, timeZone: timeZone)).zip",
                contentType: .zip
            )
        }.value
    }

    private nonisolated static func filenameDate(_ date: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
