import Foundation

struct Track: Identifiable, Codable, Hashable, Sendable {
    nonisolated static let longFormMinimumDuration: TimeInterval = 20 * 60
    nonisolated static let workPlaybackGenre = "作業用BGM"

    let id: UUID
    var title: String
    var artistName: String
    var albumArtistName: String? = nil
    var albumTitle: String? = nil
    var duration: TimeInterval
    var fileURL: URL
    var relativePath: String? = nil
    var fileSize: Int64? = nil
    var modificationDate: Date? = nil
    /// The absolute time MyMusic first observed this logical track during a library scan.
    /// `nil` is a supported legacy state meaning that the time is unknown.
    var firstSeenAt: Date? = nil
    var artworkIdentifier: String? = nil
    var trackNumber: Int? = nil
    var discNumber: Int? = nil
    var year: Int? = nil
    var genre: String? = nil
    var composer: String? = nil
    var audioFormat: AudioFormat? = nil
    // Missing in legacy caches; used to run one-time metadata migrations on rescan.
    var metadataRevision: Int? = nil

    nonisolated var isLongForm: Bool {
        duration >= Self.longFormMinimumDuration
    }

    nonisolated var isEligibleForWorkPlayback: Bool {
        isLongForm || normalizedGenreNames.contains(Self.workPlaybackGenre)
    }

    nonisolated var isEligibleForRegularPlayback: Bool {
        !isEligibleForWorkPlayback
    }

    nonisolated var normalizedGenreNames: Set<String> {
        guard let genre else { return [] }
        return Set(
            genre
                .split(whereSeparator: { $0 == ";" || $0 == "\0" })
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }
}
