import SwiftUI

struct ArtistRankingView: View {
    var weekly = false
    @State private var weekOffset = 0
    @State private var visibleWeeklyCount = 20
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
                           preferences: preferences.entries, settings: store.settings,
                           week: weekly ? ArtistRankingService.week(containing: Date(), offset: weekOffset) : nil)
    }
    private var rows: [ArtistRankingRow] { store.pages[weekly ? .instrumental : division]?[metric] ?? [] }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if weekly {
                    Picker("週", selection: $weekOffset) {
                        Text("今週").tag(0)
                        Text("先週").tag(-1)
                        Text("先々週").tag(-2)
                    }.pickerStyle(.segmented)
                    if let week = store.week {
                        Text(ArtistRankingFormatting.weekPeriod(week))
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                } else {
                Picker("部門", selection: $division) {
                    ForEach(ArtistRankingDivision.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
                }
                Picker("方式", selection: $metric) {
                    ForEach(ArtistRankingMetric.allCases, id: \.self) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
                DisclosureGroup("総合点の計算方法") {
                    VStack(alignment: .leading, spacing: 12) {
                        if weekly {
                            Text("月曜〜日曜・全部門合算の上位100組（Beta）。今週は途中経過です。再生開始日で詳細履歴を集計し、回数は通常再生と同じ30秒または曲の半分の到達を基準にします。詳細履歴のない分と再生中の未確定分は含みません。Good・お気に入りは計算に含めません。画面を開いたときと、下に引いて更新したときに集計します。")
                            Text("前週比：↑上昇・↓下降・→同順位・NEWは前週100位圏外または対象データなし。今週の途中経過と前週全体を比較します。")
                        } else {
                            Text("全期間・各部門100位まで。作業用BGMとハイレゾを除く通常曲が対象です。実聴時間は詳細履歴が残っている分を集計します。画面を開いたときと、下に引いて更新したときに集計します。")
                        }
                        Text(weekly ? "再生回数50％＋実聴時間30％＋聴いた日数20％。回数と時間はアーティストの全登録曲数の平方根（最低4曲）で割り、回数・時間の週内最大値を100点に換算します。日数は回数の計上基準を満たした日を1日1回で数え、1〜7日で段階的に加点し、7日で20点満点です。単純な回数・時間の順位には補正しません。総合1位が必ず100点になるわけではありません。" : "回数40％＋時間10％＋Good30％＋お気に入り20％。回数と時間はアーティストの全登録曲数の平方根（最低4曲）で割り、各項目の対象内最大値を100点に換算します。Goodは正の現在評価値の合計、お気に入りは曲数です。単純な回数・時間の順位には補正しません。総合1位が必ず100点になるわけではありません。")
                    }
                    .font(.callout).foregroundStyle(.secondary).padding(.top, 8)
                }
                if let error = store.errorMessage { Text(error).foregroundStyle(.red) }
                if store.isComputing {
                    ProgressView("ランキングを集計中…").frame(maxWidth: .infinity)
                } else if rows.isEmpty {
                    ContentUnavailableView {
                        Label("対象のデータがありません", systemImage: "chart.bar")
                    } description: {
                        Text(weekly ? "対象の週の再生履歴が必要です。" : "部門設定でジャンルを選んでください。選択済みの場合は再生履歴や評価が必要です。")
                    } actions: {
                        if !weekly { Button("部門設定") { showsSettings = true } }
                    }
                } else {
                    Text("上位\(rows.count)組").font(.subheadline).foregroundStyle(.secondary)
                    if weekly {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(rows.prefix(visibleWeeklyCount).enumerated()), id: \.element.id) { index, row in
                                WeeklyArtistRankingRowView(row: row, rank: index + 1, metric: metric,
                                    movement: store.movements[metric]?[row.id]) { selected = row }
                                    .padding(.bottom, index == 0 ? 16 : (index == 1 ? 14 : (index == 2 ? 12 : 10)))
                            }
                        }
                        if visibleWeeklyCount < rows.count {
                            Button("さらに\(min(20, rows.count - visibleWeeklyCount))組を表示") {
                                visibleWeeklyCount += 20
                            }
                            .buttonStyle(.bordered)
                            .frame(maxWidth: .infinity)
                        }
                    } else {
                    if let champion = rows.first { card(champion, rank: 1, compact: false) }
                    grid(Array(rows.dropFirst().prefix(9)), startingAt: 2, compact: false)
                    if rows.count > 10 {
                        Text("11〜\(rows.count)位").font(.headline).padding(.top, 8)
                        grid(Array(rows.dropFirst(10)), startingAt: 11, compact: true)
                    }
                    }
                }
            }.padding(16)
        }
        .themeScreen()
        .navigationTitle(weekly ? "Weekly" : "ランキング")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !weekly {
            ToolbarItem(placement: .topBarTrailing) {
                Button("部門設定", systemImage: "slider.horizontal.3") { showsSettings = true }
            }
            }
        }
        .onChange(of: metric) { visibleWeeklyCount = 20 }
        .task(id: weekOffset) {
            visibleWeeklyCount = 20
            await store.refresh(input)
        }
        .refreshable {
            visibleWeeklyCount = 20
            await store.refresh(input)
        }
        .sheet(isPresented: $showsSettings) {
            ArtistRankingSettingsView(store: store, tracks: library.unfilteredTracks)
        }
        .sheet(item: $selected) { row in
            ArtistRankingDetailView(row: row, division: weekly ? nil : division, metric: metric)
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
                if weekly, let movement = store.movements[metric]?[row.id] {
                    Text(movement.title)
                        .font(.caption.bold()).monospacedDigit()
                        .foregroundStyle(movementColor(movement))
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
                    Text("全\(row.totalTrackCount)曲・対象\(row.trackIDs.count)曲")
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
        .accessibilityValue(weekly ? (store.movements[metric]?[row.id]?.accessibilityDescription ?? "") : "")
        .accessibilityHint("点数の内訳とこの部門の曲を表示")
    }

    private func movementColor(_ movement: ArtistRankingMovement) -> Color {
        switch movement {
        case .newEntry: .orange
        case .change(let places) where places > 0: .green
        case .change(let places) where places < 0: .red
        case .change: .secondary
        }
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
    private static let japaneseDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy年M月d日（E）"
        return formatter
    }()

    static func weekPeriod(_ week: DateInterval) -> String {
        "\(japaneseDateFormatter.string(from: week.start))〜\(japaneseDateFormatter.string(from: week.end.addingTimeInterval(-1)))"
    }

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
