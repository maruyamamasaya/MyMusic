import Foundation

enum SearchMatchMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case and
    case or

    var id: Self { self }
    var title: String { rawValue.uppercased() }
}

enum TrackKeywordField: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case title
    case album
    case artist

    var id: Self { self }

    var title: String {
        switch self {
        case .title: "曲名"
        case .album: "アルバム名"
        case .artist: "アーティスト名"
        }
    }

    var systemImage: String {
        switch self {
        case .title: "music.note"
        case .album: "square.stack"
        case .artist: "music.mic"
        }
    }
}

enum TrackSearchConditionKind: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case genre
    case artist
    case album
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
        case .artist: "アーティスト"
        case .album: "アルバム"
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

    var needsGenreValue: Bool { self == .genre }
    var needsStringValue: Bool { self == .artist || self == .album }
}

enum TrackTextMatchMode: String, CaseIterable, Identifiable, Codable, Hashable, Sendable {
    case contains
    case exact
    case notContains

    var id: Self { self }

    var title: String {
        switch self {
        case .contains: "部分一致"
        case .exact: "完全一致"
        case .notContains: "含まない"
        }
    }
}

struct TrackSearchCondition: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var kind: TrackSearchConditionKind
    var value: Int
    var textValue: String?
    // Optional so search definitions saved before this setting was added remain decodable.
    var textMatchMode: TrackTextMatchMode?

    init(
        id: UUID = UUID(),
        kind: TrackSearchConditionKind = .favorite,
        value: Int = 0,
        textValue: String? = nil,
        textMatchMode: TrackTextMatchMode? = .contains
    ) {
        self.id = id
        self.kind = kind
        self.value = value
        self.textValue = textValue
        self.textMatchMode = textMatchMode
    }
}

struct TrackSearchFilter: Codable, Hashable, Sendable {
    var keywordMatchMode: SearchMatchMode = .and
    // Optional so playlists saved before keyword fields were added remain decodable.
    var keywordField: TrackKeywordField? = .title
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
            matchesText(
                track,
                terms: terms,
                mode: filter.keywordMatchMode,
                field: filter.keywordField ?? .title
            )
                && matchesConditions(track, history: historyEntries[track.id], filter: filter)
        }
    }

    private func matchesText(
        _ track: Track,
        terms: [String],
        mode: SearchMatchMode,
        field: TrackKeywordField
    ) -> Bool {
        guard !terms.isEmpty else { return true }
        let value = switch field {
        case .title: track.title
        case .album: track.albumTitle ?? ""
        case .artist: track.artistName
        }
        let matches = terms.map { value.localizedStandardContains($0) }
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
            case .artist:
                matchesString(track.artistName, condition: condition)
            case .album:
                matchesString(track.albumTitle ?? "", condition: condition)
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

    private func matchesString(_ candidate: String, condition: TrackSearchCondition) -> Bool {
        let value = condition.textValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !value.isEmpty else { return false }

        return switch condition.textMatchMode ?? .contains {
        case .contains:
            candidate.localizedStandardContains(value)
        case .exact:
            candidate.localizedStandardCompare(value) == .orderedSame
        case .notContains:
            !candidate.localizedStandardContains(value)
        }
    }

    private func combined(_ values: [Bool], mode: SearchMatchMode) -> Bool {
        mode == .and ? values.allSatisfy { $0 } : values.contains(true)
    }
}
