import Foundation

nonisolated struct TodayPlaybackSummary: Equatable, Sendable {
    let playCount: Int
    let listenedSeconds: TimeInterval

    var compactDuration: String {
        let seconds = listenedSeconds.isFinite ? max(0, listenedSeconds) : 0
        let minutes = Int(seconds / 60)
        return minutes >= 60
            ? "\(minutes / 60)時間\(minutes % 60)分"
            : "\(minutes)分"
    }

    var compactText: String { "今日 \(playCount)回 · \(compactDuration)" }
}

nonisolated struct TodayPlaybackSummaryService {
    func summary(
        from histories: [Track.ID: PlaybackHistory],
        now: Date = Date(),
        calendar: Calendar = .playbackHistory
    ) -> TodayPlaybackSummary {
        let components = calendar.dateComponents([.year, .month, .day], from: now)
        let dayKey = String(format: "%04d-%02d-%02d",
                            components.year ?? 0, components.month ?? 0, components.day ?? 0)
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? now
        var count = 0
        var seconds: TimeInterval = 0
        for history in histories.values {
            count += history.dailySummaries[dayKey]?.playCount ?? 0
            for event in history.playbackEvents where event.startedAt >= start && event.startedAt < end {
                seconds += event.listenedSeconds
            }
        }
        return TodayPlaybackSummary(playCount: count, listenedSeconds: seconds)
    }
}
