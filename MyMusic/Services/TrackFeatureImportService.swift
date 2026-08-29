import Foundation

nonisolated enum TrackFeatureImportError: LocalizedError {
    case invalidJSON
    case missingSchemaVersion
    case unsupportedSchemaVersion(Int)
    case invalidAnalysisVersion
    case invalidEntry(index: Int, reason: String)

    var errorDescription: String? {
        switch self {
        case .invalidJSON:
            "特徴量JSONを解析できませんでした。"
        case .missingSchemaVersion:
            "schemaVersionがありません。"
        case .unsupportedSchemaVersion(let version):
            "schemaVersion \(version) には対応していません。対応バージョンは1です。"
        case .invalidAnalysisVersion:
            "analysisVersionは1以上の整数にしてください。"
        case .invalidEntry(let index, let reason):
            "tracks[\(index)]が不正です: \(reason)"
        }
    }
}

nonisolated enum TrackFeatureMatchStatus: Sendable {
    case matched(Track.ID)
    case unmatched
    case ambiguous
}

nonisolated struct TrackFeatureMatchOutcome: Sendable {
    let entryIndex: Int
    let relativePath: String
    let status: TrackFeatureMatchStatus
}

nonisolated struct TrackFeatureImportPreparation: Sendable {
    let analysisVersion: Int
    let totalCount: Int
    let features: [TrackFeature]
    let outcomes: [TrackFeatureMatchOutcome]

    var matchedCount: Int { features.count }
    var unmatchedCount: Int {
        outcomes.count { if case .unmatched = $0.status { true } else { false } }
    }
    var ambiguousCount: Int {
        outcomes.count { if case .ambiguous = $0.status { true } else { false } }
    }
}

