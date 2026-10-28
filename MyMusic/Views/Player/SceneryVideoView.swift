import SwiftUI
import AVFoundation

struct SceneryVideoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var store = SceneryVideoStore()
    @State private var controlsVisible = true
    @State private var isBGMCollapsed = false
    @State private var orientationError: String?

    private var active: Bool { scenePhase == .active && store.isReady }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            SceneryPlayerSurface(player: store.player)
                .ignoresSafeArea()
                .overlay { Color.black.opacity(0.08).ignoresSafeArea().allowsHitTesting(false) }
                .contentShape(Rectangle())
                .onTapGesture { controlsVisible.toggle() }
                .accessibilityLabel("車窓映像。タップで操作を表示")
            if !store.isReady {
                VStack(spacing: 16) {
                    if store.isLoading {
                        ProgressView("動画を準備中…")
                    } else {
                        SceneryModeIcon(size: 48)
                        Text("車窓モード").font(.title2)
                        Text(store.errorMessage ?? "設定 → 車窓モードで動画を登録してください。")
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(24)
            }
            if controlsVisible || !store.isReady {
                VStack(alignment: .leading) {
                    Spacer(minLength: 12)
                    if let orientationError { Text(orientationError).font(.caption) }
                    SceneryBGMOverlay(onReturn: { dismiss() }, isCollapsed: $isBGMCollapsed)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 4)
            }
        }
        .foregroundStyle(.white)
        .tint(.white)
        .buttonStyle(.plain)
        .background {
            SceneryOrientationHost { orientationError = $0 }
                .allowsHitTesting(false)
        }
        .accessibilityAction(.escape) { dismiss() }
        .preferredColorScheme(.dark)
        .task {
            await store.open()
            store.setActive(active)
        }
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
