import Foundation

nonisolated struct TrackFeaturePersistenceSnapshot: Sendable {
    let features: [TrackFeature]
    let lastImportDate: Date?
    let lastImportReport: TrackFeatureImportReport?

    init(
        features: [TrackFeature],
        lastImportDate: Date?,
        lastImportReport: TrackFeatureImportReport? = nil
    ) {
        self.features = features
        self.lastImportDate = lastImportDate
        self.lastImportReport = lastImportReport
    }
}

nonisolated protocol TrackFeaturePersistenceServicing: Sendable {
    func load() async throws -> TrackFeaturePersistenceSnapshot
    func save(_ snapshot: TrackFeaturePersistenceSnapshot) async throws
    func deleteAll() async throws
}

actor TrackFeaturePersistenceService: TrackFeaturePersistenceServicing {
    private struct Document: Codable {
        let version: Int
        let lastImportDate: Date?
        let lastImportReport: TrackFeatureImportReport?
        let features: [TrackFeature]
    }

    private let fileURL: URL

    init(fileURL: URL? = nil) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.fileURL = applicationSupport.appending(path: "MyMusic/track-features.json")
        }
    }

    func load() async throws -> TrackFeaturePersistenceSnapshot {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return TrackFeaturePersistenceSnapshot(features: [], lastImportDate: nil)
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document = try decoder.decode(Document.self, from: Data(contentsOf: fileURL))
        guard document.version == 1 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return TrackFeaturePersistenceSnapshot(
            features: document.features,
            lastImportDate: document.lastImportDate,
            lastImportReport: document.lastImportReport
        )
    }

    func save(_ snapshot: TrackFeaturePersistenceSnapshot) async throws {
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let document = Document(
            version: 1,
            lastImportDate: snapshot.lastImportDate,
            lastImportReport: snapshot.lastImportReport,
            features: snapshot.features.sorted { $0.trackID.uuidString < $1.trackID.uuidString }
        )
        try encoder.encode(document).write(to: fileURL, options: .atomic)
    }

    func deleteAll() async throws {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        try FileManager.default.removeItem(at: fileURL)
    }
}
