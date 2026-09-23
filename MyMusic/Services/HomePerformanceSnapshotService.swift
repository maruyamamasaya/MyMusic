import Foundation

nonisolated struct HomeDestinationPresentation: Equatable, Sendable {
    let representativeTrack: Track?
    let artworkIdentifier: String?
    let instantPlaybackIsAvailable: Bool
}

nonisolated struct HomePerformanceSnapshot: Sendable {
    let destinationPresentations: [HomeDestination: HomeDestinationPresentation]
    let highlightArtworkIdentifier: String?
    let mixQueues: [MixKind: [Track]]?
    let todayPlaybackSummary: TodayPlaybackSummary?
    let mixDay: Date?
}

nonisolated struct HomePerformanceSnapshotRequest: Sendable {
    let tracks: [Track]
    let albums: [Album]
    let artists: [Artist]
    let workTracks: [Track]
    let hiResTracks: [Track]
    let histories: [Track.ID: PlaybackHistory]
    let preferences: [Track.ID: TrackPreference]
    let listenLaterEntries: [ListenLaterEntry]
    let favorites: LibraryFavorites
    let destinations: Set<HomeDestination>
    let representativeDestinations: Set<HomeDestination>
    let previousPresentations: [HomeDestination: HomeDestinationPresentation]
    let previousHighlightArtworkIdentifier: String?
    let rotatesRepresentatives: Bool
    let includesMixes: Bool
    let includesTodayPlaybackSummary: Bool
    let now: Date
}

