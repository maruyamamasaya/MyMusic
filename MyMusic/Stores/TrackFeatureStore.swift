import Foundation
import Observation

@MainActor
@Observable
final class TrackFeatureStore {
    private(set) var lastImportDate: Date?
    private(set) var lastImportReport: TrackFeatureImportReport?
    private(set) var isLoaded = false
    private(set) var isProcessing = false
    private(set) var errorMessage: String?

    private var featuresByTrackID: [Track.ID: TrackFeature] = [:]
    private let persistence: TrackFeaturePersistenceServicing
    private let importService: TrackFeatureImportService
    private var isLoading = false
    private var loadWaiters: [CheckedContinuation<Void, Never>] = []

    init(
        persistence: TrackFeaturePersistenceServicing? = nil,
        importService: TrackFeatureImportService = TrackFeatureImportService()
    ) {
        self.persistence = persistence ?? TrackFeaturePersistenceService()
        self.importService = importService
    }

    func loadIfNeeded() async {
        guard !isLoaded else { return }
        if isLoading {
            await withCheckedContinuation { continuation in
                loadWaiters.append(continuation)
            }
            return
        }
        isLoading = true
        defer {
            isLoading = false
            isLoaded = true
            let waiters = loadWaiters
            loadWaiters.removeAll()
            waiters.forEach { $0.resume() }
        }
        do {
            let snapshot = try await persistence.load()
            featuresByTrackID = Dictionary(
                snapshot.features.map { ($0.trackID, $0) },
                uniquingKeysWith: { current, candidate in
                    candidate.analysisVersion >= current.analysisVersion ? candidate : current
                }
            )
            lastImportDate = snapshot.lastImportDate
            lastImportReport = snapshot.lastImportReport
        } catch {
            errorMessage = "音楽特徴量を読み込めませんでした: \(error.localizedDescription)"
        }
    }

    func feature(for trackID: Track.ID) -> TrackFeature? {
        featuresByTrackID[trackID]
    }

    func hasFeature(_ trackID: Track.ID) -> Bool {
        featuresByTrackID[trackID] != nil
    }

    var storedFeatureCount: Int {
        featuresByTrackID.count
    }

    var analysisVersions: [Int] {
        Set(featuresByTrackID.values.map(\.analysisVersion)).sorted()
    }

    func statistics(for tracks: [Track]) -> TrackFeatureStatistics {
        let registeredIDs = Set(tracks.map(\.id))
        return TrackFeatureStatistics(
            registeredTrackCount: registeredIDs.count,
            tracksWithFeatures: registeredIDs.count { featuresByTrackID[$0] != nil }
        )
    }

    func `import`(
        data: Data,
        libraryTracks: [Track],
        now: Date = Date()
    ) async throws -> TrackFeatureImportResult {
        await loadIfNeeded()
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }

        let importService = self.importService
        let preparation = try await Task.detached(priority: .userInitiated) {
            try importService.prepareImport(data: data, libraryTracks: libraryTracks, importedAt: now)
        }.value

        var merged = featuresByTrackID
        var inserted = 0
        var updated = 0
        var skippedOlder = 0
        for incomingFeature in preparation.features {
            var feature = incomingFeature
            if let current = merged[feature.trackID] {
                if feature.analysisVersion < current.analysisVersion {
                    guard feature.values.hasCompleteNormalization else {
                        skippedOlder += 1
                        continue
                    }
                    feature = current.replacingNormalization(with: feature)
                } else {
                    feature = feature.preservingNormalization(from: current)
                }
                updated += 1
            } else {
                inserted += 1
            }
            merged[feature.trackID] = feature
        }

        let unmatchedSamplePaths = Array(preparation.outcomes.lazy.compactMap { outcome in
            if case .unmatched = outcome.status { outcome.relativePath } else { nil }
        }.prefix(20))
        let ambiguousSamplePaths = Array(preparation.outcomes.lazy.compactMap { outcome in
            if case .ambiguous = outcome.status { outcome.relativePath } else { nil }
        }.prefix(20))
        let result = TrackFeatureImportResult(
            analysisVersion: preparation.analysisVersion,
            totalCount: preparation.totalCount,
            matchedCount: preparation.matchedCount,
            unmatchedCount: preparation.unmatchedCount,
            ambiguousCount: preparation.ambiguousCount,
            insertedCount: inserted,
            updatedCount: updated,
            skippedOlderAnalysisCount: skippedOlder,
            unmatchedSamplePaths: unmatchedSamplePaths,
            ambiguousSamplePaths: ambiguousSamplePaths
        )
        let report = TrackFeatureImportReport(
            importedAt: now,
            analysisVersion: result.analysisVersion,
            totalCount: result.totalCount,
            matchedCount: result.matchedCount,
            unmatchedCount: result.unmatchedCount,
            ambiguousCount: result.ambiguousCount,
            insertedCount: result.insertedCount,
            updatedCount: result.updatedCount,
            skippedOlderAnalysisCount: result.skippedOlderAnalysisCount,
            unmatchedSamplePaths: result.unmatchedSamplePaths,
            ambiguousSamplePaths: result.ambiguousSamplePaths
        )

        try await persistence.save(TrackFeaturePersistenceSnapshot(
            features: Array(merged.values),
            lastImportDate: now,
            lastImportReport: report
        ))
        featuresByTrackID = merged
        lastImportDate = now
        lastImportReport = report

        return result
    }

    func deleteAll() async throws {
        await loadIfNeeded()
        isProcessing = true
        errorMessage = nil
        defer { isProcessing = false }
        try await persistence.deleteAll()
        featuresByTrackID.removeAll()
        lastImportDate = nil
        lastImportReport = nil
    }

    func dismissError() {
        errorMessage = nil
    }
}
