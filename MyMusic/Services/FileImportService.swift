import Foundation

protocol FileImportServicing: Sendable {
    func saveLibraryFolder(_ url: URL) throws
    func restoreLibraryFolder() throws -> URL?
    func removeLibraryFolder()
    func audioFiles(in folderURL: URL) async throws -> [URL]
}

enum FileImportServiceError: LocalizedError {
    case bookmarkCreationFailed
    case bookmarkResolutionFailed
    case folderUnavailable
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .bookmarkCreationFailed: "The selected folder could not be saved."
        case .bookmarkResolutionFailed: "The saved music folder could not be opened. Please select it again."
        case .folderUnavailable: "The selected music folder is no longer available."
        case .accessDenied: "MyMusic does not have permission to access this folder."
        }
    }
}

final class FileImportService: FileImportServicing, @unchecked Sendable {
    private let defaults: UserDefaults
    private let bookmarkKey = "musicLibraryFolderBookmark"
    private static let supportedExtensions: Set<String> = ["m4a", "mp3", "flac", "wav", "aiff", "aif", "aac"]

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func saveLibraryFolder(_ url: URL) throws {
        do {
            let data = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
            defaults.set(data, forKey: bookmarkKey)
        } catch {
            throw FileImportServiceError.bookmarkCreationFailed
        }
    }

    func restoreLibraryFolder() throws -> URL? {
        guard let data = defaults.data(forKey: bookmarkKey) else { return nil }
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw FileImportServiceError.folderUnavailable
            }
            if isStale { try saveLibraryFolder(url) }
            return url
        } catch let error as FileImportServiceError {
            throw error
        } catch {
            throw FileImportServiceError.bookmarkResolutionFailed
        }
    }

    func removeLibraryFolder() {
        defaults.removeObject(forKey: bookmarkKey)
    }

    func audioFiles(in folderURL: URL) async throws -> [URL] {
        try await Task.detached(priority: .userInitiated) {
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
            for case let url as URL in enumerator {
                try Task.checkCancellation()
                guard Self.supportedExtensions.contains(url.pathExtension.lowercased()) else { continue }
                guard let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true, values.isHidden != true else { continue }

                // Do not trigger a download of the user's full iCloud library. Metadata is read only
                // for files that Files has already made locally available.
                if values.isUbiquitousItem == true,
                   values.ubiquitousItemDownloadingStatus == .notDownloaded {
                    continue
                }
                files.append(url)
            }
            return files
        }.value
    }
}
