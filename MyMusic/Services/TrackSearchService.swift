import Foundation

enum SearchMatchMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case and
    case or

    var id: Self { self }
    var title: String { rawValue.uppercased() }
}

enum TrackSearchConditionKind: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case genre
    case favorite
    case notFavorite
    case liked
    case disliked
    case unrated
    case minimumPlayCount
    case maximumPlayCount

    var id: Self { self }

    var title: String {
        switch self {
        case .genre: "ジャンル"
        case .favorite: "お気に入り"
        case .notFavorite: "お気に入り以外"
        case .liked: "いいね"
        case .disliked: "よくないね"
        case .unrated: "未評価"
        case .minimumPlayCount: "再生回数が指定以上"
        case .maximumPlayCount: "再生回数が指定以下"
        }
    }

    var needsValue: Bool {
        self == .minimumPlayCount || self == .maximumPlayCount
    }

    var needsTextValue: Bool { self == .genre }
}

struct TrackSearchCondition: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: TrackSearchConditionKind
    var value: Int
    var textValue: String?

    init(
        id: UUID = UUID(),
        kind: TrackSearchConditionKind = .favorite,
        value: Int = 0,
        textValue: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.value = value
        self.textValue = textValue
    }
}

struct TrackSearchFilter: Codable, Hashable, Sendable {
    var keywordMatchMode: SearchMatchMode = .and
    var conditionMatchMode: SearchMatchMode = .and
    var conditions: [TrackSearchCondition] = []

    var hasConditions: Bool { !conditions.isEmpty }
    var activeConditionCount: Int { conditions.count }
}

struct PlaylistSearchDefinition: Codable, Hashable, Sendable {
    var query: String
    var filter: TrackSearchFilter
}

struct TrackSearchService {
    func search(
        tracks: [Track],
        query: String,
        filter: TrackSearchFilter,
        historyEntries: [Track.ID: PlaybackHistory]
    ) -> [Track] {
        let terms = query.split(whereSeparator: { $0.isWhitespace }).map(String.init)

        return tracks.filter { track in
            matchesText(track, terms: terms, mode: filter.keywordMatchMode)
                && matchesConditions(track, history: historyEntries[track.id], filter: filter)
        }
    }

    private func matchesText(_ track: Track, terms: [String], mode: SearchMatchMode) -> Bool {
        guard !terms.isEmpty else { return true }
        let values = [track.title, track.artistName, track.albumTitle, track.genre, track.composer]
            .compactMap { $0 }
        let matches = terms.map { term in values.contains { $0.localizedStandardContains(term) } }
        return combined(matches, mode: mode)
    }

    private func matchesConditions(
        _ track: Track,
        history: PlaybackHistory?,
        filter: TrackSearchFilter
    ) -> Bool {
        guard !filter.conditions.isEmpty else { return true }
        let isFavorite = history?.isFavorite ?? false
        let playCount = history?.playCount ?? 0
        let preference = history?.playbackPreference ?? 0

        let matches = filter.conditions.map { condition in
            switch condition.kind {
            case .genre:
                condition.textValue.map {
                    !$0.isEmpty && track.genre?.localizedStandardCompare($0) == .orderedSame
                } ?? false
            case .favorite: isFavorite
            case .notFavorite: !isFavorite
            case .liked: preference > 0
            case .disliked: preference < 0
            case .unrated: preference == 0
            case .minimumPlayCount: playCount >= condition.value
            case .maximumPlayCount: playCount <= condition.value
            }
        }
        return combined(matches, mode: filter.conditionMatchMode)
    }

    private func combined(_ values: [Bool], mode: SearchMatchMode) -> Bool {
        mode == .and ? values.allSatisfy { $0 } : values.contains(true)
    }
}
