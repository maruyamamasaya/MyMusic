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
    private(set) var isInitialLoadComplete = false

    var hasLibraryFolder: Bool { selectedFolderURL != nil }
    var scanProgress: Int { tracks.count }

    private var selectedFolderURL: URL?
    private var hasRestoredFolder = false
    private let service: MusicLibraryServicing
    private let fileImportService: FileImportServicing
    private let persistence: LibraryPersistenceServicing

    init(
        service: MusicLibraryServicing? = nil,
        fileImportService: FileImportServicing? = nil,
        persistence: LibraryPersistenceServicing? = nil
    ) {
        let resolvedFileImportService = fileImportService ?? FileImportService()
        self.fileImportService = resolvedFileImportService
        self.service = service ?? MusicLibraryService(fileImportService: resolvedFileImportService)
        self.persistence = persistence ?? LibraryPersistenceService()
    }

    func restoreAndLoadIfNeeded() async {
        guard !hasRestoredFolder else { return }
        hasRestoredFolder = true
        defer { isInitialLoadComplete = true }
        do {
            guard let folderURL = try fileImportService.restoreLibraryFolder() else { return }
            selectedFolderURL = folderURL
            selectedFolderName = displayName(for: folderURL)
            if let cachedLibrary = try? await persistence.load(for: folderURL) {
                apply(cachedLibrary)
            } else {
                await scan(folderURL)
            }
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
            apply(library)
            do {
                try await persistence.save(library, for: folderURL)
            } catch {
                errorMessage = "ライブラリ情報を保存できませんでした: \(error.localizedDescription)"
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ library: MusicLibrary) {
        tracks = library.tracks
        albums = library.albums
        artists = library.artists
    }

    private func displayName(for url: URL) -> String {
        let parent = url.deletingLastPathComponent().lastPathComponent
        return parent.isEmpty ? url.lastPathComponent : "\(parent) / \(url.lastPathComponent)"
    }
}
