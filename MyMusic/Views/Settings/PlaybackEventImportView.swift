import SwiftUI
import UniformTypeIdentifiers

struct PlaybackEventImportView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlaybackHistoryStore.self) private var historyStore
    @State private var store = PlaybackEventImportStore()
    @State private var isChoosingFile = false

    var body: some View {
        List {
            Section {
                Button("再生イベントJSONを選択", systemImage: "doc.badge.plus") {
                    isChoosingFile = true
                }
                .disabled(store.isBusy || store.state == .preview)
            } footer: {
                Text("MyMusic-Playback-Events.jsonを全体検証し、内容を確認してからSQLiteへ保存します。")
            }

            if store.isBusy {
                Section {
                    HStack {
                        ProgressView()
                        Text(store.state == .applying ? "保存中…" : "検証中…")
                    }
                }
            }
            if let preview = store.preview { previewSection(preview) }
            if let result = store.result { resultSection(result) }
            if let error = store.errorMessage {
                Section("エラー") {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Button("閉じる") { store.reset() }
                }
            }
        }
        .themeScreen()
        .navigationTitle("再生イベントJSONを読み込む")
        .fileImporter(isPresented: $isChoosingFile, allowedContentTypes: [.json]) { result in
            importFile(result)
        }
    }

    private func previewSection(_ preview: PlaybackEventImportPreview) -> some View {
        Section {
            metricRows(
                total: preview.total,
                inserted: preview.pendingInsert,
                duplicate: preview.duplicate,
                unresolved: preview.unresolved,
                invalid: preview.invalid
            )
            if !preview.details.isEmpty {
                DisclosureGroup("明細（最大100件）") {
                    ForEach(preview.details) { detail in
                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(detail.title).font(.headline).lineLimit(1)
                                Spacer()
                                Text(detail.disposition.rawValue)
                                    .font(.caption.bold())
                                    .foregroundStyle(detail.disposition == .insert ? .green : .secondary)
                            }
                            Text(detail.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            Text("\(detail.playedAt.formatted(.iso8601)) ・ \(detail.platform.rawValue)")
                                .font(.caption).foregroundStyle(.secondary)
                            if let reason = detail.reason {
                                Text(reason).font(.caption).foregroundStyle(.orange)
                            }
                        }
                        .padding(.vertical, 3)
                    }
                }
            }
            Button("読み込む", systemImage: "square.and.arrow.down") {
                Task { await store.apply(to: historyStore) }
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isBusy)
            Button("キャンセル", role: .cancel) { store.cancel() }
                .disabled(store.isBusy)
        } header: {
            Text("読み込み前の確認")
        } footer: {
            Text("未解決trackIdと保存済みeventIdは保存しません。曲名・アーティスト・アルバムは確認表示専用で、Libraryを変更しません。")
        }
    }

    private func resultSection(_ result: PlaybackEventImportResult) -> some View {
        Section("読み込み結果") {
            metricRows(
                total: result.total,
                inserted: result.inserted,
                duplicate: result.duplicate,
                unresolved: result.unresolved,
                invalid: result.invalid
            )
            Button("閉じる") { store.reset() }
        }
    }

    private func metricRows(
        total: Int,
        inserted: Int,
        duplicate: Int,
        unresolved: Int,
        invalid: Int
    ) -> some View {
        Group {
            LabeledContent("全イベント", value: "\(total)件")
            LabeledContent("追加", value: "\(inserted)件")
            LabeledContent("重複eventId", value: "\(duplicate)件")
            LabeledContent("LibraryにないtrackId", value: "\(unresolved)件")
            LabeledContent("不正", value: "\(invalid)件")
        }
    }

    private func importFile(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            store.prepare(
                data: data,
                history: historyStore.entries,
                libraryTrackIDs: Set(libraryStore.unfilteredTracks.map(\.id))
            )
        } catch let error as CocoaError where error.code == .userCancelled { }
        catch {
            store.reportFileReadError(error)
        }
    }
}
