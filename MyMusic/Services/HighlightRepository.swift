import Foundation

nonisolated protocol HighlightRepositoryServicing: Sendable {
    func data(for trackID: Track.ID) async -> TrackHighlightData?
    func save(_ data: TrackHighlightData) async
}

actor HighlightRepository: HighlightRepositoryServicing {
    private let fileURL: URL
    private var cachedData: [Track.ID: TrackHighlightData]?

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let applicationSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            )[0]
            self.fileURL = applicationSupport.appending(path: "MyMusic/highlights.json")
        }
    }

    func data(for trackID: Track.ID) async -> TrackHighlightData? {
        loadIfNeeded()[trackID]
    }

    func save(_ data: TrackHighlightData) async {
        var values = loadIfNeeded()
        values[data.trackID] = data
        cachedData = values

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(values).write(to: fileURL, options: .atomic)
        } catch {
            // Analysis remains usable in memory if the cache cannot be written.
        }
    }

    private func loadIfNeeded() -> [Track.ID: TrackHighlightData] {
        if let cachedData { return cachedData }
        let loaded = (try? Data(contentsOf: fileURL))
            .flatMap { try? JSONDecoder().decode([Track.ID: TrackHighlightData].self, from: $0) }
            ?? [:]
        cachedData = loaded
        return loaded
    }
}
