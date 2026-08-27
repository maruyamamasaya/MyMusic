import SwiftUI
import UniformTypeIdentifiers

struct TrackFeatureSettingsView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(TrackFeatureStore.self) private var featureStore
    @State private var isImporting = false
    @State private var isConfirmingDeletion = false
    @State private var importResult: TrackFeatureImportResult?
    @State private var errorMessage: String?

    var body: some View {
        let statistics = featureStore.statistics(for: libraryStore.unfilteredTracks)

        List {
            Section {
                LabeledContent("登録曲数", value: statistics.registeredTrackCount.formatted())
                LabeledContent("特徴量あり", value: statistics.tracksWithFeatures.formatted())
                LabeledContent("未解析 / 未紐付け", value: statistics.tracksWithoutFeatures.formatted())
                LabeledContent("analysisVersion", value: analysisVersionText)
                LabeledContent("最終Import") {
                    if let date = featureStore.lastImportDate {
                        Text(date, format: .dateTime.year().month().day().hour().minute())
                    } else {
                        Text("未実行").foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("状況")
            } footer: {
                Text("Macで生成したJSONを読み込みます。iPhone上で音響解析や全曲ハッシュ計算は行いません。")
            }

            Section("Import") {
                Button("特徴量JSONを読み込む", systemImage: "square.and.arrow.down") {
                    isImporting = true
                }
                .disabled(featureStore.isProcessing)

                if featureStore.isProcessing {
                    HStack {
                        ProgressView()
                        Text("処理中…")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let report = featureStore.lastImportReport {
                Section {
                    LabeledContent("ImportしたVersion", value: "v\(report.analysisVersion)")
                    LabeledContent("合計", value: report.totalCount.formatted())
                    LabeledContent("照合成功", value: report.matchedCount.formatted())
                    LabeledContent("未照合", value: report.unmatchedCount.formatted())
                    LabeledContent("曖昧", value: report.ambiguousCount.formatted())
                    LabeledContent("新規", value: report.insertedCount.formatted())
                    LabeledContent("更新", value: report.updatedCount.formatted())
                    LabeledContent("Skipped", value: report.skippedOlderAnalysisCount.formatted())

                    if report.unmatchedCount > 0 || report.ambiguousCount > 0 {
                        NavigationLink("未照合・曖昧の例を確認") {
                            TrackFeatureImportIssuesView(report: report)
                        }
                    }
                } header: {
                    Text("直近Import結果")
                } footer: {
                    Text("照合成功には旧Versionのため未更新の曲も含みます。Skippedは旧analysisVersionによる未更新件数です。")
                }
            }

            if let message = featureStore.errorMessage {
                Section("読み込みエラー") {
                    Text(message).foregroundStyle(.secondary)
                }
            }

            Section {
                Button("特徴量データを削除", systemImage: "trash", role: .destructive) {
                    isConfirmingDeletion = true
                }
                .disabled(
                    featureStore.isProcessing ||
                    (featureStore.storedFeatureCount == 0 && featureStore.lastImportReport == nil)
                )
            } footer: {
                Text("曲、プレイリスト、再生履歴、評価、お気に入り、再生設定には影響しません。")
            }
        }
        .navigationTitle("音楽特徴量")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.json]) { result in
            importFile(result)
        }
        .alert("Import結果", isPresented: Binding(
            get: { importResult != nil },
            set: { if !$0 { importResult = nil } }
        )) {
            Button("閉じる") { importResult = nil }
        } message: {
            Text(importResultMessage)
        }
        .alert("特徴量データを削除しますか？", isPresented: $isConfirmingDeletion) {
            Button("削除", role: .destructive) { deleteFeatures() }
            Button("キャンセル", role: .cancel) { }
        } message: {
            Text("特徴量だけを削除します。この操作は取り消せません。")
        }
        .alert("特徴量エラー", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("閉じる") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var analysisVersionText: String {
        let versions = featureStore.analysisVersions
        guard !versions.isEmpty else { return "未登録" }
        return versions.map { "v\($0)" }.joined(separator: ", ")
    }

    private var importResultMessage: String {
        guard let result = importResult else { return "" }
        var lines = [
            "analysisVersion\nv\(result.analysisVersion)",
            "合計\n\(result.totalCount.formatted())件",
            "照合成功\n\(result.matchedCount.formatted())",
            "未照合\n\(result.unmatchedCount.formatted())",
            "曖昧\n\(result.ambiguousCount.formatted())",
            "新規保存 \(result.insertedCount.formatted()) / 更新 \(result.updatedCount.formatted())"
        ]
        if result.skippedOlderAnalysisCount > 0 {
            lines.append("旧analysisVersionのため未更新 \(result.skippedOlderAnalysisCount.formatted())")
        }
        return lines.joined(separator: "\n\n")
    }

    private func importFile(_ result: Result<URL, Error>) {
        Task {
            do {
                let url = try result.get()
                let data = try await Task.detached(priority: .userInitiated) {
                    let accessing = url.startAccessingSecurityScopedResource()
                    defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                    return try Data(contentsOf: url)
                }.value
                importResult = try await featureStore.import(
                    data: data,
                    libraryTracks: libraryStore.unfilteredTracks
                )
            } catch let error as CocoaError where error.code == .userCancelled { }
            catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func deleteFeatures() {
        Task {
            do {
                try await featureStore.deleteAll()
            } catch {
                errorMessage = "特徴量データを削除できませんでした: \(error.localizedDescription)"
            }
        }
    }
}

private struct TrackFeatureImportIssuesView: View {
    let report: TrackFeatureImportReport

    var body: some View {
        List {
            issueSection(
                title: "未照合",
                count: report.unmatchedCount,
                paths: report.unmatchedSamplePaths
            )
            issueSection(
                title: "曖昧",
                count: report.ambiguousCount,
                paths: report.ambiguousSamplePaths
            )
        }
        .navigationTitle("照合できなかった曲")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func issueSection(title: String, count: Int, paths: [String]) -> some View {
        Section {
            if paths.isEmpty {
                Text("該当なし")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(paths.enumerated()), id: \.offset) { _, path in
                    Text(path)
                        .font(.caption.monospaced())
                        .textSelection(.enabled)
                }
            }
        } header: {
            Text("\(title) \(count.formatted())件")
        } footer: {
            if count > paths.count {
                Text("先頭\(paths.count.formatted())件を表示しています。")
            }
        }
    }
}
