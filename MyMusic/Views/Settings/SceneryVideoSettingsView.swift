import SwiftUI
import UniformTypeIdentifiers

struct SceneryVideoSettingsView: View {
    @State private var store = SceneryVideoStore()
    @State private var showsImporter = false
    @State private var videoToRemove: RegisteredSceneryVideo?
    @State private var selectedURL: URL?
    @State private var revision = UUID()
    @State private var importError: String?

    var body: some View {
        Form {
            Section {
                if store.registeredVideos.isEmpty {
                    Label("動画は未登録です", systemImage: "film").foregroundStyle(.secondary)
                }
                ForEach(store.registeredVideos) { video in
                    HStack {
                        Button {
                            Task { await store.select(video) }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: store.registeredVideo?.id == video.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(store.registeredVideo?.id == video.id ? Color.accentColor : .secondary)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(video.originalName).foregroundStyle(.primary)
                                    Text(ByteCountFormatter.string(fromByteCount: video.byteCount, countStyle: .file))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityValue(store.registeredVideo?.id == video.id ? "選択中" : "未選択")
                        Button(role: .destructive) { videoToRemove = video } label: {
                            Image(systemName: "trash").frame(minWidth: 44, minHeight: 44)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("\(video.originalName)の登録を解除")
                    }
                    .disabled(store.isLoading)
                }
                Button("動画を追加", systemImage: "plus") { showsImporter = true }
                    .disabled(store.isLoading)
            } header: {
                Text("車窓動画")
            } footer: {
                Text("登録した動画をタップして、車窓で流す1本を選びます。次に車窓モードを開くと、選んだ動画のランダム位置から無音・18fps設定で再生します。動画の自動切り替えは行いません。追加時はアプリ内へコピーするため、元動画に加えて端末容量を使います。")
            }
            if store.isLoading {
                Section {
                    ProgressView("動画を準備中…")
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
                if let url = urls.first { importError = nil; selectedURL = url; revision = UUID() }
            case .failure(let error): importError = error.localizedDescription
            }
        }
        .task(id: revision) { await store.open(selectedURL, preparesPlayback: false) }
        .confirmationDialog("この動画の登録を解除しますか？", isPresented: Binding(
            get: { videoToRemove != nil }, set: { if !$0 { videoToRemove = nil } }
        ), titleVisibility: .visible, presenting: videoToRemove) { video in
            Button("登録を解除", role: .destructive) {
                selectedURL = nil
                Task { await store.remove(video) }
                videoToRemove = nil
            }
        } message: { video in
            Text("\(video.originalName)のアプリ内コピーを削除します。FilesやiCloudの元動画は削除しません。選択中の動画なら残りの先頭へ切り替えます。")
        }
        .onDisappear { store.stop() }
    }
}
