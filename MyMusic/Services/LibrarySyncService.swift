import Foundation

/// Owns the expensive, serial portion of library synchronization.
///
/// LibraryStore remains MainActor-isolated for UI state, while scanning, identity
/// matching, persistence, and derived-library construction run on this actor.
actor LibrarySyncService {
    private let service: MusicLibraryServicing
    private let persistence: LibraryPersistenceServicing
    private var isScanning = false
    private var scanWaiters: [CheckedContinuation<Void, Never>] = []

    init(service: MusicLibraryServicing, persistence: LibraryPersistenceServicing) {
        self.service = service
        self.persistence = persistence
    }

    func scan(
        folderURL: URL,
        previousTracks: [Track],
        depth: LibraryScanDepth = .quick,
        progress: @escaping @Sendable (LibraryScanProgress) async -> Void = { _ in }
    ) async throws -> MusicLibraryScanResult {
        await acquireScanPermit()
        defer { releaseScanPermit() }

        try Task.checkCancellation()
        let result = try await service.loadLibraryReport(
            from: folderURL,
            previousTracks: previousTracks,
            depth: depth,
            progress: progress
        )
        try Task.checkCancellation()
        return result
    }

    func save(
        _ library: MusicLibrary,
        for folderURL: URL,
        completedScanDepth: LibraryScanDepth? = nil
    ) async throws {
        try await persistence.save(library, for: folderURL)
        if completedScanDepth == .complete {
            await service.removeCompleteScanCheckpoint(for: folderURL)
        }
    }

    func combinedLibrary(
        folderIDs: [String],
        librariesByFolderID: [String: MusicLibrary]
    ) -> MusicLibrary {
        var seenPaths: Set<String> = []
        var combined: [Track] = []
        for folderID in folderIDs {
            for track in librariesByFolderID[folderID]?.tracks ?? [] {
                let path = track.fileURL.resolvingSymlinksInPath().standardizedFileURL.path
                if seenPaths.insert(path).inserted { combined.append(track) }
            }
        }
        return MusicLibrary.build(from: combined)
    }

    private func acquireScanPermit() async {
        if !isScanning {
            isScanning = true
            return
        }
        await withCheckedContinuation { continuation in
            scanWaiters.append(continuation)
        }
    }

    private func releaseScanPermit() {
        if scanWaiters.isEmpty {
            isScanning = false
        } else {
            scanWaiters.removeFirst().resume()
        }
    }
}
