import SwiftUI
import UniformTypeIdentifiers

struct SceneryVideoSettingsView: View {
    @State private var store = SceneryVideoStore()
    @State private var showsImporter = false
    @State private var confirmsRemoval = false
    @State private var selectedURL: URL?
    @State private var revision = UUID()
    @State private var importError: String?

    var body: some View {
        Form {
            Section {
                if let video = store.registeredVideo {
                    LabeledContent("動画", value: video.originalName)
                    LabeledContent("保存容量", value: ByteCountFormatter.string(fromByteCount: video.byteCount, countStyle: .file))
                } else {
                    Label("動画は未登録です", systemImage: "film")
                        .foregroundStyle(.secondary)
                }
                Button(store.registeredVideo == nil ? "動画を登録" : "動画を変更", systemImage: "folder") {
                    showsImporter = true
                }
                .disabled(store.isLoading)
                Button("登録を解除", systemImage: "trash", role: .destructive) { confirmsRemoval = true }
                    .disabled(store.isLoading)
            } header: {
                Text("車窓動画")
            } footer: {
                Text("FilesやiCloud Driveの動画1本をアプリ内に保存します。元動画は残り、コピー分の端末容量を使います。開くたびにランダム位置から、無音・18fps設定で再生します。")
            }
            if store.isLoading {
                Section {
                    ProgressView("動画を保存・準備中…")
                    Text("iCloudの動画はダウンロードに時間がかかる場合があります。")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            if let error = importError ?? store.errorMessage {
                Section { Text(error).foregroundStyle(.red) }
            }
        }
        .navigationTitle("車窓モード")
        .navigationBarTitleDisplayMode(.inline)
        .themeScreen()
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importError = nil
                    selectedURL = url
                    revision = UUID()
                }
            case .failure(let error): importError = error.localizedDescription
            }
        }
        .task(id: revision) { await store.open(selectedURL, preparesPlayback: false) }
        .confirmationDialog("車窓動画の登録を解除しますか？", isPresented: $confirmsRemoval, titleVisibility: .visible) {
            Button("登録を解除", role: .destructive) {
                selectedURL = nil
                Task { await store.unregister() }
            }
        } message: {
            Text("アプリ内に保存した動画を削除します。FilesやiCloudの元動画は削除しません。")
        }
        .onDisappear { store.stop() }
    }
}
