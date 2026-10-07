import Foundation

/// Period totals use finished events and attribute listening time to the start date.
nonisolated struct PlaybackDurationSummary: Sendable {
    let secondsByDay: [Date: TimeInterval]
    let calendar: Calendar

    init(events: [PlaybackEvent], calendar: Calendar = .current) {
        self.calendar = calendar
        var secondsByDay: [Date: TimeInterval] = [:]
        for event in events where event.listenedSeconds.isFinite && event.listenedSeconds > 0 {
            secondsByDay[calendar.startOfDay(for: event.startedAt), default: 0] += event.listenedSeconds
        }
        self.secondsByDay = secondsByDay
    }

    func seconds(for date: Date, component: Calendar.Component) -> TimeInterval {
        guard let interval = calendar.dateInterval(of: component, for: date) else { return 0 }
        return secondsByDay.reduce(0) { total, item in
            total + (item.key >= interval.start && item.key < interval.end ? item.value : 0)
        }
    }

    static func formatted(_ seconds: TimeInterval) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0分" }
        let minutes = Int(min(seconds / 60, Double(Int.max / 60)))
        if minutes == 0 { return "1分未満" }
        let hours = minutes / 60
        return hours > 0 ? "\(hours)時間\(minutes % 60)分" : "\(minutes)分"
    }
}
