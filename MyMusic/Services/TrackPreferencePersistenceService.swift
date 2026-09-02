import Foundation

protocol TrackPreferencePersistenceServicing: Sendable {
    func load() async throws -> [TrackPreference]?
    func save(_ preferences: [TrackPreference]) async throws
}

actor TrackPreferencePersistenceService: TrackPreferencePersistenceServicing {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(applicationDirectory: URL? = nil) {
        let root = applicationDirectory ?? FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0].appending(path: "MyMusic")
        fileURL = root.appending(path: "track-preferences.json")
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    func load() async throws -> [TrackPreference]? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let document = try decoder.decode(TrackPreferencesDocument.self, from: Data(contentsOf: fileURL))
        guard document.schemaVersion == 2 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return document.tracks
    }

    func save(_ preferences: [TrackPreference]) async throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        let sorted = preferences.sorted { $0.trackID.uuidString < $1.trackID.uuidString }
        let data = try encoder.encode(TrackPreferencesDocument(schemaVersion: 2, tracks: sorted))
        try data.write(to: fileURL, options: .atomic)
        let verified = try decoder.decode(TrackPreferencesDocument.self, from: Data(contentsOf: fileURL))
        guard verified.schemaVersion == 2, verified.tracks == sorted else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}
