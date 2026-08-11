import SwiftUI
import UniformTypeIdentifiers

struct AnalyticsView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(PlaylistStore.self) private var playlistStore
    @State private var showsAllHistory = false
    @State private var showsAllMostPlayed = false

    private var snapshot: AnalyticsSnapshot {
        AnalyticsService().makeSnapshot(
            tracks: libraryStore.tracks,
            historyEntries: playbackHistoryStore.entries,
            playlists: playlistStore.playlists
        )
    }

    private var export: AnalyticsExport {
        AnalyticsExport(csv: AnalyticsService().csv(snapshot: snapshot, playlists: playlistStore.playlists))
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
        Section {
            if snapshot.playbackMonths.isEmpty {
                emptyMessage("再生履歴はありません。")
            } else {
                ForEach(showsAllHistory ? snapshot.playbackMonths : Array(snapshot.playbackMonths.prefix(10))) { month in
                    NavigationLink {
                        PlaybackMonthDetailView(month: month)
                    } label: {
                        LabeledContent(month.date.formatted(.dateTime.year().month(.wide)), value: "\(month.eventCount)件")
                    }
                }
            }
        } header: {
            expandableHeader("再生履歴", isExpanded: $showsAllHistory, count: snapshot.playbackMonths.count)
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

private struct PlaybackMonthDetailView: View {
    let month: AnalyticsSnapshot.MonthGroup

    var body: some View {
        List(month.days) { day in
            NavigationLink {
                PlaybackDayDetailView(day: day)
            } label: {
                LabeledContent(day.date.formatted(.dateTime.year().month().day()), value: "\(day.events.count)件")
            }
        }
        .navigationTitle(month.date.formatted(.dateTime.year().month(.wide)))
        .navigationBarTitleDisplayMode(.inline)
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
