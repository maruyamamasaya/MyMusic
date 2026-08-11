import Foundation

struct AnalyticsSnapshot {
    struct TrackItem: Identifiable {
        let track: Track
        let playCount: Int
        let lastPlayedAt: Date?

        var id: Track.ID { track.id }
    }

    struct PlaylistItem: Identifiable {
        let id: Playlist.ID
        let name: String
        let trackCount: Int
    }

    let totalPlayCount: Int
    let playedTrackCount: Int
    let favoriteCount: Int
    let mostPlayedTrack: TrackItem?
    let playbackHistory: [TrackItem]
    let mostPlayedTracks: [TrackItem]
    let trackPlayCounts: [TrackItem]
    let recentTracks: [TrackItem]
    let favoriteTracks: [TrackItem]
    let playlists: [PlaylistItem]

    var playlistCount: Int { playlists.count }
}

@MainActor
final class AnalyticsService {
    func makeSnapshot(
        tracks: [Track],
        historyEntries: [Track.ID: PlaybackHistory],
        playlists: [Playlist]
    ) -> AnalyticsSnapshot {
        let trackItems = tracks.map { track in
            let history = historyEntries[track.id]
            return AnalyticsSnapshot.TrackItem(
                track: track,
                playCount: history?.playCount ?? 0,
                lastPlayedAt: history?.lastPlayedAt
            )
        }

        let playbackHistory = trackItems
            .filter { $0.lastPlayedAt != nil }
            .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }

        let trackPlayCounts = trackItems
            .filter { $0.playCount > 0 }
            .sorted(by: playCountSort)

        let favoriteTracks = trackItems
            .filter { historyEntries[$0.id]?.isFavorite == true }
            .sorted { $0.track.title.localizedStandardCompare($1.track.title) == .orderedAscending }

        return AnalyticsSnapshot(
            totalPlayCount: historyEntries.values.reduce(0) { $0 + $1.playCount },
            playedTrackCount: historyEntries.values.filter { $0.lastPlayedAt != nil }.count,
            favoriteCount: historyEntries.values.filter(\.isFavorite).count,
            mostPlayedTrack: trackPlayCounts.first,
            playbackHistory: playbackHistory,
            mostPlayedTracks: Array(trackPlayCounts.prefix(10)),
            trackPlayCounts: trackPlayCounts,
            recentTracks: Array(playbackHistory.prefix(10)),
            favoriteTracks: favoriteTracks,
            playlists: playlists.map {
                AnalyticsSnapshot.PlaylistItem(
                    id: $0.id,
                    name: $0.name,
                    trackCount: $0.trackIDs.count
                )
            }
        )
    }

    private func playCountSort(
        _ lhs: AnalyticsSnapshot.TrackItem,
        _ rhs: AnalyticsSnapshot.TrackItem
    ) -> Bool {
        if lhs.playCount != rhs.playCount { return lhs.playCount > rhs.playCount }
        return lhs.track.title.localizedStandardCompare(rhs.track.title) == .orderedAscending
    }
}
