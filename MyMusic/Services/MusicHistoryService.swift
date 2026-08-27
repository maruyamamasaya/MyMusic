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
        let representativeTrack: Track

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
        let playCount: Int
        let trackCount: Int
        let artistCount: Int
        let months: [Month]
        let topTracks: [TrackRanking]
        let topArtists: [ArtistRanking]

        var id: Int { year }
        var mostPlayedTrack: TrackRanking? { topTracks.first }
        var monthCount: Int { months.count }
    }

    let years: [Year]
    let changesAndDiscovery: MusicHistoryDiscoverySnapshot?
    let memories: MusicHistoryMemorySnapshot

    var availableYears: [Int] { years.map(\.year) }

    static let empty = MusicHistorySnapshot(
        years: [],
        changesAndDiscovery: nil,
        memories: .empty
    )
}

@MainActor
final class MusicHistoryService {
    private let trackRankingLimit = 10
    private let artistRankingLimit = 10

    /// Builds a read-only history from the month groups already resolved by AnalyticsService.
    func makeSnapshot(
        playbackMonths: [AnalyticsSnapshot.MonthGroup],
        now: Date = Date()
    ) -> MusicHistorySnapshot {
        let calendar = Calendar.current
        let allEvents = playbackMonths.flatMap { $0.days.flatMap(\.events) }
        let months = playbackMonths.map(makeMonth)
        let monthsByDate = Dictionary(uniqueKeysWithValues: months.map { ($0.date, $0) })
        let years = Dictionary(grouping: playbackMonths) {
            calendar.component(.year, from: $0.date)
        }
        .map { year, playbackMonths in
            let events = playbackMonths.flatMap { $0.days.flatMap(\.events) }
            let topTracks = makeTrackRankings(from: events, limit: trackRankingLimit)
            let topArtists = makeArtistRankings(from: events, limit: artistRankingLimit)
            return MusicHistorySnapshot.Year(
                year: year,
                playCount: events.count,
                trackCount: Set(events.map { $0.track.id }).count,
                artistCount: Set(events.map { $0.track.artistName }).count,
                months: playbackMonths
                    .compactMap { monthsByDate[$0.date] }
                    .sorted { $0.date < $1.date },
                topTracks: topTracks,
                topArtists: topArtists
            )
        }
        .sorted { $0.year > $1.year }

        return MusicHistorySnapshot(
            years: years,
            changesAndDiscovery: MusicHistoryDiscoveryService().makeSnapshot(
                events: allEvents,
                now: now,
                calendar: calendar
            ),
            memories: MusicHistoryMemoryService().makeSnapshot(
                playbackMonths: playbackMonths,
                events: allEvents,
                now: now,
                calendar: calendar
            )
        )
    }

    private func makeMonth(_ month: AnalyticsSnapshot.MonthGroup) -> MusicHistorySnapshot.Month {
        let events = month.days.flatMap(\.events)
        let topTracks = makeTrackRankings(from: events, limit: trackRankingLimit)
        let topArtists = makeArtistRankings(from: events, limit: artistRankingLimit)

        return MusicHistorySnapshot.Month(
            date: month.date,
            playCount: events.count,
            trackCount: Set(events.map { $0.track.id }).count,
            artistCount: Set(events.map { $0.track.artistName }).count,
            topTracks: topTracks,
            topArtists: topArtists
        )
    }

    private func makeTrackRankings(
        from events: [AnalyticsSnapshot.PlaybackEvent],
        limit: Int
    ) -> [MusicHistorySnapshot.TrackRanking] {
        Dictionary(grouping: events, by: { $0.track.id }).values
            .compactMap { events -> MusicHistorySnapshot.TrackRanking? in
                guard let track = events.first?.track else { return nil }
                return MusicHistorySnapshot.TrackRanking(track: track, playCount: events.count)
            }
            .sorted(by: trackRankingSort)
            .prefix(limit)
            .map { $0 }
    }

    private func makeArtistRankings(
        from events: [AnalyticsSnapshot.PlaybackEvent],
        limit: Int
    ) -> [MusicHistorySnapshot.ArtistRanking] {
        Dictionary(grouping: events, by: { $0.track.artistName })
            .compactMap { name, events -> MusicHistorySnapshot.ArtistRanking? in
                guard let representativeTrack = makeTrackRankings(from: events, limit: 1).first?.track else {
                    return nil
                }
                return MusicHistorySnapshot.ArtistRanking(
                    name: name,
                    playCount: events.count,
                    representativeTrack: representativeTrack
                )
            }
            .sorted(by: artistRankingSort)
            .prefix(limit)
            .map { $0 }
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
