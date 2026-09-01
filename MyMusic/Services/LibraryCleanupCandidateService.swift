import Foundation

struct LibraryCleanupCandidate: Identifiable, Hashable, Sendable {
    let track: Track
    let earlySkipCount: Int
    let skipCount: Int
    let playCount: Int
    let manualPlayCount: Int
    let lastPlayedAt: Date?
    let playbackPreference: Int

    var id: Track.ID { track.id }
}

struct LibraryCleanupCandidateService: Sendable {
    enum SortOrder: Sendable {
        case earlySkipsThenRecentlyPlayed
    }

    static let minimumEarlySkipCount = 3

    func candidates(
        tracks: [Track],
        historyByTrackID: [Track.ID: PlaybackHistory],
        sortOrder: SortOrder = .earlySkipsThenRecentlyPlayed
    ) -> [LibraryCleanupCandidate] {
        let candidates = tracks.compactMap { track -> LibraryCleanupCandidate? in
            guard let history = historyByTrackID[track.id] else { return nil }
            let earlySkipCount = history.dailySummaries.values.reduce(0) { $0 + $1.earlySkipCount }
            guard earlySkipCount >= Self.minimumEarlySkipCount, history.manualPlayCount > 0 else { return nil }

            return LibraryCleanupCandidate(
                track: track,
                earlySkipCount: earlySkipCount,
                skipCount: history.skipCount,
                playCount: history.playCount,
                manualPlayCount: history.manualPlayCount,
                lastPlayedAt: history.lastPlayedAt,
                playbackPreference: history.playbackPreference
            )
        }

        switch sortOrder {
        case .earlySkipsThenRecentlyPlayed:
            return candidates.sorted {
                if $0.earlySkipCount != $1.earlySkipCount {
                    return $0.earlySkipCount > $1.earlySkipCount
                }
                if $0.lastPlayedAt != $1.lastPlayedAt {
                    return ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast)
                }
                return $0.track.title.localizedStandardCompare($1.track.title) == .orderedAscending
            }
        }
    }
}
