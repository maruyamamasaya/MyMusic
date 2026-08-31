import SwiftUI

struct TrackMusicHistoryView: View {
    let summary: MusicHistoryTrackSummary

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                hero
                facts
                timeline
            }
            .padding(.vertical, 16)
        }
        .navigationTitle("曲の自分史")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var hero: some View {
        VStack(spacing: 10) {
            AlbumArtworkView(artworkIdentifier: summary.track.artworkIdentifier)
                .frame(maxWidth: 290)
                .shadow(color: .black.opacity(0.14), radius: 16, y: 8)

            Text(summary.track.title)
                .font(.title2.weight(.bold))
                .multilineTextAlignment(.center)
                .lineLimit(3)
            Text(summary.track.artistName)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text("あなたとこの曲")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(.tint.opacity(0.12), in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .accessibilityElement(children: .combine)
    }

    private var facts: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
            spacing: 12
        ) {
            TrackHistoryFactView(
                title: "初めて聴いた日",
                value: summary.firstPlayedAt.formatted(.dateTime.year().month().day())
            )
            TrackHistoryFactView(
                title: "最後に聴いた日",
                value: summary.lastPlayedAt.formatted(.dateTime.year().month().day())
            )
            TrackHistoryFactView(
                title: "一番聴いた月",
                value: summary.mostPlayedMonth.date.formatted(.dateTime.year().month(.wide))
            )
            TrackHistoryFactView(
                title: "累計",
                value: "\(summary.totalPlayCount)回"
            )
            TrackHistoryFactView(
                title: "手動再生",
                value: "\(summary.manualPlayCount)回"
            )
            TrackHistoryFactView(
                title: "自動再生",
                value: "\(summary.automaticPlayCount)回"
            )
            TrackHistoryFactView(
                title: "直近7日",
                value: "\(summary.playsLast7Days)回"
            )
            TrackHistoryFactView(
                title: "直近30日",
                value: "\(summary.playsLast30Days)回"
            )
            TrackHistoryFactView(
                title: "再生入口",
                value: summary.sourceCountsDisplay
            )
        }
        .padding(.horizontal, 16)
    }

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 14) {
            MusicHistorySectionHeader(
                title: "月ごとの記憶",
                subtitle: "この曲を聴いてきた時間"
            )

            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(Array(summary.months.enumerated()), id: \.element.id) { index, month in
                    TrackHistoryTimelineRow(
                        month: month,
                        isFirst: index == 0,
                        isMostPlayed: month.id == summary.mostPlayedMonth.id,
                        showsConnector: index < summary.months.count - 1
                    )
                }
            }
            .padding(.horizontal, 20)

            Text("累計 \(summary.totalPlayCount)回")
                .font(.title3.weight(.bold).monospacedDigit())
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
        }
    }
}

private extension MusicHistoryTrackSummary {
    var sourceCountsDisplay: String {
        let parsedItems: [(key: PlaybackStartSource, count: Int)] = sourceCounts.compactMap { entry in
            let key = PlaybackStartSource(rawValue: entry.key)
            if let source = key {
                return (key: source, count: entry.value)
            }
            return nil
        }
        let ranked = parsedItems.sorted {
            if $0.count == $1.count {
                return $0.key.rawValue < $1.key.rawValue
            }
            return $0.count > $1.count
        }
        guard !ranked.isEmpty else { return "記録なし" }
        return ranked
            .prefix(2)
            .map { source in
                "\(sourceKeyLabel(source.key)): \(source.count)回"
            }
            .joined(separator: " / ")
    }

    private func sourceKeyLabel(_ source: PlaybackStartSource) -> String {
        switch source {
        case .album: return "アルバム"
        case .artist: return "アーティスト"
        case .favorite: return "お気に入り"
        case .history: return "音楽史"
        case .home: return "ホーム"
        case .library: return "ライブラリ"
        case .playlist: return "プレイリスト"
        case .queue: return "キュー"
        case .repeatPlayback: return "リピート"
        case .search: return "検索"
        case .shuffle: return "シャッフル"
        case .station: return "ステーション"
        case .highlight: return "ハイライト"
        case .workLibrary: return "Work"
        case .unknown: return "不明"
        }
    }
}

private struct TrackHistoryFactView: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(value)
                .font(.headline)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .padding(12)
        .background(.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

private struct TrackHistoryTimelineRow: View {
    let month: MusicHistoryTrackMonthSummary
    let isFirst: Bool
    let isMostPlayed: Bool
    let showsConnector: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(spacing: 0) {
                Circle()
                    .fill(isMostPlayed ? Color.accentColor : Color.secondary.opacity(0.45))
                    .frame(width: isMostPlayed ? 13 : 10, height: isMostPlayed ? 13 : 10)
                    .padding(.top, 5)
                if showsConnector {
                    Rectangle()
                        .fill(.secondary.opacity(0.22))
                        .frame(width: 2, height: 74)
                }
            }
            .frame(width: 16)

            VStack(alignment: .leading, spacing: 5) {
                Text(month.date, format: .dateTime.year().month(.wide))
                    .font(.headline)
                Text("\(month.playCount)回")
                    .font(.title3.weight(.semibold).monospacedDigit())
                if isFirst {
                    Text("この月に初めて聴きました")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if isMostPlayed {
                    Label("一番聴いていた時期", systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.tint)
                }
            }
            .padding(.bottom, showsConnector ? 14 : 0)

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }
}
