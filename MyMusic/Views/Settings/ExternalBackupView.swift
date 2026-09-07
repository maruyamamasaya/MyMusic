import SwiftUI
import UniformTypeIdentifiers

struct ExternalBackupView: View {
    @Environment(PlaybackHistoryStore.self) private var historyStore
    @Environment(TrackPreferenceStore.self) private var preferenceStore
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(FavoriteStore.self) private var favoriteStore
    @State private var status = ExternalBackupStatus(destinationName: nil, lastBackupDate: nil, hasRestorableBackup: false)
    @State private var isChoosingDestination = false
    @State private var isChoosingRestore = false
    @State private var isWorking = false
    @State private var pendingRestoreURL: URL?
    @State private var resultMessage: String?
    @State private var errorMessage: String?

    private let service = ExternalBackupService()

    var body: some View {
        List {
            Section("保存先") {
                LabeledContent("フォルダ", value: status.destinationName ?? "未選択")
                Button("バックアップ保存先を選択", systemImage: "folder.badge.plus") {
                    isChoosingDestination = true
                }
            }

            Section("状態") {
                LabeledContent("最終バックアップ") {
                    Text(status.lastBackupDate?.formatted(date: .abbreviated, time: .shortened) ?? "なし")
                }
                LabeledContent("復元可能な世代", value: status.hasRestorableBackup ? "あり" : "なし")
            }

            Section {
                Button("今すぐバックアップ", systemImage: "externaldrive.badge.check") { createBackup() }
                    .disabled(status.destinationName == nil || isWorking)
                Button("バックアップから復元", systemImage: "arrow.counterclockwise") {
                    isChoosingRestore = true
                }
                .disabled(isWorking)
            } footer: {
                Text("音源は含みません。復元後はアプリを再起動し、音楽フォルダを再選択してください。")
            }

            if isWorking {
                Section { ProgressView("処理中…") }
            }
        }
        .navigationTitle("App外バックアップ")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { refreshStatus() }
        .fileImporter(isPresented: $isChoosingDestination, allowedContentTypes: [.folder]) { result in
            do {
                let url = try result.get()
                try service.saveDestination(url)
                refreshStatus()
            } catch let error as CocoaError where error.code == .userCancelled { }
            catch { errorMessage = error.localizedDescription }
        }
        .fileImporter(isPresented: $isChoosingRestore, allowedContentTypes: [.folder]) { result in
            do { pendingRestoreURL = try result.get() }
            catch let error as CocoaError where error.code == .userCancelled { }
            catch { errorMessage = error.localizedDescription }
        }
        .confirmationDialog(
            "現在のMyMusicデータをバックアップの内容へ置き換えます。続けますか？",
            isPresented: Binding(get: { pendingRestoreURL != nil }, set: { if !$0 { pendingRestoreURL = nil } }),
            titleVisibility: .visible
        ) {
            Button("復元する", role: .destructive) { restoreBackup() }
            Button("キャンセル", role: .cancel) { pendingRestoreURL = nil }
        }
        .alert("完了", isPresented: Binding(get: { resultMessage != nil }, set: { if !$0 { resultMessage = nil } })) {
            Button("閉じる") { resultMessage = nil }
        } message: { Text(resultMessage ?? "") }
        .alert("バックアップエラー", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("閉じる") { errorMessage = nil }
        } message: { Text(errorMessage ?? "") }
    }

    private func refreshStatus() { status = service.status() }

    private func createBackup() {
        isWorking = true
        Task {
            await historyStore.waitForPendingSave()
            await preferenceStore.waitForPendingSave()
            await playlistStore.waitForPendingSave()
            await favoriteStore.waitForPendingSave()
            do {
                let manifest = try await Task.detached { try service.createBackup() }.value
                resultMessage = "バックアップを作成しました（\(manifest.files.count)ファイル）。"
                refreshStatus()
            } catch { errorMessage = error.localizedDescription }
            isWorking = false
        }
    }

    private func restoreBackup() {
        guard let url = pendingRestoreURL else { return }
        pendingRestoreURL = nil
        isWorking = true
        Task {
            do {
                _ = try await Task.detached { try service.restore(from: url) }.value
                resultMessage = "復元の準備ができました。MyMusicを終了して再起動すると安全に適用されます。その後、音楽フォルダを再選択してください。"
            } catch { errorMessage = error.localizedDescription }
            isWorking = false
        }
    }
}
