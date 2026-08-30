import CoreTransferable
import Foundation
import UniformTypeIdentifiers

struct MusicExportFile: Transferable {
    let data: Data
    let filename: String
    let contentType: UTType

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .data) { export in
            let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appending(path: export.filename)
            try export.data.write(to: url, options: .atomic)
            return SentTransferredFile(url)
        }
    }
}

struct MusicDataExportService {
    private struct TrackFeatureDocument: Codable {
        let version: Int
        let exportedAt: Date
        let tracks: [TrackFeatureDocumentItem]
    }

    private struct TrackFeatureDocumentItem: Codable {
        let trackID: UUID
        let title: String?
        let artist: String?
        let sourceIdentity: TrackFeatureSourceIdentity
        let analysisVersion: Int
        let analyzedAt: Date
        let importedAt: Date
        let features: TrackFeatureValues
    }

    private struct VolumeNormalizationDocument: Codable {
        let version: Int
        let exportedAt: Date
        let isEnabled: Bool
        let tracks: [VolumeNormalizationDocumentItem]
    }

    private struct VolumeNormalizationDocumentItem: Codable {
        let trackID: UUID
        let title: String?
        let artist: String?
        let relativePath: String
        let integratedLUFS: Double
        let truePeakDBTP: Double
        let normalizationGainDB: Double
    }

    private struct PlaylistDocument: Codable {
        let version: Int
        let name: String
        let playlistID: UUID
        let createdAt: Date
        let updatedAt: Date
        let kind: PlaylistKind
        let tags: [String]
        let tracks: [TrackDocument]
    }

    private struct PlaylistsDocument: Codable {
        let version: Int
        let playlists: [PlaylistDocument]
    }

    private struct TrackDocument: Codable {
        let trackID: UUID
        let title: String
        let artist: String
        let album: String?
        let genre: String?
        let year: Int?
        let duration: TimeInterval
        let format: String?
        let favorite: Bool?
        let playCount: Int?
        let lastPlayedAt: Date?
    }

    func playlistJSON(_ playlist: Playlist, tracks: [Track]) throws -> MusicExportFile {
        try jsonFile(document(for: playlist, tracks: tracks), filename: safe(playlist.name) + ".json")
    }

    func playlistMarkdown(_ playlist: Playlist, tracks: [Track]) -> MusicExportFile {
        var lines = ["# Playlist: \(playlist.name)", "", "- ID: \(playlist.id.uuidString)", "- Kind: \(playlist.kind.rawValue)",
                     "- Tags: \(playlist.tags.joined(separator: ", "))", "- Created: \(iso(playlist.createdAt))",
                     "- Updated: \(iso(playlist.updatedAt))", "", "## Tracks", ""]
        for (index, track) in tracks.enumerated() {
            lines += ["\(index + 1). \(track.title)", "   - Artist: \(track.artistName)",
                      "   - Album: \(track.albumTitle ?? "")", "   - TrackID: \(track.id.uuidString)", ""]
        }
        return textFile(lines.joined(separator: "\n"), filename: safe(playlist.name) + ".md", type: .plainText)
    }

    func allPlaylistsJSON(_ playlists: [Playlist], tracks: [Track]) throws -> MusicExportFile {
        try jsonFile(PlaylistsDocument(version: 1, playlists: playlists.map { document(for: $0, tracks: tracks) }), filename: "MyMusic-Playlists.json")
    }

    func libraryJSON(tracks: [Track], history: [Track.ID: PlaybackHistory]) throws -> MusicExportFile {
        struct Document: Codable { let version: Int; let tracks: [TrackDocument] }
        return try jsonFile(Document(version: 1, tracks: tracks.map { trackDocument($0, history: history[$0.id]) }), filename: "MyMusic-Library.json")
    }

    func libraryMarkdown(tracks: [Track], history: [Track.ID: PlaybackHistory]) -> MusicExportFile {
        var lines = ["# MyMusic Library", ""]
        for track in tracks {
            let entry = history[track.id]
            lines += ["## Track", "", "- TrackID: \(track.id.uuidString)", "- Title: \(track.title)",
                      "- Artist: \(track.artistName)", "- Album: \(track.albumTitle ?? "")", "- Genre: \(track.genre ?? "")",
                      "- Year: \(track.year.map(String.init) ?? "")", "- Duration: \(duration(track.duration))",
                      "- Format: \(track.audioFormat?.codec.rawValue ?? "")", "- Favorite: \(entry?.isFavorite ?? false)",
                      "- PlayCount: \(entry?.playCount ?? 0)", "- LastPlayedAt: \(entry?.lastPlayedAt.map(iso) ?? "")", ""]
        }
        return textFile(lines.joined(separator: "\n"), filename: "MyMusic-Library.md", type: .plainText)
    }

