import SwiftUI
import UniformTypeIdentifiers

struct AnalyticsView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(SettingsStore.self) private var settingsStore
    @State private var showsAllMostPlayed = false

    private var snapshot: AnalyticsSnapshot {
        AnalyticsService().makeSnapshot(
            tracks: libraryStore.tracks,
            historyEntries: playbackHistoryStore.entries,
            playlists: playlistStore.playlists
        )
    }

    private var export: AnalyticsExport {
        AnalyticsExport(csv: AnalyticsService().csv(
            snapshot: snapshot,
            playlists: playlistStore.playlists,
            equalizer: settingsStore.equalizer,
            customEqualizerPresets: settingsStore.customEqualizerPresets
        ))
    }

    var body: some View {
        List {
            overviewSection
            playbackHistorySection
            mostPlayedSection
        }
        .navigationTitle("分析")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(item: export, preview: SharePreview("MyMusic分析データ")) {
                    Label("データをダウンロード", systemImage: "square.and.arrow.down")
                }
            }
        }
    }

    private var overviewSection: some View {
        Section("概要") {
            LabeledContent("総再生回数", value: "\(snapshot.totalPlayCount)回")
            LabeledContent("再生した楽曲数", value: "\(snapshot.playedTrackCount)曲")
            LabeledContent("再生履歴", value: "\(snapshot.playbackMonths.reduce(0) { $0 + $1.eventCount })件")
            LabeledContent("お気に入りの曲", value: "\(snapshot.favoriteCount)曲")
            LabeledContent("プレイリスト", value: "\(snapshot.playlistCount)件")
        }
    }

    private var playbackHistorySection: some View {
        Section("再生履歴") {
            if snapshot.playbackMonths.isEmpty {
                emptyMessage("再生履歴はありません。")
            } else {
                NavigationLink {
                    PlaybackHistoryCalendarView(months: snapshot.playbackMonths)
                } label: {
                    LabeledContent(
                        "再生履歴カレンダー",
                        value: "\(snapshot.playbackMonths.reduce(0) { $0 + $1.eventCount })件"
                    )
                }
            }
        }
    }

    private var mostPlayedSection: some View {
        Section {
            if snapshot.mostPlayedTracks.isEmpty {
                emptyMessage("再生回数の記録はありません。")
            } else {
                ForEach(showsAllMostPlayed ? snapshot.mostPlayedTracks : Array(snapshot.mostPlayedTracks.prefix(10))) { item in
                    HStack {
                        trackSummary(item.track)
                        Spacer()
                        Text("\(item.playCount)回").foregroundStyle(.secondary).monospacedDigit()
                    }
                }
            }
        } header: {
            expandableHeader("よく再生している曲", isExpanded: $showsAllMostPlayed, count: snapshot.mostPlayedTracks.count)
        }
    }

    private func expandableHeader(_ title: String, isExpanded: Binding<Bool>, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            if count > 10 {
                Button(isExpanded.wrappedValue ? "閉じる" : "すべて表示") { isExpanded.wrappedValue.toggle() }
                    .textCase(nil)
            }
        }
    }

    private func trackSummary(_ track: Track) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(track.title).lineLimit(1)
            Text(track.artistName).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
        }
    }

    private func emptyMessage(_ message: String) -> some View {
        Text(message).foregroundStyle(.secondary)
    }
}

private struct PlaybackHistoryCalendarView: View {
    let months: [AnalyticsSnapshot.MonthGroup]
    @State private var displayedMonthIndex = 0

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    private var month: AnalyticsSnapshot.MonthGroup {
        calendarMonths[displayedMonthIndex]
    }

    private var calendar: Calendar {
        var calendar = Calendar.current
        calendar.locale = Locale(identifier: "ja_JP")
        return calendar
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let firstIndex = calendar.firstWeekday - 1
        return Array(symbols[firstIndex...] + symbols[..<firstIndex])
    }

