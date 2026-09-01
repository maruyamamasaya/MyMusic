import Foundation

struct PlaybackBehaviorAnalysis: Sendable {
    let overplayResults: [OverplayAnalysisResult]
    let preferenceDriftResults: [PreferenceDriftAnalysisResult]

    var overplayCandidates: [OverplayAnalysisResult] {
        overplayResults.filter { OverplayScoring.isCandidate($0.score) }
    }

    var preferenceDriftCandidates: [PreferenceDriftAnalysisResult] {
        preferenceDriftResults.filter(\.isCandidate)
    }
}

struct OverplayAnalysisResult: Identifiable, Hashable, Sendable {
    let track: Track
    let score: OverplayScore
    var id: Track.ID { track.id }
}

struct PreferenceDriftAnalysisResult: Identifiable, Hashable, Sendable {
    let track: Track
    let playbackPreference: Int
    let score: PreferenceDriftScore
    let isCandidate: Bool
    var id: Track.ID { track.id }
}

struct PlaybackBehaviorAnalyzer: Sendable {
    func analyze(
        tracks: [Track],
        historyByTrackID: [Track.ID: PlaybackHistory],
        now: Date = Date(),
        calendar: Calendar = .playbackHistory
    ) -> PlaybackBehaviorAnalysis {
        let recentSeven = dayKeys(offsets: 0..<OverplayScoring.recentDays, now: now, calendar: calendar)
        let baseline = dayKeys(
            offsets: OverplayScoring.recentDays..<(OverplayScoring.recentDays + OverplayScoring.baselineDays),
            now: now,
            calendar: calendar
        )
        let recentThirty = dayKeys(offsets: 0..<PreferenceDriftScoring.recentDays, now: now, calendar: calendar)
        let recentStart = calendar.startOfDay(for: calendar.date(
            byAdding: .day, value: -(PreferenceDriftScoring.recentDays - 1), to: now
        ) ?? now)
        let today = calendar.startOfDay(for: now)

        var overplayResults: [OverplayAnalysisResult] = []
        var driftResults: [PreferenceDriftAnalysisResult] = []
        for track in tracks {
            guard let history = historyByTrackID[track.id] else { continue }
            let recentPlayCount = sum(history.dailySummaries, keys: recentSeven, value: \.playCount)
            let baselinePlayCount = sum(history.dailySummaries, keys: baseline, value: \.playCount)
            let overplay = OverplayScoring.score(
                recentPlayCount: recentPlayCount,
                baselinePlayCount: baselinePlayCount
            )
            overplayResults.append(OverplayAnalysisResult(track: track, score: overplay))

            let recentFull = sum(history.dailySummaries, keys: recentThirty, value: \.fullPlaybackCount)
            let recentSkip = sum(history.dailySummaries, keys: recentThirty, value: \.skipCount)
            let historicalSummaries = history.dailySummaries.filter { key, _ in
                guard let date = Self.date(from: key, calendar: calendar) else { return false }
                return date < recentStart && date <= today
            }
            let historicalFull = historicalSummaries.values.reduce(0) { $0 + $1.fullPlaybackCount }
            let historicalSkip = historicalSummaries.values.reduce(0) { $0 + $1.skipCount }
            let drift = PreferenceDriftScoring.score(
                playbackPreference: history.playbackPreference,
                recentFullPlaybackCount: recentFull,
                recentSkipCount: recentSkip,
                historicalFullPlaybackCount: historicalFull,
                historicalSkipCount: historicalSkip,
                overplayScore: overplay.score
            )
            driftResults.append(PreferenceDriftAnalysisResult(
                track: track,
                playbackPreference: history.playbackPreference,
                score: drift,
                isCandidate: PreferenceDriftScoring.isCandidate(
                    playbackPreference: history.playbackPreference, score: drift
                )
            ))
        }

        return PlaybackBehaviorAnalysis(
            overplayResults: overplayResults.sorted { $0.score.score > $1.score.score },
            preferenceDriftResults: driftResults.sorted { $0.score.stableScore > $1.score.stableScore }
        )
    }

    private func dayKeys(
        offsets: Range<Int>, now: Date, calendar: Calendar
    ) -> Set<String> {
        Set(offsets.compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: now).map {
                Self.dayKey(for: $0, calendar: calendar)
            }
        })
    }

    private func sum(
        _ summaries: [String: PlaybackDailySummary],
        keys: Set<String>,
        value: KeyPath<PlaybackDailySummary, Int>
    ) -> Int {
        keys.reduce(0) { $0 + (summaries[$1]?[keyPath: value] ?? 0) }
    }

    private static func dayKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", components.year ?? 0, components.month ?? 0, components.day ?? 0)
    }

    private static func date(from dayKey: String, calendar: Calendar) -> Date? {
        let values = dayKey.split(separator: "-").compactMap { Int($0) }
        guard values.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: values[0], month: values[1], day: values[2]))
    }
}

extension Calendar {
    nonisolated static var playbackHistory: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }
}
