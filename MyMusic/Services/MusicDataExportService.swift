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
    private struct PlaylistDocument: Codable {
        let version: Int
        let name: String
        let playlistID: UUID
        let createdAt: Date
        let updatedAt: Date
        let kind: PlaylistKind
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
                     "- Created: \(iso(playlist.createdAt))", "- Updated: \(iso(playlist.updatedAt))", "", "## Tracks", ""]
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

    private func document(for playlist: Playlist, tracks: [Track]) -> PlaylistDocument {
        let byID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        return PlaylistDocument(version: 1, name: playlist.name, playlistID: playlist.id,
            createdAt: playlist.createdAt, updatedAt: playlist.updatedAt, kind: playlist.kind,
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
