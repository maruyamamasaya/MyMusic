import SwiftUI

struct TrackFeatureDetailView: View {
    @Environment(TrackFeatureStore.self) private var featureStore
    let track: Track

    var body: some View {
        Group {
            if let feature = featureStore.feature(for: track.id) {
                featureList(feature)
            } else {
                ContentUnavailableView("特徴量がありません", systemImage: "waveform.slash")
            }
        }
        .navigationTitle("音楽特徴")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func featureList(_ feature: TrackFeature) -> some View {
        let categories = TrackFeaturePresentation.categoryItems(for: feature.values)
        let additional = (feature.values.additional ?? [:])
            .filter { $0.value.isFinite && (0...1).contains($0.value) }
            .sorted { $0.key < $1.key }

        return List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    Text(track.title).font(.headline)
                    Text(track.artistName).foregroundStyle(.secondary)
                }
            } footer: {
                Text("Macの解析によるBetaスコアです。分類の確率や正確さを保証する値ではありません。選曲や再生動作には使用しません。")
            }

            if !categories.isEmpty {
                Section("分類スコア") {
                    ForEach(categories) { item in
                        scoreRow(item.label, score: item.score)
                    }
                }
            }

            Section("音響特徴") {
                if let energy = feature.values.energy, energy.isFinite, (0...1).contains(energy) {
                    scoreRow("Energy", score: energy)
                }
                if let tempo = feature.values.tempo, tempo.isFinite, tempo > 0 {
                    LabeledContent("Tempo") {
                        Text("\(tempo, format: .number.precision(.fractionLength(0...1))) BPM")
                            .monospacedDigit()
                    }
                }
            }

            if !additional.isEmpty {
                Section("追加特徴量") {
                    ForEach(additional, id: \.key) { item in
                        scoreRow(item.key, score: item.value)
                    }
                }
            }

            Section("Beta Debug情報") {
                LabeledContent("analysisVersion", value: "v\(feature.analysisVersion)")
                VStack(alignment: .leading, spacing: 5) {
                    Text("relativePath").foregroundStyle(.secondary)
                    Text(feature.sourceIdentity.relativePath)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
                .accessibilityElement(children: .combine)
                LabeledContent("fileSize") {
                    Text("\(feature.sourceIdentity.fileSize.formatted()) bytes")
                        .monospacedDigit()
                }
                LabeledContent("duration") {
                    Text("\(feature.sourceIdentity.duration, format: .number.precision(.fractionLength(2))) 秒")
                        .monospacedDigit()
                }
                LabeledContent("contentHash", value: feature.sourceIdentity.contentHash == nil ? "なし" : "あり")
                LabeledContent("解析日時") {
                    Text(feature.analyzedAt, format: .dateTime.year().month().day().hour().minute())
                }
                LabeledContent("Import日時") {
                    Text(feature.importedAt, format: .dateTime.year().month().day().hour().minute())
                }
            }
        }
    }

    private func scoreRow(_ label: String, score: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(label)
                Spacer()
                Text(score, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: score)
                .accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }
}
