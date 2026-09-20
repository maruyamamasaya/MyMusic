import Foundation

nonisolated enum TrendPeriod: Int, CaseIterable, Sendable {
    case sixHours, day, threeDays, week, month, threeMonths, sixMonths, year

    var title: String {
        switch self {
        case .sixHours: "6時間"
        case .day: "24時間"
        case .threeDays: "3日"
        case .week: "7日"
        case .month: "30日"
        case .threeMonths: "3か月"
        case .sixMonths: "6か月"
        case .year: "1年"
        }
    }

    var context: String {
        switch self {
        case .sixHours, .day: "今日の聴き方・ムード"
        case .threeDays, .week: "最近の傾向"
        case .month, .threeMonths, .sixMonths, .year: "好みの変化"
        }
    }

    var showsComparison: Bool { rawValue >= Self.month.rawValue }

    var bucketCount: Int {
        switch self {
        case .sixHours: 6
        case .day: 8
        case .threeDays: 12
        case .week: 7
        case .month: 10
        case .threeMonths, .sixMonths: 13
        case .year: 12
        }
    }

    func start(before now: Date, calendar: Calendar = .current) -> Date {
        let component: Calendar.Component
        let amount: Int
        switch self {
        case .sixHours: (component, amount) = (.hour, -6)
        case .day: (component, amount) = (.hour, -24)
        case .threeDays: (component, amount) = (.day, -3)
        case .week: (component, amount) = (.day, -7)
        case .month: (component, amount) = (.day, -30)
        case .threeMonths: (component, amount) = (.month, -3)
        case .sixMonths: (component, amount) = (.month, -6)
        case .year: (component, amount) = (.year, -1)
        }
        return calendar.date(byAdding: component, value: amount, to: now) ?? now
    }
}

nonisolated enum TrendFeature: String, CaseIterable, Sendable {
    case energy, piano, ambient, electronic, drumAndBass, aggressive, calm, bright, dark, vocal, instrumental

    var title: String {
        switch self {
        case .energy: "エネルギー"
        case .piano: "ピアノ"
        case .ambient: "アンビエント"
        case .electronic: "エレクトロ"
        case .drumAndBass: "DnB"
        case .aggressive: "力強さ"
        case .calm: "穏やかさ"
        case .bright: "明るさ"
        case .dark: "ダーク"
        case .vocal: "ボーカル"
        case .instrumental: "インスト"
        }
    }

    func value(in values: TrackFeatureValues) -> Double? {
        let score: Double?
        switch self {
        case .energy: score = values.energy
        case .piano: score = values.piano
        case .ambient: score = values.ambient
        case .electronic: score = values.electronic
        case .drumAndBass: score = values.drumAndBass
        case .aggressive: score = values.aggressive
        case .calm: score = values.calm
        case .bright: score = values.bright
        case .dark: score = values.dark
        case .vocal: score = values.vocal
        case .instrumental: score = values.instrumental
        }
        guard let score, score.isFinite, (0...1).contains(score) else { return nil }
        return score
    }
}

nonisolated struct TrendEvent: Sendable {
    let trackID: Track.ID
    let date: Date
    let scores: [TrendFeature: Double]
}

nonisolated struct TrendPoint: Identifiable, Sendable {
    let date: Date
    let value: Double
    let count: Int
    let segment: Int
    var id: Date { date }
}

nonisolated struct TrendChange: Identifiable, Sendable {
    let feature: TrendFeature
    let earlier: Double
    let later: Double
    let earlierCount: Int
    let laterCount: Int
    var difference: Double { later - earlier }
    var id: TrendFeature { feature }
}

nonisolated struct TrendSnapshot: Sendable {
    let period: TrendPeriod
    let start: Date
    let end: Date
    let eligiblePlayCount: Int
    let availableFeatures: [TrendFeature]
    let points: [TrendFeature: [TrendPoint]]
    let comparisons: [TrendFeature: TrendChange]
    let changes: [TrendChange]

    func hasChart(for feature: TrendFeature) -> Bool {
        (points[feature]?.count ?? 0) >= 2
    }
}

