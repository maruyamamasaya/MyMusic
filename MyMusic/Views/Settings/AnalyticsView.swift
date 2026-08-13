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
            tracks: libraryStore.unfilteredTracks,
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
            preferenceRatingsSection
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

    private var preferenceRatingsSection: some View {
        Section("いいね評価") {
            if snapshot.preferenceRatedTracks.isEmpty {
                emptyMessage("評価した曲はありません。")
            } else {
                NavigationLink {
                    PreferenceRatingsView(items: snapshot.preferenceRatedTracks)
                } label: {
                    LabeledContent("評価リスト", value: "\(snapshot.preferenceRatedTracks.count)曲")
                }
            }
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

private struct PreferenceRatingsView: View {
    let items: [AnalyticsSnapshot.TrackItem]

    @State private var filter = RatingFilter.all
    @State private var sortOrder = RatingSortOrder.title

    private var displayedItems: [AnalyticsSnapshot.TrackItem] {
        items
            .filter { filter.includes($0.playbackPreference) }
            .sorted { lhs, rhs in sortOrder.isOrderedBefore(lhs, rhs) }
    }

    var body: some View {
        List {
            if displayedItems.isEmpty {
                ContentUnavailableView(
                    "該当する評価はありません",
                    systemImage: "line.3.horizontal.decrease.circle"
                )
            } else {
                ForEach(displayedItems) { item in
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.track.title).lineLimit(1)
                            Text(item.track.artistName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text(String(format: "%+d", item.playbackPreference))
                            .font(.body.bold().monospacedDigit())
                            .foregroundStyle(item.playbackPreference > 0 ? Color.blue : Color.brown)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(
                                (item.playbackPreference > 0 ? Color.blue : Color.brown).opacity(0.12),
                                in: Capsule()
                            )
                    }
                }
            }
        }
        .navigationTitle("いいね評価リスト")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Menu {
                    Picker("評価フィルター", selection: $filter) {
                        ForEach(RatingFilter.allCases) { option in
                            Label(option.title, systemImage: option.systemImage).tag(option)
                        }
                    }
                } label: {
                    Label("評価を絞り込む", systemImage: filter == .all ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill")
                }

                Menu {
                    Picker("並び順", selection: $sortOrder) {
                        ForEach(RatingSortOrder.allCases) { option in
                            Text(option.title).tag(option)
                        }
                    }
                } label: {
                    Label("曲順を変更", systemImage: "arrow.up.arrow.down")
                }
            }
        }
    }
}

private enum RatingFilter: String, CaseIterable, Identifiable {
    case all
    case good
    case bad

    var id: Self { self }
    var title: String {
        switch self {
        case .all: "すべて"
        case .good: "グッド"
        case .bad: "バッド"
        }
    }
    var systemImage: String {
        switch self {
        case .all: "list.bullet"
        case .good: "hand.thumbsup.fill"
        case .bad: "hand.thumbsdown.fill"
        }
    }
    func includes(_ preference: Int) -> Bool {
        switch self {
        case .all: true
        case .good: preference > 0
        case .bad: preference < 0
        }
    }
}

private enum RatingSortOrder: String, CaseIterable, Identifiable {
    case title
    case rating
    case albumTrack

    var id: Self { self }
    var title: String {
        switch self {
        case .title: "曲名順"
        case .rating: "評価順"
        case .albumTrack: "アルバム曲順"
        }
    }

    func isOrderedBefore(_ lhs: AnalyticsSnapshot.TrackItem, _ rhs: AnalyticsSnapshot.TrackItem) -> Bool {
        switch self {
        case .title:
            let comparison = lhs.track.title.localizedStandardCompare(rhs.track.title)
            if comparison != .orderedSame { return comparison == .orderedAscending }
            return lhs.track.artistName.localizedStandardCompare(rhs.track.artistName) == .orderedAscending
        case .rating:
            if lhs.playbackPreference != rhs.playbackPreference {
                return lhs.playbackPreference > rhs.playbackPreference
            }
            return lhs.track.title.localizedStandardCompare(rhs.track.title) == .orderedAscending
        case .albumTrack:
            let lhsAlbum = lhs.track.albumTitle ?? ""
            let rhsAlbum = rhs.track.albumTitle ?? ""
            let albumComparison = lhsAlbum.localizedStandardCompare(rhsAlbum)
            if albumComparison != .orderedSame { return albumComparison == .orderedAscending }
            if (lhs.track.discNumber ?? 1) != (rhs.track.discNumber ?? 1) {
                return (lhs.track.discNumber ?? 1) < (rhs.track.discNumber ?? 1)
            }
            if (lhs.track.trackNumber ?? Int.max) != (rhs.track.trackNumber ?? Int.max) {
                return (lhs.track.trackNumber ?? Int.max) < (rhs.track.trackNumber ?? Int.max)
            }
            return lhs.track.title.localizedStandardCompare(rhs.track.title) == .orderedAscending
        }
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
