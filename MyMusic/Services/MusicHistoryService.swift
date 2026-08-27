import Foundation

struct MusicHistorySnapshot {
    struct TrackRanking: Identifiable {
        let track: Track
        let playCount: Int

        var id: Track.ID { track.id }
    }

    struct ArtistRanking: Identifiable {
        let name: String
        let playCount: Int

        var id: String { name }
    }

    struct Month: Identifiable {
        let date: Date
        let playCount: Int
        let trackCount: Int
        let artistCount: Int
        let topTracks: [TrackRanking]
        let topArtists: [ArtistRanking]

        var id: Date { date }
        var mostPlayedTrack: TrackRanking? { topTracks.first }
    }

    struct Year: Identifiable {
        let year: Int
        let months: [Month]

        var id: Int { year }
    }

    let years: [Year]
}

@MainActor
final class MusicHistoryService {
    private let rankingLimit = 10

    /// Builds a read-only history from the month groups already resolved by AnalyticsService.
    func makeSnapshot(playbackMonths: [AnalyticsSnapshot.MonthGroup]) -> MusicHistorySnapshot {
        let calendar = Calendar.current
        let months = playbackMonths.map(makeMonth)
        let years = Dictionary(grouping: months) {
            calendar.component(.year, from: $0.date)
        }
        .map { year, months in
            MusicHistorySnapshot.Year(
                year: year,
                months: months.sorted { $0.date > $1.date }
            )
        }
        .sorted { $0.year > $1.year }

        return MusicHistorySnapshot(years: years)
    }

    private func makeMonth(_ month: AnalyticsSnapshot.MonthGroup) -> MusicHistorySnapshot.Month {
        let events = month.days.flatMap(\.events)
        let tracks = Dictionary(grouping: events, by: { $0.track.id })
        let artists = Dictionary(grouping: events, by: { $0.track.artistName })

        let topTracks = tracks.values
            .compactMap { events -> MusicHistorySnapshot.TrackRanking? in
                guard let track = events.first?.track else { return nil }
                return MusicHistorySnapshot.TrackRanking(track: track, playCount: events.count)
            }
            .sorted(by: trackRankingSort)

        let topArtists = artists.map { name, events in
            MusicHistorySnapshot.ArtistRanking(name: name, playCount: events.count)
        }
        .sorted(by: artistRankingSort)

        return MusicHistorySnapshot.Month(
            date: month.date,
            playCount: events.count,
            trackCount: tracks.count,
            artistCount: artists.count,
            topTracks: Array(topTracks.prefix(rankingLimit)),
            topArtists: Array(topArtists.prefix(rankingLimit))
        )
    }

    private func trackRankingSort(
        _ lhs: MusicHistorySnapshot.TrackRanking,
        _ rhs: MusicHistorySnapshot.TrackRanking
    ) -> Bool {
        if lhs.playCount != rhs.playCount { return lhs.playCount > rhs.playCount }
        let titleComparison = lhs.track.title.localizedStandardCompare(rhs.track.title)
        if titleComparison != .orderedSame { return titleComparison == .orderedAscending }
        return lhs.track.artistName.localizedStandardCompare(rhs.track.artistName) == .orderedAscending
    }

    private func artistRankingSort(
        _ lhs: MusicHistorySnapshot.ArtistRanking,
        _ rhs: MusicHistorySnapshot.ArtistRanking
    ) -> Bool {
        if lhs.playCount != rhs.playCount { return lhs.playCount > rhs.playCount }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }
}
