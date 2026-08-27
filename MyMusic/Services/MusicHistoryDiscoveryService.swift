import Foundation

struct MusicHistoryComparisonPeriod {
    enum Kind {
        case thirtyDays
        case threeMonths
        case yearOverYear
    }

    let kind: Kind
    let current: DateInterval
    let previous: DateInterval
    let currentLabel: String
    let previousLabel: String

    var summary: String {
        switch kind {
        case .thirtyDays:
            "直近30日と、その前の30日"
        case .threeMonths:
            "直近3か月と、その前の3か月"
        case .yearOverYear:
            "\(currentLabel)と\(previousLabel)"
        }
    }

    var newDiscoveryTitle: String {
        kind == .yearOverYear ? "今年の新しい出会い" : "最近の新しい出会い"
    }
}

struct MusicHistoryTrackChange: Identifiable {
    let track: Track
    let currentPlayCount: Int
    let previousPlayCount: Int

    var id: Track.ID { track.id }
    var increase: Int { currentPlayCount - previousPlayCount }
}

struct MusicHistoryArtistChange: Identifiable {
    let name: String
    let representativeTrack: Track
    let currentPlayCount: Int
    let previousPlayCount: Int

    var id: String { name }
    var increase: Int { currentPlayCount - previousPlayCount }
}

struct MusicHistoryDormantTrack: Identifiable {
    let track: Track
    let previousPlayCount: Int
    let lastPlayedAt: Date
    let daysSinceLastPlayed: Int

    var id: Track.ID { track.id }
}

struct MusicHistoryNewDiscovery: Identifiable {
    let track: Track
    let playCount: Int
    let firstPlayedAt: Date

    var id: Track.ID { track.id }
}

struct MusicHistoryDiscoverySnapshot {
    let period: MusicHistoryComparisonPeriod
    let hasComparisonData: Bool
    let risingTracks: [MusicHistoryTrackChange]
    let risingArtists: [MusicHistoryArtistChange]
    let dormantTracks: [MusicHistoryDormantTrack]
    let newDiscoveries: [MusicHistoryNewDiscovery]

    var hasInsights: Bool {
        !risingTracks.isEmpty
            || !risingArtists.isEmpty
            || !dormantTracks.isEmpty
            || !newDiscoveries.isEmpty
    }
}

@MainActor
final class MusicHistoryDiscoveryService {
    private let insightLimit = 5

    func makeSnapshot(
        events: [AnalyticsSnapshot.PlaybackEvent],
        now: Date,
        calendar: Calendar
    ) -> MusicHistoryDiscoverySnapshot? {
        guard let firstEventDate = events.map(\.playedAt).min(),
              let lastEventDate = events.map(\.playedAt).max() else { return nil }

        let period = comparisonPeriod(
            firstEventDate: firstEventDate,
            lastEventDate: lastEventDate,
            now: now,
            calendar: calendar
        )
        let currentEvents = events.filter { period.current.contains($0.playedAt) }
        let previousEvents = events.filter { period.previous.contains($0.playedAt) }
        let hasComparisonData = previousEvents.count >= 3

        return MusicHistoryDiscoverySnapshot(
            period: period,
            hasComparisonData: hasComparisonData,
            risingTracks: hasComparisonData
                ? risingTracks(current: currentEvents, previous: previousEvents)
                : [],
            risingArtists: hasComparisonData
                ? risingArtists(current: currentEvents, previous: previousEvents)
                : [],
            dormantTracks: hasComparisonData
                ? dormantTracks(
                    allEvents: events,
                    current: currentEvents,
                    previous: previousEvents,
                    period: period,
                    now: now,
                    calendar: calendar
                )
                : [],
            newDiscoveries: newDiscoveries(
                allEvents: events,
                current: currentEvents,
                period: period
            )
        )
    }