actor HomePerformanceSnapshotWorker {
    static let shared = HomePerformanceSnapshotWorker()

    func prepare(_ request: HomePerformanceSnapshotRequest) -> HomePerformanceSnapshot? {
        guard !Task.isCancelled else { return nil }

        let tracksByID = Dictionary(
            request.tracks.map { ($0.id, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        let eligibleTracks = request.tracks.filter {
            $0.isEligibleForRegularRandomPlayback
                && !Self.isHidden($0.id, histories: request.histories, now: request.now)
        }
        guard !Task.isCancelled else { return nil }

        let favoriteAlbumTracks = Self.favoriteAlbumTracks(
            albums: request.albums,
            favoriteIDs: request.favorites.albumIDs,
            tracksByID: tracksByID
        )
        let favoriteArtistTracks = Self.favoriteArtistTracks(
            artists: request.artists,
            favoriteIDs: request.favorites.artistIDs,
            tracksByID: tracksByID
        )
        let sourceTracks: [HomeDestination: [Track]] = [
            .quickPlay: eligibleTracks,
            .selectiveRandomPlay: eligibleTracks,
            .discoveryPlay: eligibleTracks.filter { (request.histories[$0.id]?.playCount ?? 0) == 0 },
            .listenLater: request.listenLaterEntries.compactMap { tracksByID[$0.trackID] },
            .recentlyAddedPlay: eligibleTracks.filter {
                guard let date = $0.firstSeenAt else { return false }
                return date >= request.now.addingTimeInterval(-PlaybackHistoryStore.recentlyAddedInterval)
                    && date <= request.now
            },
            .repeatPlay: eligibleTracks.filter { (request.histories[$0.id]?.playCount ?? 0) >= 2 },
            .favorites: eligibleTracks.filter {
                request.preferences[$0.id]?.favorite == true
            },
            .favoriteAlbums: favoriteAlbumTracks,
            .favoriteArtists: favoriteArtistTracks,
            .recentTracks: request.tracks.filter {
                $0.isEligibleForRegularPlayback && request.histories[$0.id]?.lastPlayedAt != nil
            },
            .workSizePlay: request.workTracks,
            .hiResLibrary: request.hiResTracks
        ]

        var presentations: [HomeDestination: HomeDestinationPresentation] = [:]
        for destination in request.destinations {
            guard !Task.isCancelled else { return nil }
            let source = sourceTracks[destination] ?? []
            let artworkTracks = HomeRepresentativeTrackPolicy.eligibleArtworkTracks(from: source)
            let previous = request.previousPresentations[destination]?.representativeTrack
            let representative: Track?
            if !request.representativeDestinations.contains(destination) {
                representative = nil
            } else if !request.rotatesRepresentatives,
                      let previous,
                      artworkTracks.contains(where: { $0.id == previous.id }) {
                representative = previous
            } else {
                representative = HomeRepresentativeTrackPolicy.select(
                    from: artworkTracks,
                    excluding: previous?.id
                )
            }
            let artworkIdentifiers = source.compactMap(\.artworkIdentifier)
            let previousArtwork = request.previousPresentations[destination]?.artworkIdentifier
            let artwork = representative?.artworkIdentifier
                ?? previousArtwork.flatMap { artworkIdentifiers.contains($0) ? $0 : nil }
                ?? artworkIdentifiers.randomElement()
            presentations[destination] = HomeDestinationPresentation(
                representativeTrack: representative,
                artworkIdentifier: artwork,
                instantPlaybackIsAvailable: !source.isEmpty
            )
        }

        let highlightCandidates = Array(Set(eligibleTracks.compactMap(\.artworkIdentifier)))
        let highlightArtworkIdentifier = Self.selectedHighlightArtwork(
            from: highlightCandidates,
            previous: request.previousHighlightArtworkIdentifier,
            rotating: request.rotatesRepresentatives
        )

        var mixQueues: [MixKind: [Track]]?
        var mixDay: Date?
        if request.includesMixes {
            let scores = PlaybackBehaviorAnalyzer().overplayScores(
                for: eligibleTracks.map(\.id),
                historyByTrackID: request.histories,
                now: request.now
            )
            guard !Task.isCancelled else { return nil }
            let weights = Dictionary(eligibleTracks.map { track in
                (track.id, PlaybackSelectionPolicy.shuffleWeight(
                    playbackPreference: request.preferences[track.id]?.playbackPreference ?? 0,
                    overplayScore: scores[track.id] ?? 0
                ))
            }, uniquingKeysWith: { first, _ in first })
            mixQueues = MixSelectionService().allQueues(
                from: eligibleTracks,
                histories: request.histories,
                preferences: request.preferences,
                weights: weights,
                now: request.now
            )
            mixDay = Calendar.current.startOfDay(for: request.now)
        }

        let today = request.includesTodayPlaybackSummary
            ? TodayPlaybackSummaryService().summary(from: request.histories, now: request.now)
            : nil
        guard !Task.isCancelled else { return nil }
        return HomePerformanceSnapshot(
            destinationPresentations: presentations,
            highlightArtworkIdentifier: highlightArtworkIdentifier,
            mixQueues: mixQueues,
            todayPlaybackSummary: today,
            mixDay: mixDay
        )
    }

    private static func isHidden(
        _ trackID: Track.ID,
        histories: [Track.ID: PlaybackHistory],
        now: Date
    ) -> Bool {
        guard let history = histories[trackID] else { return false }
        return history.isPermanentlyHiddenFromShuffle
            || (history.boredomHiddenUntil.map { $0 > now } ?? false)
    }

    private static func favoriteAlbumTracks(
        albums: [Album],
        favoriteIDs: Set<Album.ID>,
        tracksByID: [Track.ID: Track]
    ) -> [Track] {
        var seen: Set<Track.ID> = []
        return albums.filter {
            !favoriteIDs.isDisjoint(with: ($0.legacyAlbumIDs ?? []).union([$0.id]))
        }.flatMap(\.trackIDs).compactMap {
            guard seen.insert($0).inserted,
                  let track = tracksByID[$0], track.isEligibleForRegularPlayback else { return nil }
            return track
        }
    }

    private static func favoriteArtistTracks(
        artists: [Artist],
        favoriteIDs: Set<Artist.ID>,
        tracksByID: [Track.ID: Track]
    ) -> [Track] {
        var seen: Set<Track.ID> = []
        return artists.filter { favoriteIDs.contains($0.id) }.flatMap(\.trackIDs).compactMap {
            guard seen.insert($0).inserted,
                  let track = tracksByID[$0], track.isEligibleForRegularPlayback else { return nil }
            return track
        }
    }

    private static func selectedHighlightArtwork(
        from candidates: [String],
        previous: String?,
        rotating: Bool
    ) -> String? {
        guard !candidates.isEmpty else { return nil }
        if !rotating, let previous, candidates.contains(previous) { return previous }
        let alternatives = candidates.filter { $0 != previous }
        return (alternatives.isEmpty ? candidates : alternatives).randomElement()
    }
}
