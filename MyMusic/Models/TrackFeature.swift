import Foundation

nonisolated struct TrackFeatureSourceIdentity: Codable, Hashable, Sendable {
    let relativePath: String
    let fileSize: Int64
    let duration: TimeInterval
    let modificationDate: Date?
    let contentHash: String?
    let title: String?
    let artist: String?
    let album: String?
}

nonisolated struct TrackFeatureValues: Codable, Hashable, Sendable {
    let tempo: Double?
    let energy: Double?
    let piano: Double?
    let ambient: Double?
    let electronic: Double?
    let drumAndBass: Double?
    let aggressive: Double?
    let calm: Double?
    let bright: Double?
    let dark: Double?
    let vocal: Double?
    let instrumental: Double?
    let additional: [String: Double]?
    let integratedLUFS: Double?
    let truePeakDBTP: Double?
    let normalizationGainDB: Double?

    init(
        tempo: Double?,
        energy: Double?,
        piano: Double?,
        ambient: Double?,
        electronic: Double?,
        drumAndBass: Double?,
        aggressive: Double?,
        calm: Double?,
        bright: Double?,
        dark: Double?,
        vocal: Double?,
        instrumental: Double?,
        additional: [String: Double]?,
        integratedLUFS: Double? = nil,
        truePeakDBTP: Double? = nil,
        normalizationGainDB: Double? = nil
    ) {
        self.tempo = tempo
        self.energy = energy
        self.piano = piano
        self.ambient = ambient
        self.electronic = electronic
        self.drumAndBass = drumAndBass
        self.aggressive = aggressive
        self.calm = calm
        self.bright = bright
        self.dark = dark
        self.vocal = vocal
        self.instrumental = instrumental
        self.additional = additional
        self.integratedLUFS = integratedLUFS
        self.truePeakDBTP = truePeakDBTP
        self.normalizationGainDB = normalizationGainDB
    }

    var hasCompleteNormalization: Bool {
        integratedLUFS != nil && truePeakDBTP != nil && normalizationGainDB != nil
    }

    func preservingNormalization(from fallback: TrackFeatureValues) -> TrackFeatureValues {
        guard !hasCompleteNormalization, fallback.hasCompleteNormalization else { return self }
        return replacingNormalization(with: fallback)
    }

    func replacingNormalization(with source: TrackFeatureValues) -> TrackFeatureValues {
        TrackFeatureValues(
            tempo: tempo,
            energy: energy,
            piano: piano,
            ambient: ambient,
            electronic: electronic,
            drumAndBass: drumAndBass,
            aggressive: aggressive,
            calm: calm,
            bright: bright,
            dark: dark,
            vocal: vocal,
            instrumental: instrumental,
            additional: additional,
            integratedLUFS: source.integratedLUFS,
            truePeakDBTP: source.truePeakDBTP,
            normalizationGainDB: source.normalizationGainDB
        )
    }

    var scores: [String: Double] {
        var values = additional ?? [:]
        if let energy { values["energy"] = energy }
        if let piano { values["piano"] = piano }
        if let ambient { values["ambient"] = ambient }
        if let electronic { values["electronic"] = electronic }
        if let drumAndBass { values["drumAndBass"] = drumAndBass }
        if let aggressive { values["aggressive"] = aggressive }
        if let calm { values["calm"] = calm }
        if let bright { values["bright"] = bright }
        if let dark { values["dark"] = dark }
        if let vocal { values["vocal"] = vocal }
        if let instrumental { values["instrumental"] = instrumental }
        return values
    }

    func score(named name: String) -> Double? {
        scores[name]
    }
}

nonisolated struct TrackFeature: Codable, Hashable, Sendable {
    let trackID: Track.ID
    let sourceIdentity: TrackFeatureSourceIdentity
    let analysisVersion: Int
    let analyzedAt: Date
    let importedAt: Date
    let values: TrackFeatureValues

    func preservingNormalization(from fallback: TrackFeature) -> TrackFeature {
        TrackFeature(
            trackID: trackID,
            sourceIdentity: sourceIdentity,
            analysisVersion: analysisVersion,
            analyzedAt: analyzedAt,
            importedAt: importedAt,
            values: values.preservingNormalization(from: fallback.values)
        )
    }

    func replacingNormalization(with source: TrackFeature) -> TrackFeature {
        TrackFeature(
            trackID: trackID,
            sourceIdentity: sourceIdentity,
            analysisVersion: analysisVersion,
            analyzedAt: analyzedAt,
            importedAt: source.importedAt,
            values: values.replacingNormalization(with: source.values)
        )
    }
}

nonisolated struct TrackFeatureImportDocument: Codable, Sendable {
    let schemaVersion: Int
    let analysisVersion: Int
    let generatedAt: Date
    let tracks: [TrackFeatureImportEntry]
}

nonisolated struct TrackFeatureImportEntry: Codable, Sendable {
    let relativePath: String
    let fileSize: Int64
    let duration: TimeInterval
    let modificationDate: Date?
    let contentHash: String?
    let title: String?
    let artist: String?
    let album: String?
    let features: TrackFeatureValues
}

nonisolated struct TrackFeatureStatistics: Sendable {
    let registeredTrackCount: Int
    let tracksWithFeatures: Int

    var tracksWithoutFeatures: Int {
        max(0, registeredTrackCount - tracksWithFeatures)
    }
}

nonisolated struct TrackFeatureImportResult: Sendable {
    let analysisVersion: Int
    let totalCount: Int
    let matchedCount: Int
    let unmatchedCount: Int
    let ambiguousCount: Int
    let insertedCount: Int
    let updatedCount: Int
    let skippedOlderAnalysisCount: Int
    let unmatchedSamplePaths: [String]
    let ambiguousSamplePaths: [String]
}

nonisolated struct TrackFeatureImportReport: Codable, Hashable, Sendable {
    let importedAt: Date
    let analysisVersion: Int
    let totalCount: Int
    let matchedCount: Int
    let unmatchedCount: Int
    let ambiguousCount: Int
    let insertedCount: Int
    let updatedCount: Int
    let skippedOlderAnalysisCount: Int
    let unmatchedSamplePaths: [String]
    let ambiguousSamplePaths: [String]
}
