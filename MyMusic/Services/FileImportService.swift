import Foundation

protocol FileImportServicing: Sendable {
    func saveLibraryFolders(_ urls: [URL]) throws
    func restoreLibraryFolders() throws -> [URL]
    func audioFiles(in folderURL: URL) async throws -> [URL]
}

enum FileImportServiceError: LocalizedError {
    case bookmarkCreationFailed
    case bookmarkResolutionFailed
    case folderUnavailable
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .bookmarkCreationFailed: "選択したフォルダへのアクセス情報を保存できませんでした。"
        case .bookmarkResolutionFailed: "保存済みの音楽フォルダを開けませんでした。もう一度選択してください。"
        case .folderUnavailable: "選択した音楽フォルダが見つかりません。"
        case .accessDenied: "このフォルダへアクセスする権限がありません。"
        }
    }
}

final class FileImportService: FileImportServicing, @unchecked Sendable {
    private let defaults: UserDefaults
    private let bookmarkKey = "musicLibraryFolderBookmark"
    private let bookmarksKey = "musicLibraryFolderBookmarks"
    private nonisolated static let supportedExtensions: Set<String> = ["m4a", "mp3", "flac", "wav", "aiff", "aif", "aac"]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveLibraryFolders(_ urls: [URL]) throws {
        var bookmarks: [Data] = []
        for url in urls {
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            guard hasAccess || FileManager.default.isReadableFile(atPath: url.path) else {
                throw FileImportServiceError.accessDenied
            }
            do {
                bookmarks.append(try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil))
            } catch {
                throw FileImportServiceError.bookmarkCreationFailed
            }
        }
        defaults.set(bookmarks, forKey: bookmarksKey)
        defaults.removeObject(forKey: bookmarkKey)
    }

    func restoreLibraryFolders() throws -> [URL] {
        let bookmarks = (defaults.array(forKey: bookmarksKey) as? [Data])
            ?? defaults.data(forKey: bookmarkKey).map { [$0] }
            ?? []
        return try bookmarks.map { data in
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            let hasAccess = url.startAccessingSecurityScopedResource()
            defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
            guard hasAccess || FileManager.default.isReadableFile(atPath: url.path),
                  FileManager.default.fileExists(atPath: url.path) else {
                throw FileImportServiceError.folderUnavailable
            }
            return url
        }
    }

    func audioFiles(in folderURL: URL) async throws -> [URL] {
        try await Task.detached(priority: .userInitiated) {
            try Self.scanAudioFiles(in: folderURL)
        }.value
    }

    /// `DirectoryEnumerator` is a synchronous Objective-C iterator. Keeping it in a
    /// nonisolated synchronous function avoids using its iterator from an async context.
    private nonisolated static func scanAudioFiles(in folderURL: URL) throws -> [URL] {
        let hasAccess = folderURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { folderURL.stopAccessingSecurityScopedResource() } }

        guard hasAccess || FileManager.default.isReadableFile(atPath: folderURL.path) else {
            throw FileImportServiceError.accessDenied
        }

        let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey, .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey]
        guard let enumerator = FileManager.default.enumerator(
            at: folderURL,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else {
            throw FileImportServiceError.folderUnavailable
        }

        var files: [URL] = []
        while let url = enumerator.nextObject() as? URL {
            if Task.isCancelled { throw CancellationError() }
            guard supportedExtensions.contains(url.pathExtension.lowercased()) else { continue }
            guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true, values.isHidden != true else { continue }

            // Avoid downloading the user's complete iCloud library during a scan.
            if values.isUbiquitousItem == true,
               values.ubiquitousItemDownloadingStatus == .notDownloaded {
                continue
            }
            files.append(url)
        }
        return files
    }
}