nonisolated struct TrackFeatureImportService: Sendable {
    static let supportedSchemaVersion = 1
    static let durationTolerance: TimeInterval = 0.5

    nonisolated func prepareImport(
        data: Data,
        libraryTracks: [Track],
        importedAt: Date = Date()
    ) throws -> TrackFeatureImportPreparation {
        let document = try decodeAndValidate(data)
        let pathIndex = Dictionary(grouping: libraryTracks.compactMap { track -> (String, Track)? in
            guard let path = track.relativePath,
                  let normalized = Self.normalizedRelativePath(path) else { return nil }
            return (normalized, track)
        }, by: { $0.0 }).mapValues { $0.map(\.1) }
        let sizeIndex = Dictionary(grouping: libraryTracks.compactMap { track -> (Int64, Track)? in
            track.fileSize.map { ($0, track) }
        }, by: { $0.0 }).mapValues { $0.map(\.1) }

        var features: [TrackFeature] = []
        var outcomes: [TrackFeatureMatchOutcome] = []
        features.reserveCapacity(document.tracks.count)
        outcomes.reserveCapacity(document.tracks.count)

        for (index, entry) in document.tracks.enumerated() {
            let normalizedPath = Self.normalizedRelativePath(entry.relativePath)!
            let sourceIdentity = TrackFeatureSourceIdentity(
                relativePath: normalizedPath,
                fileSize: entry.fileSize,
                duration: entry.duration,
                modificationDate: entry.modificationDate,
                contentHash: entry.contentHash?.lowercased(),
                title: Self.trimmed(entry.title),
                artist: Self.trimmed(entry.artist),
                album: Self.trimmed(entry.album)
            )
            let status = match(
                entry: entry,
                normalizedPath: normalizedPath,
                pathCandidates: pathIndex[normalizedPath] ?? [],
                sizeCandidates: sizeIndex[entry.fileSize] ?? []
            )
            outcomes.append(TrackFeatureMatchOutcome(
                entryIndex: index,
                relativePath: normalizedPath,
                status: status
            ))
            guard case .matched(let trackID) = status else { continue }
            features.append(TrackFeature(
                trackID: trackID,
                sourceIdentity: sourceIdentity,
                analysisVersion: document.analysisVersion,
                analyzedAt: document.generatedAt,
                importedAt: importedAt,
                values: entry.features
            ))
        }

        return TrackFeatureImportPreparation(
            analysisVersion: document.analysisVersion,
            totalCount: document.tracks.count,
            features: features,
            outcomes: outcomes
        )
    }

    private nonisolated func decodeAndValidate(_ data: Data) throws -> TrackFeatureImportDocument {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw TrackFeatureImportError.invalidJSON
        }
        guard let root = object as? [String: Any] else {
            throw TrackFeatureImportError.invalidJSON
        }
        let rootKeys: Set<String> = ["schemaVersion", "analysisVersion", "generatedAt", "tracks"]
        guard Set(root.keys).isSubset(of: rootKeys) else {
            throw TrackFeatureImportError.invalidJSON
        }
        guard let schemaVersion = root["schemaVersion"] as? Int else {
            throw TrackFeatureImportError.missingSchemaVersion
        }
        guard schemaVersion == Self.supportedSchemaVersion else {
            throw TrackFeatureImportError.unsupportedSchemaVersion(schemaVersion)
        }
        if let rawTracks = root["tracks"] as? [[String: Any]] {
            let entryKeys: Set<String> = [
                "relativePath", "fileSize", "duration", "modificationDate", "contentHash",
                "title", "artist", "album", "features"
            ]
            let featureKeys: Set<String> = [
                "tempo", "energy", "piano", "ambient", "electronic", "drumAndBass",
                "aggressive", "calm", "bright", "dark", "vocal", "instrumental", "additional",
                "integratedLUFS", "truePeakDBTP", "normalizationGainDB"
            ]
            for (index, rawTrack) in rawTracks.enumerated() {
                let unknownEntryKeys = Set(rawTrack.keys).subtracting(entryKeys)
                guard unknownEntryKeys.isEmpty else {
                    throw TrackFeatureImportError.invalidEntry(
                        index: index,
                        reason: "未対応フィールドがあります: \(unknownEntryKeys.sorted().joined(separator: ", "))"
                    )
                }
                if let rawFeatures = rawTrack["features"] as? [String: Any] {
                    let unknownFeatureKeys = Set(rawFeatures.keys).subtracting(featureKeys)
                    guard unknownFeatureKeys.isEmpty else {
                        throw TrackFeatureImportError.invalidEntry(
                            index: index,
                            reason: "featuresに未対応フィールドがあります: \(unknownFeatureKeys.sorted().joined(separator: ", "))"
                        )
                    }
                }
            }
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let value = try decoder.singleValueContainer().decode(String.self)
            guard let date = Self.iso8601Date(from: value) else {
                throw DecodingError.dataCorruptedError(
                    in: try decoder.singleValueContainer(),
                    debugDescription: "Expected an RFC 3339 date-time."
                )
            }
            return date
        }
        let document: TrackFeatureImportDocument
        do {
            document = try decoder.decode(TrackFeatureImportDocument.self, from: data)
        } catch {
            throw TrackFeatureImportError.invalidJSON
        }
        guard document.analysisVersion > 0 else {
            throw TrackFeatureImportError.invalidAnalysisVersion
        }
        for (index, entry) in document.tracks.enumerated() {
            try validate(entry, at: index)
        }
        return document
    }

    private nonisolated func validate(_ entry: TrackFeatureImportEntry, at index: Int) throws {
        guard Self.normalizedRelativePath(entry.relativePath) != nil else {
            throw TrackFeatureImportError.invalidEntry(index: index, reason: "relativePathは安全な相対パスにしてください。")
        }
        guard entry.fileSize > 0 else {
            throw TrackFeatureImportError.invalidEntry(index: index, reason: "fileSizeは1以上にしてください。")
        }
        guard entry.duration.isFinite, entry.duration > 0 else {
            throw TrackFeatureImportError.invalidEntry(index: index, reason: "durationは0より大きい有限値にしてください。")
        }
        if let contentHash = entry.contentHash {
            let scalarSet = CharacterSet(charactersIn: contentHash)
            guard contentHash.count == 64,
                  scalarSet.isSubset(of: CharacterSet(charactersIn: "0123456789abcdefABCDEF")) else {
                throw TrackFeatureImportError.invalidEntry(index: index, reason: "contentHashは64桁のSHA-256 hexadecimalにしてください。")
            }
        }
        if let tempo = entry.features.tempo, (!tempo.isFinite || tempo <= 0) {
            throw TrackFeatureImportError.invalidEntry(index: index, reason: "tempoは0より大きい有限値にしてください。")
        }
        let loudnessValues = [
            entry.features.integratedLUFS,
            entry.features.truePeakDBTP,
            entry.features.normalizationGainDB
        ]
        let presentLoudnessValueCount = loudnessValues.compactMap { $0 }.count
        guard presentLoudnessValueCount == 0 || presentLoudnessValueCount == loudnessValues.count else {
            throw TrackFeatureImportError.invalidEntry(
                index: index,
                reason: "integratedLUFS、truePeakDBTP、normalizationGainDBは3項目を揃えてください。"
            )
        }
        if presentLoudnessValueCount > 0 {
            guard loudnessValues.allSatisfy({ $0?.isFinite == true }) else {
                throw TrackFeatureImportError.invalidEntry(index: index, reason: "音量解析値は有限値にしてください。")
            }
            guard let gain = entry.features.normalizationGainDB, (-4 ... 4).contains(gain) else {
                throw TrackFeatureImportError.invalidEntry(index: index, reason: "normalizationGainDBは-4.0...4.0にしてください。")
            }
        }

        let fixedNames = Set([
            "energy", "piano", "ambient", "electronic", "drumAndBass", "aggressive",
            "calm", "bright", "dark", "vocal", "instrumental"
        ])
        if let additional = entry.features.additional,
           !fixedNames.isDisjoint(with: additional.keys) {
            throw TrackFeatureImportError.invalidEntry(index: index, reason: "additionalに標準特徴量と同じキーを含めないでください。")
        }
        for (name, value) in entry.features.scores {
            guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  value.isFinite, (0 ... 1).contains(value) else {
                throw TrackFeatureImportError.invalidEntry(index: index, reason: "特徴量\(name)は0.0...1.0の有限値にしてください。")
            }
        }
        guard entry.features.tempo != nil || !entry.features.scores.isEmpty || entry.features.hasCompleteNormalization else {
            throw TrackFeatureImportError.invalidEntry(index: index, reason: "featuresが空です。")
        }
    }

    private nonisolated func match(
        entry: TrackFeatureImportEntry,
        normalizedPath: String,
        pathCandidates: [Track],
        sizeCandidates: [Track]
    ) -> TrackFeatureMatchStatus {
        if !pathCandidates.isEmpty {
            let verified = pathCandidates.filter { matchesFileProperties($0, entry: entry) }
            if verified.count == 1 { return .matched(verified[0].id) }
            return verified.isEmpty ? .unmatched : .ambiguous
        }

        guard Self.trimmed(entry.title) != nil,
              Self.trimmed(entry.artist) != nil else { return .unmatched }
        let fallback = sizeCandidates.filter {
            matchesFileProperties($0, entry: entry) && matchesMetadata($0, entry: entry)
        }
        if fallback.count == 1 { return .matched(fallback[0].id) }
        return fallback.isEmpty ? .unmatched : .ambiguous
    }

    private nonisolated func matchesFileProperties(_ track: Track, entry: TrackFeatureImportEntry) -> Bool {
        track.fileSize == entry.fileSize
            && track.duration.isFinite
            && abs(track.duration - entry.duration) <= Self.durationTolerance
    }

    private nonisolated func matchesMetadata(_ track: Track, entry: TrackFeatureImportEntry) -> Bool {
        guard Self.normalizedMetadata(track.title) == Self.normalizedMetadata(entry.title),
              Self.normalizedMetadata(track.artistName) == Self.normalizedMetadata(entry.artist) else { return false }
        guard let album = Self.trimmed(entry.album) else { return true }
        return Self.normalizedMetadata(track.albumTitle) == Self.normalizedMetadata(album)
    }

    private nonisolated static func normalizedRelativePath(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\", with: "/")
        guard !trimmed.isEmpty, !trimmed.hasPrefix("/") else { return nil }
        let components = trimmed.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        guard !components.isEmpty,
              components.allSatisfy({ $0 != "." && $0 != ".." }) else { return nil }
        return components.joined(separator: "/").precomposedStringWithCanonicalMapping
    }

    private nonisolated static func trimmed(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private nonisolated static func normalizedMetadata(_ value: String?) -> String? {
        trimmed(value)?.precomposedStringWithCanonicalMapping.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }

    private nonisolated static func iso8601Date(from value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
