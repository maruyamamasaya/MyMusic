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
        previousTracks: [Track]
    ) async throws -> MusicLibrary {
        await acquireScanPermit()
        defer { releaseScanPermit() }

        try Task.checkCancellation()
        let library = try await service.loadLibrary(from: folderURL, previousTracks: previousTracks)
        try Task.checkCancellation()
        return library
    }

    func save(_ library: MusicLibrary, for folderURL: URL) async throws {
        try await persistence.save(library, for: folderURL)
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
