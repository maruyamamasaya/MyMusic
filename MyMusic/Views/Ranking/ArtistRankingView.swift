import SwiftUI

struct ArtistRankingView: View {
    @Environment(LibraryStore.self) private var library
    @Environment(PlaybackHistoryStore.self) private var history
    @Environment(TrackPreferenceStore.self) private var preferences
    @State private var store = ArtistRankingStore()
    @State private var division = ArtistRankingDivision.instrumental
    @State private var metric = ArtistRankingMetric.score
    @State private var selected: ArtistRankingRow?
    @State private var showsSettings = false
    @ScaledMetric private var minimumCardWidth = 145

    private var input: ArtistRankingInput {
        ArtistRankingInput(tracks: library.unfilteredTracks, histories: history.entries,
                           preferences: preferences.entries, settings: store.settings)
    }
    private var rows: [ArtistRankingRow] { store.pages[division]?[metric] ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Picker("部門", selection: $division) {
                    ForEach(ArtistRankingDivision.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
                Picker("方式", selection: $metric) {
                    ForEach(ArtistRankingMetric.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
                Text("全期間・各部門100位まで。作業用BGMとハイレゾを除く通常曲が対象です。実聴時間は詳細履歴が残っている分を集計します。画面を開いたときと、下に引いて更新したときに集計します。")
                    .font(.caption).foregroundStyle(.secondary)
                DisclosureGroup("総合点の計算方法") {
                    Text("回数40％＋時間10％＋Good30％＋お気に入り20％。回数と時間はアーティストの全登録曲数の平方根（最低4曲）で割り、各項目の部門内最大値を100点に換算します。Goodは正の現在評価値の合計、お気に入りは曲数です。単純な回数・時間の順位には補正しません。総合1位が必ず100点になるわけではありません。")
                        .font(.callout).foregroundStyle(.secondary).padding(.top, 8)
                }
                if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
                if store.isComputing {
                    ProgressView("ランキングを集計中…").frame(maxWidth: .infinity)
                } else if rows.isEmpty {
                    ContentUnavailableView {
                        Label("対象のデータがありません", systemImage: "chart.bar")
                    } description: {
                        Text("部門設定でジャンルを選んでください。選択済みの場合は再生履歴や評価が必要です。")
                    } actions: {
                        Button("部門設定") { showsSettings = true }
                    }
                } else {
                    Text("上位\(rows.count)組").font(.subheadline).foregroundStyle(.secondary)
                    if let champion = rows.first { card(champion, rank: 1, compact: false) }
                    grid(Array(rows.dropFirst().prefix(9)), startingAt: 2, compact: false)
                    if rows.count > 10 {
                        Text("11〜\(rows.count)位").font(.headline).padding(.top, 8)
                        grid(Array(rows.dropFirst(10)), startingAt: 11, compact: true)
                    }
                }
            }.padding(16)
        }
        .themeScreen()
        .navigationTitle("ランキング")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("部門設定", systemImage: "slider.horizontal.3") { showsSettings = true }
            }
        }
        .task { await store.refresh(input) }
        .refreshable { await store.refresh(input) }
        .sheet(isPresented: $showsSettings) {
            ArtistRankingSettingsView(store: store, tracks: library.unfilteredTracks)
        }
        .sheet(item: $selected) { row in
            ArtistRankingDetailView(row: row, division: division, metric: metric)
        }
    }

    private func grid(_ entries: [ArtistRankingRow], startingAt: Int, compact: Bool) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: minimumCardWidth), alignment: .top)], spacing: 12) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, row in
                card(row, rank: startingAt + index, compact: compact)
            }
        }
    }

    private func card(_ row: ArtistRankingRow, rank: Int, compact: Bool) -> some View {
        Button { selected = row } label: {
            VStack(alignment: .leading, spacing: compact ? 8 : 12) {
                HStack {
                    if rank == 1 { Image(systemName: "crown.fill").font(.title).foregroundStyle(.orange) }
                    Text("\(rank)").font(rank == 1 ? .largeTitle.bold() : .title2.bold()).monospacedDigit()
                        .foregroundStyle(rankColor(rank))
                    Spacer(minLength: 4)
                    AlbumArtworkView(artworkIdentifier: row.artworkIdentifier)
                        .frame(width: rank == 1 ? 76 : (compact ? 36 : 52))
                }
                Text(row.title).font(rank == 1 ? .title2.bold() : (compact ? .callout.bold() : .headline))
                    .lineLimit(compact ? 1 : 2, reservesSpace: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(ArtistRankingFormatting.value(row, metric: metric))
                    .font(compact ? .callout.bold() : .title3.bold()).monospacedDigit()
                ProgressView(value: row.value(for: metric),
                             total: max(1, metric == .score ? 100 : (rows.first?.value(for: metric) ?? 1)))
                    .tint(rankColor(rank)).accessibilityHidden(true)
                if !compact {
                    Text("全\(row.totalTrackCount)曲・部門内\(row.trackIDs.count)曲")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(compact ? 12 : 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(.background, in: RoundedRectangle(cornerRadius: 16))
            .background {
                RoundedRectangle(cornerRadius: 16).fill(rankColor(rank).opacity(0.1))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: [rankColor(rank).opacity(rank == 1 ? 0.25 : 0.13), .clear],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .allowsHitTesting(false)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 16).strokeBorder(rankColor(rank).opacity(0.5), lineWidth: 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(rank)位、\(row.title)、\(metric.title)、\(ArtistRankingFormatting.value(row, metric: metric))")
        .accessibilityHint("点数の内訳とこの部門の曲を表示")
    }

    private func rankColor(_ rank: Int) -> Color {
        switch rank {
        case 1: .orange
        case 2: .cyan
        case 3: .brown
        case 4...10: .purple
        default: .blue
        }
    }
}

enum ArtistRankingFormatting {
    static func duration(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds >= 0 else { return "0分" }
        return "\((seconds / 3600).formatted(.number.precision(.fractionLength(1))))時間"
    }

    static func value(_ row: ArtistRankingRow, metric: ArtistRankingMetric) -> String {
        switch metric {
        case .score: "\(row.score.formatted(.number.precision(.fractionLength(1)))) / 100点"
        case .count: "\(row.playCount)回"
        case .time: duration(row.seconds)
        }
    }
}
