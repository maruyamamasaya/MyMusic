import Foundation

struct MusicHistoryTrackMonthSummary: Identifiable {
    let date: Date
    let playCount: Int

    var id: Date { date }
}

struct MusicHistoryTrackSummary: Identifiable {
    let track: Track
    let firstPlayedAt: Date
    let lastPlayedAt: Date
    let totalPlayCount: Int
    let mostPlayedMonth: MusicHistoryTrackMonthSummary
    let months: [MusicHistoryTrackMonthSummary]

    var id: Track.ID { track.id }
}

struct MusicHistoryDaySummary: Identifiable {
    let date: Date
    let playCount: Int
    let tracks: [MusicHistorySnapshot.TrackRanking]

    var id: Date { date }
}

struct MusicHistoryCalendarMonth: Identifiable {
    let date: Date
    let daysByNumber: [Int: MusicHistoryDaySummary]

    var id: Date { date }
    var playCount: Int { daysByNumber.values.reduce(0) { $0 + $1.playCount } }
}

struct MusicHistoryCalendarYear: Identifiable {
    let year: Int
    let months: [MusicHistoryCalendarMonth]
    let maxDailyPlayCount: Int

    var id: Int { year }
}

struct MusicHistoryTimeCapsuleSummary: Identifiable {
    enum Distance: String, Identifiable {
        case thirtyDays
        case threeMonths
        case sixMonths
        case oneYear

        var id: String { rawValue }
        var title: String {
            switch self {
            case .thirtyDays: "30日前のあなた"
            case .threeMonths: "3か月前のあなた"
            case .sixMonths: "6か月前のあなた"
            case .oneYear: "1年前のあなた"
            }
        }
    }

    let distance: Distance
    let targetDate: Date
    let topTracks: [MusicHistorySnapshot.TrackRanking]
    let topArtistNames: [String]

    var id: Distance { distance }
}

struct MusicHistoryMemorySnapshot {
    let trackHistories: [Track.ID: MusicHistoryTrackSummary]
    let calendarYears: [MusicHistoryCalendarYear]
    let timeCapsules: [MusicHistoryTimeCapsuleSummary]

    static let empty = MusicHistoryMemorySnapshot(
        trackHistories: [:],
        calendarYears: [],
        timeCapsules: []
    )
}

@MainActor
final class MusicHistoryMemoryService {
    private let capsuleTrackLimit = 5
    private let capsuleWindowDays = 7

    func makeSnapshot(
        playbackMonths: [AnalyticsSnapshot.MonthGroup],
        events: [AnalyticsSnapshot.PlaybackEvent],
        now: Date,
        calendar: Calendar
    ) -> MusicHistoryMemorySnapshot {
        MusicHistoryMemorySnapshot(
            trackHistories: makeTrackHistories(events: events, calendar: calendar),
            calendarYears: makeCalendarYears(playbackMonths: playbackMonths, calendar: calendar),
            timeCapsules: makeTimeCapsules(events: events, now: now, calendar: calendar)
        )
    }

    private func makeTrackHistories(
        events: [AnalyticsSnapshot.PlaybackEvent],
        calendar: Calendar
    ) -> [Track.ID: MusicHistoryTrackSummary] {
        Dictionary(grouping: events, by: { $0.track.id }).compactMapValues { trackEvents in
            guard let track = trackEvents.first?.track,
                  let firstPlayedAt = trackEvents.map(\.playedAt).min(),
                  let lastPlayedAt = trackEvents.map(\.playedAt).max() else { return nil }

            let months = Dictionary(grouping: trackEvents) { event in
                calendar.date(from: calendar.dateComponents([.year, .month], from: event.playedAt))
                    ?? calendar.startOfDay(for: event.playedAt)
            }
            .map { date, events in
                MusicHistoryTrackMonthSummary(date: date, playCount: events.count)
            }
            .sorted { $0.date < $1.date }

            guard let mostPlayedMonth = months.sorted(by: monthRankingSort).first else { return nil }
            return MusicHistoryTrackSummary(
                track: track,
                firstPlayedAt: firstPlayedAt,
                lastPlayedAt: lastPlayedAt,
                totalPlayCount: trackEvents.count,
                mostPlayedMonth: mostPlayedMonth,
                months: months
            )
        }
    }

