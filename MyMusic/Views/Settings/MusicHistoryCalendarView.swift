import SwiftUI

struct MusicHistoryCalendarView: View {
    let years: [MusicHistoryCalendarYear]
    let trackHistories: [Track.ID: MusicHistoryTrackSummary]
    @State private var selectedYear: Int

    init(
        years: [MusicHistoryCalendarYear],
        trackHistories: [Track.ID: MusicHistoryTrackSummary],
        initialYear: Int
    ) {
        self.years = years
        self.trackHistories = trackHistories
        _selectedYear = State(initialValue: years.contains { $0.year == initialYear }
            ? initialYear
            : years.first?.year ?? initialYear)
    }

    private var year: MusicHistoryCalendarYear? {
        years.first { $0.year == selectedYear } ?? years.first
    }

    var body: some View {
        Group {
            if let year {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 20) {
                        Picker("年", selection: $selectedYear) {
                            ForEach(years) { year in
                                Text("\(year.year)年").tag(year.year)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.horizontal, 16)

                        ForEach(year.months) { month in
                            MusicHistoryCalendarMonthView(
                                month: month,
                                maxDailyPlayCount: year.maxDailyPlayCount,
                                trackHistories: trackHistories
                            )
                        }
                    }
                    .padding(.vertical, 16)
                }
            } else {
                ContentUnavailableView(
                    "音楽を聴いた日がまだありません",
                    systemImage: "calendar",
                    description: Text("聴き続けると、日々の音楽がカレンダーに積み重なります。")
                )
            }
        }
        .navigationTitle("音楽カレンダー")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct MusicHistoryCalendarMonthView: View {
    let month: MusicHistoryCalendarMonth
    let maxDailyPlayCount: Int
    let trackHistories: [Track.ID: MusicHistoryTrackSummary]

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 5), count: 7)

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

    private var cells: [MusicHistoryCalendarCell] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: month.date) else { return [] }
        let leadingDays = (calendar.component(.weekday, from: month.date) - calendar.firstWeekday + 7) % 7
        let blanks = (0..<leadingDays).map {
            MusicHistoryCalendarCell(id: $0, dayNumber: nil, summary: nil)
        }
        let days = dayRange.map { dayNumber in
            MusicHistoryCalendarCell(
                id: leadingDays + dayNumber - 1,
                dayNumber: dayNumber,
                summary: month.daysByNumber[dayNumber]
            )
        }
        return blanks + days
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(month.date, format: .dateTime.month(.wide))
                    .font(.headline)
                Spacer()
                if month.playCount > 0 {
                    Text("\(month.playCount)回")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            LazyVGrid(columns: columns, spacing: 7) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(cells) { cell in
                    if let dayNumber = cell.dayNumber, let summary = cell.summary {
                        NavigationLink {
                            MusicHistoryDayView(day: summary, trackHistories: trackHistories)
                        } label: {
                            dayCell(dayNumber: dayNumber, playCount: summary.playCount)
                        }
                        .buttonStyle(.plain)
                    } else if let dayNumber = cell.dayNumber {
                        dayCell(dayNumber: dayNumber, playCount: 0)
                    } else {
                        Color.clear.aspectRatio(1, contentMode: .fit)
                    }
                }
            }
        }
        .padding(14)
        .background(.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
    }

    private func dayCell(dayNumber: Int, playCount: Int) -> some View {
        Text("\(dayNumber)")
            .font(.caption2.weight(playCount > 0 ? .bold : .regular).monospacedDigit())
            .foregroundStyle(playCount > 0 ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .aspectRatio(1, contentMode: .fit)
            .background(dayColor(playCount), in: RoundedRectangle(cornerRadius: 7))
            .accessibilityLabel("\(dayNumber)日、\(playCount)回再生")
    }

    private func dayColor(_ playCount: Int) -> Color {
        guard playCount > 0, maxDailyPlayCount > 0 else { return .secondary.opacity(0.08) }
        let ratio = Double(playCount) / Double(maxDailyPlayCount)
        switch ratio {
        case ..<0.26: return .accentColor.opacity(0.20)
        case ..<0.51: return .accentColor.opacity(0.38)
        case ..<0.76: return .accentColor.opacity(0.58)
        default: return .accentColor.opacity(0.82)
        }
    }
}

private struct MusicHistoryCalendarCell: Identifiable {
    let id: Int
    let dayNumber: Int?
    let summary: MusicHistoryDaySummary?
}

private struct MusicHistoryDayView: View {
    let day: MusicHistoryDaySummary
    let trackHistories: [Track.ID: MusicHistoryTrackSummary]

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.date, format: .dateTime.year().month().day().weekday(.wide))
                        .font(.title2.weight(.bold))
                    Text("\(day.playCount)回再生 ・ \(day.tracks.count)曲")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 16)

                LazyVStack(spacing: 0) {
                    ForEach(Array(day.tracks.enumerated()), id: \.element.id) { index, item in
                        if let history = trackHistories[item.track.id] {
                            NavigationLink {
                                TrackMusicHistoryView(summary: history)
                            } label: {
                                MusicHistoryTrackRow(rank: index + 1, item: item)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        } else {
                            MusicHistoryTrackRow(rank: index + 1, item: item)
                                .padding(.vertical, 8)
                        }
                        if item.id != day.tracks.last?.id {
                            Divider().padding(.leading, 90)
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("この日の音楽")
        .navigationBarTitleDisplayMode(.inline)
    }
}
