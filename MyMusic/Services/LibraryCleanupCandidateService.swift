import Foundation

struct LibraryCleanupCandidate: Identifiable, Hashable, Sendable {
    let track: Track
    let evaluatedEventCount: Int
    let userSkipCount: Int
    let userSkipRate: Double
    let averagePlaybackRatio: Double
    let lastPlayedAt: Date?
    let playbackPreference: Int

    var id: Track.ID { track.id }
}

struct LibraryCleanupCandidateService: Sendable {
    enum SortOrder: Sendable {
        case behaviorThenRecentlyPlayed
    }

    static let maximumEvaluatedEventCount = 20
    static let minimumEvaluatedEventCount = 5
    static let minimumUserSkipRate = 0.50
    static let maximumAveragePlaybackRatio = 0.10

    func candidates(
        tracks: [Track],
        historyByTrackID: [Track.ID: PlaybackHistory],
        preferencesByTrackID: [Track.ID: TrackPreference] = [:],
        sortOrder: SortOrder = .behaviorThenRecentlyPlayed
    ) -> [LibraryCleanupCandidate] {
        let candidates = tracks.compactMap { track -> LibraryCleanupCandidate? in
            guard track.isEligibleForRegularPlayback,
                  let history = historyByTrackID[track.id] else { return nil }
            let events = history.playbackEvents
                .filter { $0.endKind != nil }
                .sorted { $0.endedAt > $1.endedAt }
                .prefix(Self.maximumEvaluatedEventCount)
            guard events.count >= Self.minimumEvaluatedEventCount else { return nil }

            let userSkipCount = events.count { $0.endKind == .userSkipped }
            let userSkipRate = Double(userSkipCount) / Double(events.count)
            let averagePlaybackRatio = events.reduce(0.0) { $0 + min(max($1.completionRatio, 0), 1) }
                / Double(events.count)
            guard userSkipRate >= Self.minimumUserSkipRate,
                  averagePlaybackRatio <= Self.maximumAveragePlaybackRatio else { return nil }

            return LibraryCleanupCandidate(
                track: track,
                evaluatedEventCount: events.count,
                userSkipCount: userSkipCount,
                userSkipRate: userSkipRate,
                averagePlaybackRatio: averagePlaybackRatio,
                lastPlayedAt: history.lastPlayedAt,
                playbackPreference: preferencesByTrackID[track.id]?.playbackPreference ?? 0
            )
        }

        switch sortOrder {
        case .behaviorThenRecentlyPlayed:
            return candidates.sorted {
                if $0.userSkipRate != $1.userSkipRate {
                    return $0.userSkipRate > $1.userSkipRate
                }
                if $0.averagePlaybackRatio != $1.averagePlaybackRatio {
                    return $0.averagePlaybackRatio < $1.averagePlaybackRatio
                }
                if $0.lastPlayedAt != $1.lastPlayedAt {
                    return ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast)
                }
                return $0.track.title.localizedStandardCompare($1.track.title) == .orderedAscending
            }
        }
    }
}
