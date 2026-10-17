import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct SceneryVideoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PlayerStore.self) private var music
    @State private var store = SceneryVideoStore()
    @State private var selectedURL: URL?
    @State private var loadRevision = UUID()
    @State private var showsImporter = false
    @State private var importError: String?
    @State private var controlsVisible = true
    @State private var confirmsUnregister = false
    @State private var orientationError: String?

    private var active: Bool { scenePhase == .active && music.isPlaying && !showsImporter && store.isReady }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                SceneryPlayerSurface(player: store.player)
                    .ignoresSafeArea()
                    .contentShape(Rectangle())
                    .onTapGesture { controlsVisible.toggle() }
                    .accessibilityLabel("車窓映像。タップで操作を表示")
                if !store.isReady {
                    VStack(spacing: 16) {
                        if store.isLoading {
                            ProgressView("動画を保存・準備中…")
                            Text("iCloudの動画はダウンロードに時間がかかる場合があります。")
                                .font(.caption).multilineTextAlignment(.center)
                        } else {
                            Image(systemName: "tram.fill").font(.largeTitle)
                            Text("車窓モード Beta").font(.title2)
                            Text(importError ?? store.errorMessage ?? "動画をアプリ内に保存し、次回から自動で再生します。\nランダム開始・無音・18fps。")
                                .multilineTextAlignment(.center)
                            Button("Filesから動画を選ぶ") { showsImporter = true }
                                .buttonStyle(.borderedProminent)
                            Text("元動画はそのまま残り、コピー分の端末容量を使います。")
                                .font(.caption)
                        }
                    }
                    .padding(24)
                }
                if controlsVisible || !store.isReady {
                    VStack {
                        HStack {
                            Button("閉じる", systemImage: "xmark") { dismiss() }
                            Spacer()
                            Menu {
                                if let video = store.registeredVideo {
                                    Text(video.originalName)
                                    Text(ByteCountFormatter.string(fromByteCount: video.byteCount, countStyle: .file))
                                }
                                Button("動画を変更", systemImage: "folder") { showsImporter = true }
                                Button("登録を解除", systemImage: "trash", role: .destructive) {
                                    confirmsUnregister = true
                                }
                            } label: {
                                Label("動画の管理", systemImage: "ellipsis.circle")
                            }
                            .disabled(store.isLoading)
                        }
                        Spacer()
                        if let orientationError {
                            Text(orientationError).font(.caption)
                        }
                        if store.isReady {
                            if let error = store.errorMessage {
                                Text(error).font(.caption).padding(8)
                                    .background(.black.opacity(0.8), in: RoundedRectangle(cornerRadius: 8))
                            }
                            HStack(spacing: 24) {
                                VStack(alignment: .leading) {
                                    Text(music.currentTrack?.title ?? "未再生").lineLimit(1)
                                    Text(music.currentTrack?.artistName ?? "").font(.caption).lineLimit(1)
                                }
                                Spacer(minLength: 0)
                                Button { music.togglePlayPause() } label: {
                                    Image(systemName: music.isPlaying ? "pause.fill" : "play.fill")
                                        .font(.title2).frame(minWidth: 44, minHeight: 44)
                                }
                                .disabled(music.currentTrack == nil || music.isLoading)
                                .accessibilityLabel(music.isPlaying ? "音楽を一時停止" : "音楽を再生")
                                Button { music.next() } label: {
                                    Image(systemName: "forward.end.fill").frame(minWidth: 44, minHeight: 44)
                                }
                                .disabled(!music.hasNext)
                                .accessibilityLabel("次の曲")
                            }
                            .padding().background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 16))
                        } else if geometry.size.height > geometry.size.width {
                            Text("iPhoneを横向きにすると映像を大きく表示できます。")
                                .font(.caption).multilineTextAlignment(.center)
                        }
                    }
                    .padding()
                }
            }
            .foregroundStyle(.white)
            .tint(.white)
        }
        .background {
            SceneryOrientationHost { orientationError = $0 }
                .allowsHitTesting(false)
        }
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $showsImporter, allowedContentTypes: [.movie], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    importError = nil
                    selectedURL = url
                    loadRevision = UUID()
                    controlsVisible = true
                }
            case .failure(let error): importError = error.localizedDescription
            }
        }
        .task(id: loadRevision) {
            await store.open(selectedURL)
            store.setActive(active)
        }
        .confirmationDialog("車窓動画の登録を解除しますか？", isPresented: $confirmsUnregister, titleVisibility: .visible) {
            Button("登録を解除", role: .destructive) {
                selectedURL = nil
                Task { await store.unregister() }
            }
        } message: {
            Text("アプリ内に保存した動画を削除します。FilesやiCloudの元動画は削除しません。")
        }
        .alert("動画を開けませんでした", isPresented: Binding(
            get: { importError != nil }, set: { if !$0 { importError = nil } }
        )) { Button("OK") { importError = nil } } message: { Text(importError ?? "") }
        .onChange(of: active) { _, value in store.setActive(value) }
        .onDisappear { store.stop() }
    }
}

private struct SceneryPlayerSurface: UIViewRepresentable {
    let player: AVPlayer
    func makeUIView(context: Context) -> Surface {
        let view = Surface()
        view.playerLayer.videoGravity = .resizeAspect
        view.playerLayer.player = player
        return view
    }
    func updateUIView(_ uiView: Surface, context: Context) { uiView.playerLayer.player = player }
    static func dismantleUIView(_ uiView: Surface, coordinator: ()) { uiView.playerLayer.player = nil }

    final class Surface: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }
}
