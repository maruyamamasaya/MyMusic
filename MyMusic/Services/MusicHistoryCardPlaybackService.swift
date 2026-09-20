import Foundation

/// Resolves card IDs against the current library immediately before playback.
/// A folder scope is opened for the same file checks the player performs later.
final class MusicHistoryCardPlaybackService {
    private let fileImportService: FileImportServicing

    init(fileImportService: FileImportServicing = FileImportService()) {
        self.fileImportService = fileImportService
    }

    func tracksForPlayback(
        _ card: MusicHistoryCardCandidate,
        availableTracks: [Track]
    ) -> [Track] {
        let folders = (try? fileImportService.restoreLibraryFolders()) ?? []
        let accessed = folders.filter { $0.startAccessingSecurityScopedResource() }
        defer { accessed.forEach { $0.stopAccessingSecurityScopedResource() } }
        return MusicHistoryCardService().tracksForPlayback(
            card,
            availableTracks: availableTracks,
            isPlayable: { FileManager.default.isReadableFile(atPath: $0.fileURL.path) }
        )
    }
}
