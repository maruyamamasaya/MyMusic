import Foundation

enum PlaylistKind: String, Codable, Hashable, Sendable {
    case regular
    case work

    func accepts(_ track: Track) -> Bool {
        switch self {
        case .regular:
            !track.isEligibleForWorkPlayback
        case .work:
            track.isEligibleForWorkPlayback
        }
    }
}

struct Playlist: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var trackIDs: [Track.ID]
    let createdAt: Date
    var updatedAt: Date
    var description: String? = nil
    var artworkIdentifier: String? = nil
    var searchDefinition: PlaylistSearchDefinition? = nil
    var kind: PlaylistKind = .regular
    var tags: [String] = []

    init(
        id: UUID,
        name: String,
        trackIDs: [Track.ID],
        createdAt: Date,
        updatedAt: Date,
        description: String? = nil,
        artworkIdentifier: String? = nil,
        searchDefinition: PlaylistSearchDefinition? = nil,
        kind: PlaylistKind = .regular,
        tags: [String] = []
    ) {
        self.id = id
        self.name = name
        self.trackIDs = trackIDs
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.description = description
        self.artworkIdentifier = artworkIdentifier
        self.searchDefinition = searchDefinition
        self.kind = kind
        self.tags = PlaylistTagRules.normalizedTags(tags)
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, trackIDs, createdAt, updatedAt, description, artworkIdentifier, searchDefinition, kind, tags
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        trackIDs = try container.decode([Track.ID].self, forKey: .trackIDs)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        artworkIdentifier = try container.decodeIfPresent(String.self, forKey: .artworkIdentifier)
        searchDefinition = try container.decodeIfPresent(PlaylistSearchDefinition.self, forKey: .searchDefinition)
        kind = try container.decodeIfPresent(PlaylistKind.self, forKey: .kind) ?? .regular
        tags = PlaylistTagRules.normalizedTags(
            try container.decodeIfPresent([String].self, forKey: .tags) ?? []
        )
    }
}
