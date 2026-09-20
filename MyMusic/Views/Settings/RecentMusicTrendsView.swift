import Charts
import SwiftUI

struct RecentMusicTrendsView: View {
    @Environment(PlaybackHistoryStore.self) private var historyStore
    @Environment(TrackFeatureStore.self) private var featureStore
    @State private var selectedPeriod: TrendPeriod = .month
    @State private var selectedFeature: TrendFeature?
    @State private var index: [TrendEvent] = []
    @State private var snapshot: TrendSnapshot?
    @State private var isLoading = true
    @State private var aggregationGeneration = 0

    private var dataRevision: String {
        "\(historyStore.homePresentationRevision)-\(featureStore.lastImportDate?.timeIntervalSince1970 ?? 0)-\(featureStore.storedFeatureCount)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                periodPicker
                if isLoading {
                    ProgressView("最近の音楽傾向をまとめています…")
                        .frame(maxWidth: .infinity, minHeight: 220)
                } else if let snapshot, !snapshot.points.values.contains(where: { $0.count >= 2 }) {
                    ContentUnavailableView(
                        "この期間はまだ十分な再生履歴がありません",
                        systemImage: "chart.xyaxis.line",
                        description: Text("もう少し音楽を聴くと、ここに最近の傾向が表示されます。特徴量を取り込んだ曲の再生が対象です。")
                    )
                    .frame(maxWidth: .infinity, minHeight: 240)
                } else if let snapshot {
                    featurePicker(snapshot)
                    if let selectedFeature {
                        featureContent(selectedFeature, snapshot: snapshot)
                    } else {
                        overview(snapshot)
                    }
                }
            }
            .padding(.vertical, 20)
        }
        .themeScreen()
        .navigationTitle("最近の音楽傾向")
        .navigationBarTitleDisplayMode(.inline)
        .task(id: dataRevision) { await loadIndex() }
        .onChange(of: selectedPeriod) { _, _ in Task { await refresh() } }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(selectedPeriod.context)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
            Text("聴く音楽は、どう変わってきた？")
                .font(.title2.weight(.bold))
            Text("再生した曲の特徴を時間に沿って見てみましょう。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
    }

    private var periodPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(TrendPeriod.allCases, id: \.self) { period in
                    Button(period.title) { selectedPeriod = period }
                        .font(.subheadline.weight(selectedPeriod == period ? .semibold : .regular))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(selectedPeriod == period ? Color.accentColor : Color.secondary.opacity(0.14),
                                    in: Capsule())
                        .foregroundStyle(selectedPeriod == period ? Color.white : Color.primary)
                        .accessibilityAddTraits(selectedPeriod == period ? [.isSelected] : [])
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }

    private func featurePicker(_ snapshot: TrendSnapshot) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                featureButton("総合", feature: nil)
                ForEach(snapshot.availableFeatures, id: \.self) { feature in
                    featureButton(feature.title, feature: feature)
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }

    private func featureButton(_ title: String, feature: TrendFeature?) -> some View {
        let isSelected = selectedFeature == feature
        return Button(title) { selectedFeature = feature }
            .font(.subheadline.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(isSelected ? Color.accentColor.opacity(0.20) : Color.secondary.opacity(0.10),
                        in: Capsule())
            .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
            .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    private func overview(_ snapshot: TrendSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("最近の変化")
                .font(.headline)
            if snapshot.changes.isEmpty {
                Text("まだはっきりした変化は見られません。もう少し聴くと、前半と後半の違いが分かりやすくなります。")
                    .foregroundStyle(.secondary)
            } else {
                Text(summaryText(for: snapshot.changes))
                    .font(.title3.weight(.medium))
                ForEach(snapshot.changes.prefix(3)) { change in
                    changeRow(change, showsValues: snapshot.period.showsComparison)
                }
                if snapshot.period.showsComparison {
                    Text("選んだ期間の前半と後半を比較しています。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 16)
    }

    private func featureContent(_ feature: TrendFeature, snapshot: TrendSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(feature.title)
                .font(.headline)
            if snapshot.hasChart(for: feature), let points = snapshot.points[feature] {
                Chart(points) { point in
                    LineMark(
                        x: .value("日時", point.date),
                        y: .value("特徴", point.value),
                        series: .value("区間", point.segment)
                    )
                    .foregroundStyle(Color.accentColor)
                    PointMark(x: .value("日時", point.date), y: .value("特徴", point.value))
                        .foregroundStyle(Color.accentColor)
                }
                .chartYScale(domain: 0...1)
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                        AxisGridLine()
                        AxisValueLabel(format: snapshot.period.rawValue >= TrendPeriod.threeDays.rawValue
                            ? .dateTime.month().day() : .dateTime.hour().minute())
                    }
                }
                .chartYAxis {
                    AxisMarks(values: [0, 0.5, 1]) { _ in
                        AxisGridLine()
                        AxisValueLabel()
                    }
                }
                .frame(height: 240)
                .accessibilityLabel("\(feature.title)の時間ごとの変化")
                Text("各点は時間帯ごとに聴いた曲の平均です。空白の時間帯は線をつないでいません。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if snapshot.period.showsComparison,
                   let change = snapshot.comparisons[feature] {
                    changeRow(change, showsValues: true)
                }
            } else {
                Text("この特徴を表示するには、もう少し再生履歴が必要です。")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 16)
    }

    private func changeRow(_ change: TrendChange, showsValues: Bool) -> some View {
        HStack {
            Text(change.feature.title)
            Spacer()
            if showsValues {
                Text("前半 \(Int((change.earlier * 100).rounded())) → 後半 \(Int((change.later * 100).rounded()))")
                    .foregroundStyle(.secondary)
            }
            Text(String(format: "%+.0fポイント", change.difference * 100))
                .fontWeight(.semibold)
                .foregroundStyle(change.difference >= 0 ? Color.accentColor : Color.secondary)
        }
        .font(.subheadline)
    }

    private func summaryText(for changes: [TrendChange]) -> String {
        let sentences = Array(changes.prefix(2)).map { change in
            "\(change.feature.title)を感じる曲が\(change.difference > 0 ? "増えています" : "少なくなっています")。"
        }
        return "最近は、以前より\(sentences.joined(separator: " "))"
    }

    private func loadIndex() async {
        isLoading = true
        await historyStore.loadIfNeeded()
        await featureStore.loadIfNeeded()
        let entries = historyStore.entries
        let features = Dictionary(uniqueKeysWithValues: featureStore.exportedFeatures.map { ($0.trackID, $0) })
        let now = Date()
        let built = await Task.detached(priority: .userInitiated) {
            RecentMusicTrendsService.makeIndex(historyEntries: entries, features: features, now: now)
        }.value
        guard !Task.isCancelled else { return }
        index = built
        await refresh()
    }

    private func refresh() async {
        let period = selectedPeriod
        let events = index
        aggregationGeneration &+= 1
        let generation = aggregationGeneration
        let result = await Task.detached(priority: .userInitiated) {
            RecentMusicTrendsService.summarize(events, period: period, now: Date())
        }.value
        guard selectedPeriod == period, aggregationGeneration == generation else { return }
        snapshot = result
        if let selectedFeature, !result.availableFeatures.contains(selectedFeature) {
            self.selectedFeature = nil
        }
        isLoading = false
    }
}
