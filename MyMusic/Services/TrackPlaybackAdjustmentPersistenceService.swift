import Foundation

protocol TrackPlaybackAdjustmentPersistenceServicing: Sendable {
    func load(trackID: Track.ID) async throws -> TrackPlaybackAdjustment?
    func save(_ adjustment: TrackPlaybackAdjustment) async throws
}

actor TrackPlaybackAdjustmentPersistenceService: TrackPlaybackAdjustmentPersistenceServicing {
    private let rootURL: URL

    init(rootURL: URL? = nil) {
        if let rootURL {
            self.rootURL = rootURL
        } else {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            self.rootURL = applicationSupport.appending(path: "MyMusic/TrackPlaybackAdjustments")
        }
    }

    func load(trackID: Track.ID) async throws -> TrackPlaybackAdjustment? {
        let fileURL = fileURL(for: trackID)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TrackPlaybackAdjustment.self, from: Data(contentsOf: fileURL))
    }

    func save(_ adjustment: TrackPlaybackAdjustment) async throws {
        let fileURL = fileURL(for: adjustment.trackID)
        let fileManager = FileManager.default
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        if fileManager.fileExists(atPath: fileURL.path),
           let existing = try? await load(trackID: adjustment.trackID),
           existing.updatedAt > adjustment.updatedAt {
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(adjustment).write(to: fileURL, options: .atomic)
    }

    private func fileURL(for trackID: Track.ID) -> URL {
        let identifier = trackID.uuidString.lowercased()
        let shard = String(identifier.prefix(2))
        return rootURL.appending(path: shard).appending(path: "\(identifier).json")
    }
}
