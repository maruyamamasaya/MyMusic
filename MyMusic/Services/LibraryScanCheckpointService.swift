import Foundation

nonisolated struct LibraryScanCheckpointEntry: Codable, Sendable {
    let track: Track
    let refreshedAt: Date
}

protocol LibraryScanCheckpointServicing: Sendable {
    func recentEntries(for folderURL: URL, since cutoff: Date) async -> [String: LibraryScanCheckpointEntry]
    func append(_ entries: [String: LibraryScanCheckpointEntry], for folderURL: URL) async
    func remove(for folderURL: URL) async
}

actor LibraryScanCheckpointService: LibraryScanCheckpointServicing {
    private struct Batch: Codable {
        let version: Int
        let folderPath: String
        let entries: [String: LibraryScanCheckpointEntry]
    }

    // Read compatibility for checkpoints created before the append-only format.
    private struct Snapshot: Codable {
        let folderPath: String
        let entries: [String: LibraryScanCheckpointEntry]
    }

    private nonisolated static let currentVersion = 2
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
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        let folderPath = normalizedPath(for: folderURL)
        let decoder = JSONDecoder()
        let entries: [String: LibraryScanCheckpointEntry]
        if let snapshot = try? decoder.decode(Snapshot.self, from: data),
           snapshot.folderPath == folderPath {
            entries = snapshot.entries
        } else {
            var merged: [String: LibraryScanCheckpointEntry] = [:]
            for line in data.split(separator: 0x0A) {
                guard let batch = try? decoder.decode(Batch.self, from: Data(line)),
                      batch.version == Self.currentVersion,
                      batch.folderPath == folderPath else { continue }
                merged.merge(batch.entries) { _, latest in latest }
            }
            entries = merged
        }
        let recent = entries.filter { $0.value.refreshedAt >= cutoff }
        if recent.isEmpty {
            try? FileManager.default.removeItem(at: fileURL)
        } else {
            // Compact once at resume. During scanning all later writes are small appends.
            try? replaceFile(with: recent, folderPath: folderPath, at: fileURL)
        }
        return recent
    }

    func append(_ entries: [String: LibraryScanCheckpointEntry], for folderURL: URL) async {
        guard !entries.isEmpty else { return }
        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let batch = Batch(
                version: Self.currentVersion,
                folderPath: normalizedPath(for: folderURL),
                entries: entries
            )
            var data = try JSONEncoder().encode(batch)
            data.append(0x0A)
            let fileURL = checkpointURL(for: folderURL)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                let handle = try FileHandle(forWritingTo: fileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: fileURL, options: .atomic)
            }
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

    private func replaceFile(
        with entries: [String: LibraryScanCheckpointEntry],
        folderPath: String,
        at fileURL: URL
    ) throws {
        let batch = Batch(version: Self.currentVersion, folderPath: folderPath, entries: entries)
        var data = try JSONEncoder().encode(batch)
        data.append(0x0A)
        try data.write(to: fileURL, options: .atomic)
    }

    private func normalizedPath(for url: URL) -> String {
        url.resolvingSymlinksInPath().standardizedFileURL.path
            .precomposedStringWithCanonicalMapping
    }
}
