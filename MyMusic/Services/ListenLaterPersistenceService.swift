import Foundation

protocol ListenLaterPersistenceServicing: Sendable {
    func load() async throws -> [ListenLaterEntry]
    func save(_ entries: [ListenLaterEntry]) async throws
}

actor ListenLaterPersistenceService: ListenLaterPersistenceServicing {
    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            self.fileURL = applicationSupport.appending(path: "MyMusic/listen-later.json")
        }
    }

    func load() async throws -> [ListenLaterEntry] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        return try JSONDecoder().decode([ListenLaterEntry].self, from: Data(contentsOf: fileURL))
    }

    func save(_ entries: [ListenLaterEntry]) async throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(entries).write(to: fileURL, options: .atomic)
    }
}