/// Read-only, bounded aggregation over the events already loaded by PlaybackHistoryStore.
nonisolated enum RecentMusicTrendsService {
    static func makeIndex(
        historyEntries: [Track.ID: PlaybackHistory],
        features: [Track.ID: TrackFeature],
        now: Date,
        calendar: Calendar = .current
    ) -> [TrendEvent] {
        let start = TrendPeriod.year.start(before: now, calendar: calendar)
        var result: [TrendEvent] = []
        for (trackID, history) in historyEntries {
            guard let values = features[trackID]?.values else { continue }
            let recentEvents = history.playbackEvents.filter {
                $0.endedAt >= start && $0.endedAt <= now && !$0.isEarlySkip
            }
            guard !recentEvents.isEmpty else { continue }
            let scores = Dictionary(uniqueKeysWithValues: TrendFeature.allCases.compactMap { feature in
                feature.value(in: values).map { (feature, $0) }
            })
            guard !scores.isEmpty else { continue }
            for event in recentEvents {
                result.append(TrendEvent(trackID: trackID, date: event.endedAt, scores: scores))
            }
        }
        return result.sorted { $0.date < $1.date }
    }

    static func summarize(
        _ index: [TrendEvent], period: TrendPeriod, now: Date,
        calendar: Calendar = .current
    ) -> TrendSnapshot {
        let start = period.start(before: now, calendar: calendar)
        let duration = now.timeIntervalSince(start)
        let bucketDuration = duration / Double(period.bucketCount)
        let midpoint = start.addingTimeInterval(duration / 2)
        var buckets: [TrendFeature: [[Double]]] = [:]
        var halves: [TrendFeature: [[Double]]] = [:]
        var halfTracks: [TrendFeature: [Set<Track.ID>]] = [:]
        var allTracks: Set<Track.ID> = []
        var playCount = 0
        for event in index where event.date >= start && event.date <= now {
            playCount += 1
            allTracks.insert(event.trackID)
            let bucket = min(period.bucketCount - 1, Int(event.date.timeIntervalSince(start) / bucketDuration))
            let half = event.date < midpoint ? 0 : 1
            for (feature, score) in event.scores {
                if buckets[feature] == nil {
                    buckets[feature] = Array(repeating: [], count: period.bucketCount)
                    halves[feature] = [[], []]
                    halfTracks[feature] = [[], []]
                }
                buckets[feature]![bucket].append(score)
                halves[feature]![half].append(score)
                halfTracks[feature]![half].insert(event.trackID)
            }
        }

        var points: [TrendFeature: [TrendPoint]] = [:]
        var comparisons: [TrendFeature: TrendChange] = [:]
        var changes: [TrendChange] = []
        if playCount >= 5 && allTracks.count >= 2 {
            for feature in TrendFeature.allCases {
                guard let bins = buckets[feature] else { continue }
                let featureCount = bins.reduce(0) { $0 + $1.count }
                let featureTracks = halfTracks[feature, default: []].reduce(into: Set<Track.ID>()) { $0.formUnion($1) }
                guard featureCount >= 5, featureTracks.count >= 3 else { continue }
                var series: [TrendPoint] = []
                var segment = 0
                for (offset, scores) in bins.enumerated() {
                    if scores.isEmpty {
                        segment += 1
                        continue
                    }
                    series.append(TrendPoint(
                        date: start.addingTimeInterval((Double(offset) + 0.5) * bucketDuration),
                        value: scores.reduce(0, +) / Double(scores.count),
                        count: scores.count,
                        segment: segment
                    ))
                }
                points[feature] = series
                guard let pair = halves[feature], let tracks = halfTracks[feature],
                      pair[0].count >= 5, pair[1].count >= 5,
                      tracks[0].count >= 3, tracks[1].count >= 3 else { continue }
                let earlier = pair[0].reduce(0, +) / Double(pair[0].count)
                let later = pair[1].reduce(0, +) / Double(pair[1].count)
                let comparison = TrendChange(feature: feature, earlier: earlier, later: later,
                                             earlierCount: pair[0].count, laterCount: pair[1].count)
                comparisons[feature] = comparison
                guard abs(later - earlier) >= 0.10 else { continue }
                changes.append(comparison)
            }
        }
        changes.sort { abs($0.difference) > abs($1.difference) }
        return TrendSnapshot(period: period, start: start, end: now,
                             eligiblePlayCount: playCount,
                             availableFeatures: TrendFeature.allCases.filter { buckets[$0] != nil },
                             points: points, comparisons: comparisons, changes: changes)
    }
}
