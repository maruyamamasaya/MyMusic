import Foundation

protocol PlaybackHistoryPersistenceServicing: Sendable {
    func load() async throws -> [PlaybackHistory]
    func save(_ history: [PlaybackHistory]) async throws
}

actor PlaybackHistoryPersistenceService: PlaybackHistoryPersistenceServicing {
    private let fileManager: FileManager
    private let fileURL: URL

    init(fileManager: FileManager = .default, fileURL: URL? = nil) {
        self.fileManager = fileManager
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let applicationSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = applicationSupport.appending(path: "MyMusic/playback-history.json")
        }
    }

    func load() async throws -> [PlaybackHistory] {
        guard fileManager.fileExists(atPath: fileURL.path) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([PlaybackHistory].self, from: Data(contentsOf: fileURL))
    }

    func save(_ history: [PlaybackHistory]) async throws {
        try fileManager.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(history).write(to: fileURL, options: .atomic)
    }
}