    private func makeCalendarYears(
        playbackMonths: [AnalyticsSnapshot.MonthGroup],
        calendar: Calendar
    ) -> [MusicHistoryCalendarYear] {
        Dictionary(grouping: playbackMonths) {
            calendar.component(.year, from: $0.date)
        }
        .map { year, playbackMonths in
            let playbackMonthsByNumber = Dictionary(uniqueKeysWithValues: playbackMonths.map {
                (calendar.component(.month, from: $0.date), $0)
            })
            let months = (1...12).compactMap { monthNumber -> MusicHistoryCalendarMonth? in
                guard let date = calendar.date(from: DateComponents(year: year, month: monthNumber)) else {
                    return nil
                }
                let daysByNumber = Dictionary(uniqueKeysWithValues:
                    (playbackMonthsByNumber[monthNumber]?.days ?? []).map { day in
                        let summary = MusicHistoryDaySummary(
                            date: day.date,
                            playCount: day.events.count,
                            tracks: trackRankings(from: day.events, limit: nil)
                        )
                        return (calendar.component(.day, from: day.date), summary)
                    }
                )
                return MusicHistoryCalendarMonth(date: date, daysByNumber: daysByNumber)
            }
            let maxDailyPlayCount = months
                .flatMap { $0.daysByNumber.values }
                .map(\.playCount)
                .max() ?? 0
            return MusicHistoryCalendarYear(
                year: year,
                months: months,
                maxDailyPlayCount: maxDailyPlayCount
            )
        }
        .sorted { $0.year > $1.year }
    }

    private func makeTimeCapsules(
        events: [AnalyticsSnapshot.PlaybackEvent],
        now: Date,
        calendar: Calendar
    ) -> [MusicHistoryTimeCapsuleSummary] {
        let candidates: [(MusicHistoryTimeCapsuleSummary.Distance, Date?)] = [
            (.thirtyDays, calendar.date(byAdding: .day, value: -30, to: now)),
            (.threeMonths, calendar.date(byAdding: .month, value: -3, to: now)),
            (.sixMonths, calendar.date(byAdding: .month, value: -6, to: now)),
            (.oneYear, calendar.date(byAdding: .year, value: -1, to: now))
        ]

        return candidates.compactMap { distance, targetDate in
            guard let targetDate,
                  let start = calendar.date(byAdding: .day, value: -capsuleWindowDays, to: targetDate),
                  let end = calendar.date(byAdding: .day, value: capsuleWindowDays + 1, to: targetDate)
            else { return nil }

            let capsuleEvents = events.filter { $0.playedAt >= start && $0.playedAt < end }
            guard !capsuleEvents.isEmpty else { return nil }

            let artists = Dictionary(grouping: capsuleEvents, by: { $0.track.artistName })
                .map { (name: $0.key, playCount: $0.value.count) }
                .sorted {
                    if $0.playCount != $1.playCount { return $0.playCount > $1.playCount }
                    return $0.name.localizedStandardCompare($1.name) == .orderedAscending
                }

            return MusicHistoryTimeCapsuleSummary(
                distance: distance,
                targetDate: targetDate,
                topTracks: trackRankings(from: capsuleEvents, limit: capsuleTrackLimit),
                topArtistNames: Array(artists.prefix(2).map(\.name))
            )
        }
    }

    private func trackRankings(
        from events: [AnalyticsSnapshot.PlaybackEvent],
        limit: Int?
    ) -> [MusicHistorySnapshot.TrackRanking] {
        let rankings = Dictionary(grouping: events, by: { $0.track.id }).values
            .compactMap { events -> MusicHistorySnapshot.TrackRanking? in
                guard let track = events.first?.track else { return nil }
                return MusicHistorySnapshot.TrackRanking(track: track, playCount: events.count)
            }
            .sorted {
                if $0.playCount != $1.playCount { return $0.playCount > $1.playCount }
                let titleComparison = $0.track.title.localizedStandardCompare($1.track.title)
                if titleComparison != .orderedSame { return titleComparison == .orderedAscending }
                return $0.track.artistName.localizedStandardCompare($1.track.artistName) == .orderedAscending
            }
        guard let limit else { return rankings }
        return Array(rankings.prefix(limit))
    }

    private func monthRankingSort(
        _ lhs: MusicHistoryTrackMonthSummary,
        _ rhs: MusicHistoryTrackMonthSummary
    ) -> Bool {
        if lhs.playCount != rhs.playCount { return lhs.playCount > rhs.playCount }
        return lhs.date > rhs.date
    }
}