    func playbackHistoryJSON(_ entries: [Track.ID: PlaybackHistory]) throws -> MusicExportFile {
        struct Item: Codable { let trackID: UUID; let favorite: Bool; let playCount: Int; let lastPlayedAt: Date? }
        struct Document: Codable { let version: Int; let history: [Item] }
        let items = entries.values.sorted { $0.trackID.uuidString < $1.trackID.uuidString }
            .map { Item(trackID: $0.trackID, favorite: $0.isFavorite, playCount: $0.playCount, lastPlayedAt: $0.lastPlayedAt) }
        return try jsonFile(Document(version: 1, history: items), filename: "MyMusic-Playback-History.json")
    }

    func trackFeaturesJSON(_ features: [TrackFeature], tracks: [Track], exportedAt: Date = Date()) throws -> MusicExportFile {
        let tracksByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        let items = features.sorted { $0.trackID.uuidString < $1.trackID.uuidString }.map { feature in
            TrackFeatureDocumentItem(
                trackID: feature.trackID,
                title: tracksByID[feature.trackID]?.title ?? feature.sourceIdentity.title,
                artist: tracksByID[feature.trackID]?.artistName ?? feature.sourceIdentity.artist,
                sourceIdentity: feature.sourceIdentity,
                analysisVersion: feature.analysisVersion,
                analyzedAt: feature.analyzedAt,
                importedAt: feature.importedAt,
                features: feature.values
            )
        }
        return try jsonFile(
            TrackFeatureDocument(version: 1, exportedAt: exportedAt, tracks: items),
            filename: "MyMusic-Track-Features.json"
        )
    }

    func volumeNormalizationJSON(
        _ features: [TrackFeature],
        tracks: [Track],
        isEnabled: Bool,
        exportedAt: Date = Date()
    ) throws -> MusicExportFile {
        let tracksByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        let items = features.compactMap { feature -> VolumeNormalizationDocumentItem? in
            guard let integratedLUFS = feature.values.integratedLUFS,
                  let truePeakDBTP = feature.values.truePeakDBTP,
                  let normalizationGainDB = feature.values.normalizationGainDB else { return nil }
            return VolumeNormalizationDocumentItem(
                trackID: feature.trackID,
                title: tracksByID[feature.trackID]?.title ?? feature.sourceIdentity.title,
                artist: tracksByID[feature.trackID]?.artistName ?? feature.sourceIdentity.artist,
                relativePath: feature.sourceIdentity.relativePath,
                integratedLUFS: integratedLUFS,
                truePeakDBTP: truePeakDBTP,
                normalizationGainDB: normalizationGainDB
            )
        }.sorted { $0.trackID.uuidString < $1.trackID.uuidString }
        return try jsonFile(
            VolumeNormalizationDocument(
                version: 1,
                exportedAt: exportedAt,
                isEnabled: isEnabled,
                tracks: items
            ),
            filename: "MyMusic-Volume-Normalization.json"
        )
    }

    func equalizerJSON(
        settings: EqualizerSettings,
        customPresets: [EqualizerPreset]
    ) throws -> MusicExportFile {
        try jsonFile(
            EqualizerTransferDocument(
                kind: .equalizer,
                version: 1,
                equalizer: settings,
                customPresets: customPresets
            ),
            filename: "MyMusic-Equalizer.json"
        )
    }

    func genreDisplayPresetsJSON(_ presets: [GenreDisplayPreset]) throws -> MusicExportFile {
        try jsonFile(
            GenreDisplayPresetTransferDocument(
                kind: .genreDisplayPresets,
                version: 1,
                presets: presets
            ),
            filename: "MyMusic-Genre-Display-Presets.json"
        )
    }

    private func document(for playlist: Playlist, tracks: [Track]) -> PlaylistDocument {
        let byID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        return PlaylistDocument(version: 1, name: playlist.name, playlistID: playlist.id,
            createdAt: playlist.createdAt, updatedAt: playlist.updatedAt, kind: playlist.kind, tags: playlist.tags,
            tracks: playlist.trackIDs.compactMap { byID[$0] }.map { trackDocument($0, history: nil) })
    }

    private func trackDocument(_ track: Track, history: PlaybackHistory?) -> TrackDocument {
        TrackDocument(trackID: track.id, title: track.title, artist: track.artistName, album: track.albumTitle,
            genre: track.genre, year: track.year, duration: track.duration, format: track.audioFormat?.codec.rawValue,
            favorite: history?.isFavorite, playCount: history?.playCount, lastPlayedAt: history?.lastPlayedAt)
    }

    private func jsonFile<T: Encodable>(_ value: T, filename: String) throws -> MusicExportFile {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return MusicExportFile(data: try encoder.encode(value), filename: filename, contentType: .json)
    }

    private func textFile(_ text: String, filename: String, type: UTType) -> MusicExportFile {
        MusicExportFile(data: Data(text.utf8), filename: filename, contentType: type)
    }

    private func iso(_ date: Date) -> String { ISO8601DateFormatter().string(from: date) }
    private func duration(_ seconds: TimeInterval) -> String { String(format: "%d:%02d", Int(seconds) / 60, Int(seconds) % 60) }
    private func safe(_ name: String) -> String {
        let value = name.replacingOccurrences(of: "[^A-Za-z0-9ぁ-んァ-ン一-龯._-]", with: "-", options: .regularExpression)
        return value.isEmpty ? "Playlist" : value
    }
}
