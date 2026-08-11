import Foundation
import Observation

@MainActor
@Observable
final class LibraryStore {
    private(set) var tracks: [Track] = []
    private(set) var albums: [Album] = []
    private(set) var artists: [Artist] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var selectedFolderName: String?

    var hasLibraryFolder: Bool { selectedFolderURL != nil }
    var scanProgress: Int { tracks.count }

    private var selectedFolderURL: URL?
    private var hasRestoredFolder = false
    private let service: MusicLibraryServicing
    private let fileImportService: FileImportServicing

    init(
        service: MusicLibraryServicing? = nil,
        fileImportService: FileImportServicing? = nil
    ) {
        let resolvedFileImportService = fileImportService ?? FileImportService()
        self.fileImportService = resolvedFileImportService
        self.service = service ?? MusicLibraryService(fileImportService: resolvedFileImportService)
    }

    func restoreAndLoadIfNeeded() async {
        guard !hasRestoredFolder else { return }
        hasRestoredFolder = true
        do {
            guard let folderURL = try fileImportService.restoreLibraryFolder() else { return }
            selectedFolderURL = folderURL
            selectedFolderName = displayName(for: folderURL)
            await scan(folderURL)
        } catch {
            fileImportService.removeLibraryFolder()
            errorMessage = error.localizedDescription
        }
    }

    func selectFolder(_ folderURL: URL) async {
        errorMessage = nil
        do {
            try fileImportService.saveLibraryFolder(folderURL)
            selectedFolderURL = folderURL
            selectedFolderName = displayName(for: folderURL)
            await scan(folderURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rescan() async {
        guard let selectedFolderURL else {
            errorMessage = "先に音楽フォルダを選択してください。"
            return
        }
        await scan(selectedFolderURL)
    }

    func dismissError() { errorMessage = nil }

    func reportFolderImportFailure(_ error: Error) {
        let nsError = error as NSError
        guard nsError.code != NSUserCancelledError else { return }
        errorMessage = "フォルダを選択できませんでした: \(error.localizedDescription)"
    }

    private func scan(_ folderURL: URL) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let library = try await service.loadLibrary(from: folderURL)
            tracks = library.tracks
            albums = library.albums
            artists = library.artists
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func displayName(for url: URL) -> String {
        let parent = url.deletingLastPathComponent().lastPathComponent
        return parent.isEmpty ? url.lastPathComponent : "\(parent) / \(url.lastPathComponent)"
    }
}
