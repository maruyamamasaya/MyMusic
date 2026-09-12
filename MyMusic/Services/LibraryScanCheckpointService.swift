import Foundation

nonisolated struct LibraryScanCheckpointEntry: Codable, Sendable {
    let track: Track
    let refreshedAt: Date
}

protocol LibraryScanCheckpointServicing: Sendable {
    func recentEntries(for folderURL: URL, since cutoff: Date) async -> [String: LibraryScanCheckpointEntry]
    func save(_ entries: [String: LibraryScanCheckpointEntry], for folderURL: URL) async
    func remove(for folderURL: URL) async
}

actor LibraryScanCheckpointService: LibraryScanCheckpointServicing {
    private struct Snapshot: Codable {
        let folderPath: String
        let entries: [String: LibraryScanCheckpointEntry]
    }

    private let directoryURL: URL

    init(directoryURL: URL? = nil) {
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            self.directoryURL = applicationSupport.appending(
                path: "MyMusic/LibraryScanCheckpoints",
                directoryHint: .isDirectory
            )
        }
    }

    func recentEntries(for folderURL: URL, since cutoff: Date) async -> [String: LibraryScanCheckpointEntry] {
        let fileURL = checkpointURL(for: folderURL)
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data),
              snapshot.folderPath == normalizedPath(for: folderURL) else {
            return [:]
        }
        let recent = snapshot.entries.filter { $0.value.refreshedAt >= cutoff }
        if recent.isEmpty {
            try? FileManager.default.removeItem(at: fileURL)
        }
        return recent
    }

    func save(_ entries: [String: LibraryScanCheckpointEntry], for folderURL: URL) async {
        guard !entries.isEmpty else { return }
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let snapshot = Snapshot(folderPath: normalizedPath(for: folderURL), entries: entries)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(snapshot).write(to: checkpointURL(for: folderURL), options: .atomic)
        } catch {
            // A checkpoint is an optimization only. A write failure must not fail library synchronization.
        }
    }

    func remove(for folderURL: URL) async {
        try? FileManager.default.removeItem(at: checkpointURL(for: folderURL))
    }

    private func checkpointURL(for folderURL: URL) -> URL {
        let identifier = StableTrackIdentifier.id(
            for: "library-scan-checkpoint:\(normalizedPath(for: folderURL))"
        ).uuidString
        return directoryURL.appending(path: "\(identifier).json")
    }

    private func normalizedPath(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
            .precomposedStringWithCanonicalMapping
    }
}