    private var calendarMonths: [AnalyticsSnapshot.MonthGroup] {
        guard let oldestMonth = months.last else { return [] }

        let groupsByMonth = Dictionary(uniqueKeysWithValues: months.map { (monthStart(for: $0.date), $0) })
        let currentMonth = monthStart(for: Date())
        var cursor = max(currentMonth, monthStart(for: months[0].date))
        let oldestDate = monthStart(for: oldestMonth.date)
        var result: [AnalyticsSnapshot.MonthGroup] = []

        while cursor >= oldestDate {
            result.append(groupsByMonth[cursor] ?? AnalyticsSnapshot.MonthGroup(date: cursor, days: []))
            guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: cursor) else { break }
            cursor = previousMonth
        }
        return result
    }

    private var calendarDays: [CalendarDay] {
        guard
            let dayRange = calendar.range(of: .day, in: .month, for: month.date),
            let firstDay = calendar.date(from: calendar.dateComponents([.year, .month], from: month.date))
        else { return [] }

        let leadingEmptyDays = (calendar.component(.weekday, from: firstDay) - calendar.firstWeekday + 7) % 7
        let groupsByDay = Dictionary(uniqueKeysWithValues: month.days.map {
            (calendar.component(.day, from: $0.date), $0)
        })

        return (0..<leadingEmptyDays).map { CalendarDay(id: $0, dayNumber: nil, group: nil) }
            + dayRange.map { dayNumber in
                CalendarDay(
                    id: leadingEmptyDays + dayNumber - 1,
                    dayNumber: dayNumber,
                    group: groupsByDay[dayNumber]
                )
            }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                monthPicker

                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(weekdaySymbols, id: \.self) { symbol in
                        Text(symbol)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }

                    ForEach(calendarDays) { calendarDay in
                        if let day = calendarDay.group {
                            NavigationLink {
                                PlaybackDayDetailView(day: day)
                            } label: {
                                dayCell(dayNumber: calendarDay.dayNumber, eventCount: day.events.count)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(calendarDay.dayNumber ?? 0)日、\(day.events.count)件")
                            .accessibilityHint("再生した曲の一覧を表示")
                        } else if let dayNumber = calendarDay.dayNumber {
                            dayCell(dayNumber: dayNumber, eventCount: nil)
                        } else {
                            Color.clear
                                .aspectRatio(0.82, contentMode: .fit)
                                .accessibilityHidden(true)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("再生履歴カレンダー")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var monthPicker: some View {
        HStack {
            Button("前の月", systemImage: "chevron.left") {
                displayedMonthIndex += 1
            }
            .labelStyle(.iconOnly)
            .disabled(displayedMonthIndex == calendarMonths.count - 1)

            Spacer()

            Text(month.date.formatted(.dateTime.year().month(.wide)))
                .font(.headline)
                .contentTransition(.numericText())

            Spacer()

            Button("次の月", systemImage: "chevron.right") {
                displayedMonthIndex -= 1
            }
            .labelStyle(.iconOnly)
            .disabled(displayedMonthIndex == 0)
        }
        .font(.headline)
        .padding(.horizontal, 8)
    }

    private func monthStart(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func dayCell(dayNumber: Int?, eventCount: Int?) -> some View {
        VStack(spacing: 5) {
            Text(dayNumber.map(String.init) ?? "")
                .font(.body.weight(eventCount == nil ? .regular : .semibold))

            if let eventCount {
                Text("\(eventCount)件")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.tint)
                    .monospacedDigit()
            } else {
                Text(" ").font(.caption2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(0.82, contentMode: .fit)
        .background(eventCount == nil ? Color.clear : Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
    }

    private struct CalendarDay: Identifiable {
        let id: Int
        let dayNumber: Int?
        let group: AnalyticsSnapshot.DayGroup?
    }
}

private struct PlaybackDayDetailView: View {
    let day: AnalyticsSnapshot.DayGroup

    var body: some View {
        List(day.events) { event in
            VStack(alignment: .leading, spacing: 3) {
                Text(event.track.title).lineLimit(1)
                Text("\(event.track.artistName) • \(AnalyticsService.dateTimeFormatter.string(from: event.playedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(day.date.formatted(.dateTime.year().month().day()))
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct AnalyticsExport: Transferable {
    let csv: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { export in
            Data(export.csv.utf8)
        }
        .suggestedFileName("MyMusic-Analytics.csv")
    }
}