    private func comparisonPeriod(
        firstEventDate: Date,
        lastEventDate: Date,
        now: Date,
        calendar: Calendar
    ) -> MusicHistoryComparisonPeriod {
        let historySpanDays = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: firstEventDate),
            to: calendar.startOfDay(for: lastEventDate)
        ).day ?? 0

        if historySpanDays >= 365 {
            let currentYearStart = calendar.date(from: calendar.dateComponents([.year], from: now)) ?? now
            let nextYearStart = calendar.date(byAdding: .year, value: 1, to: currentYearStart) ?? now
            let previousYearStart = calendar.date(byAdding: .year, value: -1, to: currentYearStart) ?? currentYearStart
            let currentYear = calendar.component(.year, from: currentYearStart)
            return MusicHistoryComparisonPeriod(
                kind: .yearOverYear,
                current: DateInterval(start: currentYearStart, end: nextYearStart),
                previous: DateInterval(start: previousYearStart, end: currentYearStart),
                currentLabel: "\(currentYear)年",
                previousLabel: "\(currentYear - 1)年"
            )
        }

        if historySpanDays >= 180 {
            return rollingPeriod(days: 90, kind: .threeMonths, now: now, calendar: calendar)
        }

        return rollingPeriod(days: 30, kind: .thirtyDays, now: now, calendar: calendar)
    }

    private func rollingPeriod(
        days: Int,
        kind: MusicHistoryComparisonPeriod.Kind,
        now: Date,
        calendar: Calendar
    ) -> MusicHistoryComparisonPeriod {
        let currentStart = calendar.date(byAdding: .day, value: -days, to: now) ?? now
        let previousStart = calendar.date(byAdding: .day, value: -(days * 2), to: now) ?? currentStart
        return MusicHistoryComparisonPeriod(
            kind: kind,
            current: DateInterval(start: currentStart, end: now),
            previous: DateInterval(start: previousStart, end: currentStart),
            currentLabel: days == 30 ? "直近30日" : "直近3か月",
            previousLabel: days == 30 ? "その前の30日" : "その前の3か月"
        )
    }

    private func risingTracks(
        current: [AnalyticsSnapshot.PlaybackEvent],
        previous: [AnalyticsSnapshot.PlaybackEvent]
    ) -> [MusicHistoryTrackChange] {
        let currentCounts = trackCounts(in: current)
        let previousCounts = trackCounts(in: previous)

        return currentCounts.values.compactMap { current -> MusicHistoryTrackChange? in
            let previousCount = previousCounts[current.track.id]?.count ?? 0
            guard previousCount > 0,
                  current.count >= 3,
                  current.count - previousCount >= 2 else { return nil }
            return MusicHistoryTrackChange(
                track: current.track,
                currentPlayCount: current.count,
                previousPlayCount: previousCount
            )
        }
        .sorted(by: trackChangeSort)
        .prefix(insightLimit)
        .map { $0 }
    }

    private func risingArtists(
        current: [AnalyticsSnapshot.PlaybackEvent],
        previous: [AnalyticsSnapshot.PlaybackEvent]
    ) -> [MusicHistoryArtistChange] {
        let currentGroups = Dictionary(grouping: current, by: { $0.track.artistName })
        let previousGroups = Dictionary(grouping: previous, by: { $0.track.artistName })

        return currentGroups.compactMap { name, events -> MusicHistoryArtistChange? in
            let previousCount = previousGroups[name]?.count ?? 0
            guard events.count >= 4,
                  events.count - previousCount >= 3,
                  let representativeTrack = topTrack(in: events) else { return nil }
            return MusicHistoryArtistChange(
                name: name,
                representativeTrack: representativeTrack,
                currentPlayCount: events.count,
                previousPlayCount: previousCount
            )
        }
        .sorted(by: artistChangeSort)
        .prefix(insightLimit)
        .map { $0 }
    }

    private func dormantTracks(
        allEvents: [AnalyticsSnapshot.PlaybackEvent],
        current: [AnalyticsSnapshot.PlaybackEvent],
        previous: [AnalyticsSnapshot.PlaybackEvent],
        period: MusicHistoryComparisonPeriod,
        now: Date,
        calendar: Calendar
    ) -> [MusicHistoryDormantTrack] {
        let allGroups = Dictionary(grouping: allEvents, by: { $0.track.id })
        let currentCounts = trackCounts(in: current)
        let previousCounts = trackCounts(in: previous)
        let minimumPreviousCount: Int = switch period.kind {
        case .thirtyDays: 3
        case .threeMonths: 5
        case .yearOverYear: 8
        }

        return previousCounts.values.compactMap { previous -> MusicHistoryDormantTrack? in
            guard previous.count >= minimumPreviousCount,
                  currentCounts[previous.track.id] == nil,
                  let trackEvents = allGroups[previous.track.id],
                  let lastPlayedAt = trackEvents.map(\.playedAt).max(),
                  lastPlayedAt < period.current.start else { return nil }
            let days = calendar.dateComponents(
                [.day],
                from: calendar.startOfDay(for: lastPlayedAt),
                to: calendar.startOfDay(for: now)
            ).day ?? 0
            return MusicHistoryDormantTrack(
                track: previous.track,
                previousPlayCount: previous.count,
                lastPlayedAt: lastPlayedAt,
                daysSinceLastPlayed: max(0, days)
            )
        }
        .sorted {
            if $0.previousPlayCount != $1.previousPlayCount {
                return $0.previousPlayCount > $1.previousPlayCount
            }
            return $0.lastPlayedAt < $1.lastPlayedAt
        }
        .prefix(insightLimit)
        .map { $0 }
    }

    private func newDiscoveries(
        allEvents: [AnalyticsSnapshot.PlaybackEvent],
        current: [AnalyticsSnapshot.PlaybackEvent],
        period: MusicHistoryComparisonPeriod
    ) -> [MusicHistoryNewDiscovery] {
        let allGroups = Dictionary(grouping: allEvents, by: { $0.track.id })
        let currentCounts = trackCounts(in: current)

        return currentCounts.values.compactMap { current -> MusicHistoryNewDiscovery? in
            guard current.count >= 2,
                  let firstPlayedAt = allGroups[current.track.id]?.map(\.playedAt).min(),
                  period.current.contains(firstPlayedAt) else { return nil }
            return MusicHistoryNewDiscovery(
                track: current.track,
                playCount: current.count,
                firstPlayedAt: firstPlayedAt
            )
        }
        .sorted {
            if $0.playCount != $1.playCount { return $0.playCount > $1.playCount }
            return $0.firstPlayedAt > $1.firstPlayedAt
        }
        .prefix(insightLimit)
        .map { $0 }
    }

    private func trackCounts(
        in events: [AnalyticsSnapshot.PlaybackEvent]
    ) -> [Track.ID: TrackCount] {
        Dictionary(grouping: events, by: { $0.track.id }).compactMapValues { events in
            guard let track = events.first?.track else { return nil }
            return TrackCount(track: track, count: events.count)
        }
    }

    private func topTrack(in events: [AnalyticsSnapshot.PlaybackEvent]) -> Track? {
        trackCounts(in: events).values.sorted {
            if $0.count != $1.count { return $0.count > $1.count }
            return $0.track.title.localizedStandardCompare($1.track.title) == .orderedAscending
        }.first?.track
    }

    private func trackChangeSort(_ lhs: MusicHistoryTrackChange, _ rhs: MusicHistoryTrackChange) -> Bool {
        if lhs.increase != rhs.increase { return lhs.increase > rhs.increase }
        if lhs.currentPlayCount != rhs.currentPlayCount { return lhs.currentPlayCount > rhs.currentPlayCount }
        return lhs.track.title.localizedStandardCompare(rhs.track.title) == .orderedAscending
    }

    private func artistChangeSort(_ lhs: MusicHistoryArtistChange, _ rhs: MusicHistoryArtistChange) -> Bool {
        if lhs.increase != rhs.increase { return lhs.increase > rhs.increase }
        if lhs.currentPlayCount != rhs.currentPlayCount { return lhs.currentPlayCount > rhs.currentPlayCount }
        return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
    }

    private struct TrackCount {
        let track: Track
        let count: Int
    }
}
