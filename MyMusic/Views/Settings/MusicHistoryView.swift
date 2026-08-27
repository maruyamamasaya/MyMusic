import SwiftUI

struct MusicHistoryView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @State private var selectedYear: Int?

    private var snapshot: MusicHistorySnapshot {
        let analytics = AnalyticsService().makeSnapshot(
            tracks: libraryStore.unfilteredTracks,
            historyEntries: playbackHistoryStore.entries,
            playlists: []
        )
        return MusicHistoryService().makeSnapshot(playbackMonths: analytics.playbackMonths)
    }

    private var displayedYear: MusicHistorySnapshot.Year? {
        snapshot.years.first { $0.year == selectedYear } ?? snapshot.years.first
    }

    private var availableYears: [Int] {
        snapshot.years.map(\.year)
    }

    var body: some View {
        List {
            if snapshot.years.isEmpty {
                ContentUnavailableView(
                    "再生履歴はありません",
                    systemImage: "calendar.badge.clock",
                    description: Text("再生が完了した曲の履歴が保存されると、年月ごとに振り返れます。")
                )
            } else if let displayedYear {
                Section("年") {
                    Picker("表示する年", selection: yearSelection) {
                        ForEach(snapshot.years) { year in
                            Text("\(year.year)年").tag(year.year)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("\(displayedYear.year)年") {
                    ForEach(displayedYear.months) { month in
                        NavigationLink {
                            MusicHistoryMonthView(month: month)
                        } label: {
                            monthRow(month)
                        }
                    }
                }
            }
        }
        .navigationTitle("音楽史")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: normalizeSelectedYear)
        .onChange(of: availableYears) { _, _ in normalizeSelectedYear() }
    }

    private var yearSelection: Binding<Int> {
        Binding(
            get: { selectedYear ?? snapshot.years.first?.year ?? Calendar.current.component(.year, from: Date()) },
            set: { selectedYear = $0 }
        )
    }

    private func normalizeSelectedYear() {
        guard !availableYears.isEmpty else {
            selectedYear = nil
            return
        }
        if selectedYear.map(availableYears.contains) != true {
            selectedYear = availableYears.first
        }
    }

    private func monthRow(_ month: MusicHistorySnapshot.Month) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(month.date, format: .dateTime.month(.wide))
                .font(.headline)

            Text("再生 \(month.playCount)回 ・ \(month.trackCount)曲")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            if let topTrack = month.mostPlayedTrack {
                Text("最も再生した曲: \(topTrack.track.title)（\(topTrack.playCount)回）")
                    .font(.subheadline)
                    .lineLimit(1)
                Text(topTrack.track.artistName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct MusicHistoryMonthView: View {
    let month: MusicHistorySnapshot.Month

    var body: some View {
        List {
            Section("概要") {
                LabeledContent("再生回数", value: "\(month.playCount)回")
                LabeledContent("聴いた曲数", value: "\(month.trackCount)曲")
                LabeledContent("聴いたアーティスト数", value: "\(month.artistCount)組")
            }

            Section("よく聴いた曲 TOP10") {
                ForEach(Array(month.topTracks.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        rank(index + 1)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.track.title).lineLimit(1)
                            Text(item.track.artistName)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                        playCount(item.playCount)
                    }
                }
            }

            Section("よく聴いたアーティスト TOP10") {
                ForEach(Array(month.topArtists.enumerated()), id: \.element.id) { index, item in
                    HStack(spacing: 12) {
                        rank(index + 1)
                        Text(item.name).lineLimit(1)
                        Spacer()
                        playCount(item.playCount)
                    }
                }
            }
        }
        .navigationTitle(month.date.formatted(.dateTime.year().month(.wide)))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func rank(_ value: Int) -> some View {
        Text("\(value)")
            .font(.subheadline.monospacedDigit())
            .foregroundStyle(.secondary)
            .frame(width: 22, alignment: .trailing)
    }

    private func playCount(_ value: Int) -> some View {
        Text("\(value)回")
            .foregroundStyle(.secondary)
            .monospacedDigit()
    }
}
