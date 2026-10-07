import Foundation

struct PlaylistImportDraft: Sendable {
    let id: UUID?
    let createdAt: Date?
    let updatedAt: Date?
    let tagsWereProvided: Bool
    let name: String
    let trackIDs: [Track.ID]
    let kind: PlaylistKind
    let tags: [String]
}

struct PlaylistImportResult: Sendable {
    let playlists: [PlaylistImportDraft]
    let importedTrackCount: Int
    let missingTrackCount: Int
    let incompatibleTrackCount: Int
}

enum MusicDataImportError: LocalizedError {
    case unsupportedFormat, invalidData, missingName, noTrackIDs
    case unresolvedTracks, conflictingPlaylist, importInProgress
    var errorDescription: String? {
        switch self {
        case .unsupportedFormat: "対応していないファイル形式です。"
        case .invalidData: "プレイリストデータを解析できませんでした。"
        case .missingName: "プレイリスト名がありません。"
        case .noTrackIDs: "有効なTrack IDがありません。"
        case .unresolvedTracks: "照合できない曲、または種別が異なる曲があります。情報の欠落を防ぐため操作を停止しました。ライブラリとプレイリストの種別を確認してください。"
        case .conflictingPlaylist: "同じIDのプレイリストに変更があります。内容の更新を確認してから読み込んでください。"
        case .importInProgress: "プレイリストの保存中です。完了後に再試行してください。"
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
            return PlaylistImportDraft(
                id: draft.id, createdAt: draft.createdAt, updatedAt: draft.updatedAt,
                tagsWereProvided: draft.tagsWereProvided, name: draft.name,
                trackIDs: accepted.map(\.id),
                kind: draft.kind,
                tags: PlaylistTagRules.normalizedTags(draft.tags)
            )
        }
        guard missing == 0, incompatible == 0 else { throw MusicDataImportError.unresolvedTracks }
        let ids = resolved.compactMap(\.id)
        guard Set(ids).count == ids.count else { throw MusicDataImportError.invalidData }
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
        let ids = try tracks.map { track -> UUID in
            guard let text = track["trackID"] as? String, let id = UUID(uuidString: text) else { throw MusicDataImportError.invalidData }
            return id
        }
        guard Set(ids).count == ids.count else { throw MusicDataImportError.invalidData }
        guard !ids.isEmpty || tracks.isEmpty else { throw MusicDataImportError.noTrackIDs }
        let kind: PlaylistKind
        if let raw = object["kind"] {
            guard let text = raw as? String, let parsed = PlaylistKind(rawValue: text) else { throw MusicDataImportError.invalidData }
            kind = parsed
        } else { kind = .regular }
        let tags: [String]
        if let raw = object["tags"] {
            guard let values = raw as? [String], PlaylistTagRules.normalizedTags(values) == values else { throw MusicDataImportError.invalidData }
            tags = values
        } else { tags = [] }
        let id: UUID?
        if let raw = object["playlistID"] {
            guard let text = raw as? String, let parsed = UUID(uuidString: text) else { throw MusicDataImportError.invalidData }
            id = parsed
        } else { id = nil }
        return PlaylistImportDraft(id: id, createdAt: try date(object["createdAt"]), updatedAt: try date(object["updatedAt"]),
            tagsWereProvided: object["tags"] != nil, name: name, trackIDs: ids, kind: kind, tags: tags)
    }

    private func date(_ raw: Any?) throws -> Date? {
        guard let raw else { return nil }
        guard let text = raw as? String else { throw MusicDataImportError.invalidData }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: text) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: text) else { throw MusicDataImportError.invalidData }
        return date
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
        let tags = text.split(separator: "\n").compactMap { line -> [String]? in
            guard let range = line.range(of: "Tags:") else { return nil }
            return line[range.upperBound...]
                .split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        }.first ?? []
        func field(_ key: String) -> String? {
            text.split(separator: "\n").first { $0.hasPrefix("- \(key): ") }
                .map { String($0.dropFirst(key.count + 4)) }
        }
        let id: UUID?
        if let raw = field("ID") {
            guard let parsed = UUID(uuidString: raw) else { throw MusicDataImportError.invalidData }
            id = parsed
        } else { id = nil }
        return [PlaylistImportDraft(id: id, createdAt: try date(field("Created")), updatedAt: try date(field("Updated")),
            tagsWereProvided: field("Tags") != nil, name: name, trackIDs: ids, kind: kind, tags: tags)]
    }
}
