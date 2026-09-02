import Foundation

enum TrackPreferenceImportError: LocalizedError, Equatable {
    case invalidStructure(String)
    case unsupportedSchemaVersion
    case invalidTrackID(String)
    case duplicateTrackID(UUID)
    case outOfRangePreference(UUID)

    var errorDescription: String? {
        switch self {
        case let .invalidStructure(detail):
            "再生傾向JSONの構造が不正です: \(detail)"
        case .unsupportedSchemaVersion:
            "再生傾向JSONはschemaVersion 2のみ読み込めます。"
        case let .invalidTrackID(value):
            "Track IDがUUIDではありません: \(value)"
        case let .duplicateTrackID(id):
            "同じTrack IDが重複しています: \(id.uuidString)"
        case let .outOfRangePreference(id):
            "再生傾向が-10〜+10の範囲外です: \(id.uuidString)"
        }
    }
}

struct TrackPreferenceImportService {
    private struct Document: Decodable {
        let schemaVersion: Int
        let exportedAt: Date
        let tracks: [Item]
    }

    private struct Item: Decodable {
        let trackId: String
        let playbackPreference: Int
        let favorite: Bool
    }

    /// This transfer contract is intentionally strict: unknown root or track fields
    /// are rejected so a newer document cannot silently change unrelated app data.
    func parse(data: Data) throws -> [TrackPreference] {
        try validateKeys(data: data)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let document: Document
        do {
            document = try decoder.decode(Document.self, from: data)
        } catch {
            throw TrackPreferenceImportError.invalidStructure(error.localizedDescription)
        }
        guard document.schemaVersion == 2 else {
            throw TrackPreferenceImportError.unsupportedSchemaVersion
        }

        var ids = Set<UUID>()
        return try document.tracks.map { item in
            guard let id = UUID(uuidString: item.trackId) else {
                throw TrackPreferenceImportError.invalidTrackID(item.trackId)
            }
            guard ids.insert(id).inserted else {
                throw TrackPreferenceImportError.duplicateTrackID(id)
            }
            guard (PlaybackPreferenceWeightPolicy.minimumPreference ...
                   PlaybackPreferenceWeightPolicy.maximumPreference)
                .contains(item.playbackPreference) else {
                throw TrackPreferenceImportError.outOfRangePreference(id)
            }
            return TrackPreference(
                trackID: id,
                playbackPreference: item.playbackPreference,
                favorite: item.favorite
            )
        }
    }

    private func validateKeys(data: Data) throws {
        let object: Any
        do {
            object = try JSONSerialization.jsonObject(with: data)
        } catch {
            throw TrackPreferenceImportError.invalidStructure(error.localizedDescription)
        }
        guard let root = object as? [String: Any] else {
            throw TrackPreferenceImportError.invalidStructure("ルートはobjectである必要があります。")
        }
        let rootKeys: Set<String> = ["schemaVersion", "exportedAt", "tracks"]
        guard Set(root.keys) == rootKeys, let tracks = root["tracks"] as? [Any] else {
            throw TrackPreferenceImportError.invalidStructure("必須fieldまたは未知fieldを確認してください。")
        }
        let itemKeys: Set<String> = ["trackId", "playbackPreference", "favorite"]
        for (index, value) in tracks.enumerated() {
            guard let item = value as? [String: Any], Set(item.keys) == itemKeys else {
                throw TrackPreferenceImportError.invalidStructure(
                    "tracks[\(index)]に必須field不足または未知fieldがあります。"
                )
            }
        }
    }
}
