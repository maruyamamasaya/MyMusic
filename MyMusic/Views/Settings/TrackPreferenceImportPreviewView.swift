import SwiftUI

struct TrackPreferenceImportPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let preview: TrackPreferenceImportPreview
    let apply: () async throws -> Void
    @State private var showsUnchanged = false
    @State private var isApplying = false
    @State private var errorMessage: String?

    private var visibleRows: [TrackPreferenceImportPreview.Row] {
        preview.rows.filter { showsUnchanged || !$0.isMatched || $0.isChanged }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("更新予定", value: "\(preview.changedCount)曲")
                    LabeledContent("変更なし", value: "\(preview.unchangedCount)曲")
                    LabeledContent("Libraryにない曲", value: "\(preview.missingCount)曲")
                    Toggle("変更なしも表示", isOn: $showsUnchanged)
                } footer: {
                    Text("評価とハートだけを受信内容へ更新します。Libraryにない曲は適用せず、JSONにない曲は変更しません。")
                }
                Section("現在 → 読み込み後") {
                    ForEach(visibleRows) { row in
                        VStack(alignment: .leading, spacing: 5) {
                            Text(row.title).font(.headline)
                            Text(row.artist).font(.caption).foregroundStyle(.secondary)
                            Text(row.id.uuidString).font(.caption2.monospaced()).foregroundStyle(.secondary)
                            if let current = row.current {
                                Text("評価: \(current.playbackPreference) → \(row.incoming.playbackPreference)")
                                Label("ハート: \(current.favorite ? "ON" : "OFF") → \(row.incoming.favorite ? "ON" : "OFF")",
                                      systemImage: row.incoming.favorite ? "heart.fill" : "heart")
                                if !row.isChanged { Text("変更なし").font(.caption).foregroundStyle(.secondary) }
                            } else {
                                Text("未照合・適用しません").foregroundStyle(.orange)
                                Text("受信: 評価 \(row.incoming.playbackPreference)、ハート \(row.incoming.favorite ? "ON" : "OFF")")
                            }
                        }.padding(.vertical, 3)
                    }
                }
                if let errorMessage {
                    Section("読み込めませんでした") { Text(errorMessage).foregroundStyle(.red) }
                }
                Section {
                    Button {
                        isApplying = true
                        Task { @MainActor in
                            defer { isApplying = false }
                            do { try await apply(); dismiss() }
                            catch { errorMessage = error.localizedDescription }
                        }
                    } label: {
                        if isApplying { ProgressView() } else { Text("確認して読み込む") }
                    }
                    .disabled(isApplying || errorMessage != nil)
                }
            }
            .navigationTitle("再生傾向の差分確認")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }.disabled(isApplying)
                }
            }
            .interactiveDismissDisabled(isApplying)
        }
    }
}
