import Foundation

struct PlaylistImportDraft: Sendable {
    let name: String
    let trackIDs: [Track.ID]
    let kind: PlaylistKind
}

struct PlaylistImportResult: Sendable {
    let playlists: [PlaylistImportDraft]
    let importedTrackCount: Int
    let missingTrackCount: Int
    let incompatibleTrackCount: Int
}

enum MusicDataImportError: LocalizedError {
    case unsupportedFormat, invalidData, missingName, noTrackIDs
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: "対応していないファイル形式です。"
        case .invalidData: "プレイリストデータを解析できませんでした。"
        case .missingName: "プレイリスト名がありません。"
        case .noTrackIDs: "有効なTrack IDがありません。"
        }
    }
}

struct MusicDataImportService: Sendable {
    func parse(data: Data, fileExtension: String, libraryTracks: [Track]) throws -> PlaylistImportResult {
        let drafts: [PlaylistImportDraft]
        switch fileExtension.lowercased() {
        case "json": drafts = try parseJSON(data)
        case "md", "markdown": drafts = try parseMarkdown(data)
        default: throw MusicDataImportError.unsupportedFormat
        }
        let tracksByID = Dictionary(uniqueKeysWithValues: libraryTracks.map { ($0.id, $0) })
        var imported = 0, missing = 0, incompatible = 0
        let resolved = drafts.map { draft in
            var seen: Set<Track.ID> = []
            let unique = draft.trackIDs.filter { seen.insert($0).inserted }
            let found = unique.compactMap { tracksByID[$0] }
            let accepted = found.filter(draft.kind.accepts)
            imported += accepted.count
            missing += unique.count - found.count
            incompatible += found.count - accepted.count
            return PlaylistImportDraft(name: draft.name, trackIDs: accepted.map(\.id), kind: draft.kind)
        }
        return PlaylistImportResult(
            playlists: resolved,
            importedTrackCount: imported,
            missingTrackCount: missing,
            incompatibleTrackCount: incompatible
        )
    }

    private func parseJSON(_ data: Data) throws -> [PlaylistImportDraft] {
        let object = try JSONSerialization.jsonObject(with: data)
        guard let root = object as? [String: Any], (root["version"] as? Int) == 1 else { throw MusicDataImportError.invalidData }
        if let playlists = root["playlists"] as? [[String: Any]] { return try playlists.map(parseJSONObject) }
        return [try parseJSONObject(root)]
    }

    private func parseJSONObject(_ object: [String: Any]) throws -> PlaylistImportDraft {
        guard let name = (object["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else { throw MusicDataImportError.missingName }
        guard let tracks = object["tracks"] as? [[String: Any]] else { throw MusicDataImportError.noTrackIDs }
        let ids = tracks.compactMap { ($0["trackID"] as? String).flatMap(UUID.init(uuidString:)) }
        guard !ids.isEmpty || tracks.isEmpty else { throw MusicDataImportError.noTrackIDs }
        let kind = (object["kind"] as? String).flatMap(PlaylistKind.init(rawValue:)) ?? .regular
        return PlaylistImportDraft(name: name, trackIDs: ids, kind: kind)
    }

    private func parseMarkdown(_ data: Data) throws -> [PlaylistImportDraft] {
        guard let text = String(data: data, encoding: .utf8) else { throw MusicDataImportError.invalidData }
        guard let heading = text.split(separator: "\n").first(where: { $0.hasPrefix("# Playlist:") }) else { throw MusicDataImportError.missingName }
        let name = heading.dropFirst("# Playlist:".count).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw MusicDataImportError.missingName }
        let ids = text.split(separator: "\n").compactMap { line -> UUID? in
            guard let range = line.range(of: "TrackID:") else { return nil }
            return UUID(uuidString: line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines))
        }
        guard !ids.isEmpty else { throw MusicDataImportError.noTrackIDs }
        let kind = text.split(separator: "\n").compactMap { line -> PlaylistKind? in
            guard let range = line.range(of: "Kind:") else { return nil }
            let value = line[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            return PlaylistKind(rawValue: value)
        }.first ?? .regular
        return [PlaylistImportDraft(name: name, trackIDs: ids, kind: kind)]
    }
}
