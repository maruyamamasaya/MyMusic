import ImageIO
import SwiftUI

struct NowPlayingView: View {
    @Environment(WatchSessionManager.self) private var sessionManager
    @State private var showsDetails = false

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                backgroundLayer(size: proxy.size)
            }
            .ignoresSafeArea()

            GeometryReader { proxy in
                let metrics = LayoutMetrics(size: proxy.size)
                mainContent(metrics: metrics)
            }
        }
        .foregroundStyle(.white)
        .sheet(isPresented: $showsDetails) {
            PlaybackDetailsView()
        }
    }

    private func mainContent(metrics: LayoutMetrics) -> some View {
        let state = sessionManager.playbackState
        return VStack(spacing: 0) {
            utilityControls(metrics: metrics)
            trackInformation(for: state)
            preferenceControls(for: state)
            playbackProgress(for: state)
            Spacer(minLength: metrics.minimumVerticalSpacing)

            HStack(spacing: metrics.controlSpacing) {
                transportButton("backward.fill", label: "前の曲", command: .previous, diameter: metrics.controlDiameter)
                playPauseButton(for: state, diameter: metrics.controlDiameter)
                transportButton("forward.fill", label: "次の曲", command: .next, diameter: metrics.controlDiameter)
            }
            .frame(maxWidth: .infinity)
            .disabled(!sessionManager.isPhoneReachable || state.trackID == nil)
        }
        .frame(height: metrics.contentHeight, alignment: .top)
        .padding(.horizontal, metrics.horizontalPadding)
    }

    private func backgroundLayer(size: CGSize) -> some View {
        ZStack {
            artworkBackground
            LinearGradient(
                colors: [.black.opacity(0.72), .black.opacity(0.38), .black.opacity(0.76)],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .ignoresSafeArea()
    }

    @ViewBuilder
    private var artworkBackground: some View {
        if let image = artworkCGImage {
            Image(decorative: image, scale: 1)
                .resizable()
                .scaledToFill()
                .clipped()
                .accessibilityHidden(true)
        } else {
            ZStack {
                LinearGradient(colors: [.gray.opacity(0.46), .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                Image(systemName: "music.note")
                    .font(.system(size: 58, weight: .light))
                    .foregroundStyle(.white.opacity(0.18))
            }
            .accessibilityHidden(true)
        }
    }

    private var artworkCGImage: CGImage? {
        guard let data = sessionManager.artworkData,
              let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }

    private func trackInformation(for state: WatchPlaybackState) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(state.trackID == nil ? "再生中の曲はありません" : state.title)
                .font(.headline.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
            Text(state.trackID == nil ? connectionText : state.artist)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.80))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .shadow(color: .black.opacity(0.8), radius: 2, y: 1)
        .accessibilityElement(children: .combine)
    }

    private func preferenceControls(for state: WatchPlaybackState) -> some View {
        HStack(spacing: 4) {
            compactActionButton(
                state.isFavorite ? "heart.fill" : "heart",
                label: state.isFavorite ? "お気に入りから削除" : "お気に入りに追加",
                value: state.isFavorite ? "お気に入り" : "未登録",
                command: .toggleFavorite,
                isSelected: state.isFavorite
            )
            compactActionButton(
                state.playbackPreference > 0 ? "hand.thumbsup.fill" : "hand.thumbsup",
                label: "再生頻度を増やす",
                value: preferenceAccessibilityValue(for: state),
                command: .increasePlaybackPreference,
                isSelected: state.playbackPreference > 0
            )
            compactActionButton(
                state.playbackPreference < 0 ? "hand.thumbsdown.fill" : "hand.thumbsdown",
                label: "再生頻度を減らす",
                value: preferenceAccessibilityValue(for: state),
                command: .decreasePlaybackPreference,
                isSelected: state.playbackPreference < 0
            )
        }
        .frame(height: 30)
        .disabled(!sessionManager.isPhoneReachable || state.trackID == nil)
    }

    private func utilityControls(metrics: LayoutMetrics) -> some View {
        HStack(spacing: 3) {
            Spacer(minLength: 0)
            CompanionVolumeControl()
                .frame(width: metrics.utilityControlSize, height: metrics.utilityControlSize)
                .scaleEffect(0.65)
                .frame(width: metrics.utilityControlSize, height: metrics.utilityControlSize)
                .contentShape(Rectangle())
                .accessibilityLabel("iPhoneの音量")
                .accessibilityHint("選択してDigital Crownを回すと音量を調整できます")

            Button { showsDetails = true } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: metrics.utilityControlSize, height: metrics.utilityControlSize)
            }
            .buttonStyle(.plain)
            .background(.black.opacity(0.28), in: Circle())
            .accessibilityLabel("詳細")
        }
        .frame(height: metrics.utilityControlSize)
    }

    @ViewBuilder
    private func playbackProgress(for state: WatchPlaybackState) -> some View {
        if state.duration > 0 {
            GeometryReader { proxy in
                let progress = min(max(state.currentTime / state.duration, 0), 1)
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.24))
                    Capsule()
                        .fill(.white.opacity(0.92))
                        .frame(width: proxy.size.width * progress)
                }
            }
                .frame(height: 1)
                .accessibilityLabel("再生位置")
                .accessibilityValue("\(Int(min(state.currentTime, state.duration)))秒 / \(Int(state.duration))秒")
                .padding(.top, 1)
        }
    }

    private func compactActionButton(
        _ symbol: String,
        label: String,
        value: String,
        command: WatchPlaybackCommand,
        isSelected: Bool
    ) -> some View {
        Button { sessionManager.send(command) } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity, minHeight: 28)
                .background(isSelected ? .white.opacity(0.24) : .black.opacity(0.24), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private func preferenceAccessibilityValue(for state: WatchPlaybackState) -> String {
        guard state.playbackPreference != 0 else { return "未評価" }
        return "\(state.playbackPreference > 0 ? "グッド" : "バッド") \(abs(state.playbackPreference))、10段階中"
    }

    private func playPauseButton(for state: WatchPlaybackState, diameter: CGFloat) -> some View {
        Button { sessionManager.send(.togglePlayPause) } label: {
            Image(systemName: state.isPlaying ? "pause.fill" : "play.fill")
                .font(.system(size: diameter * 0.43, weight: .semibold))
                .foregroundStyle(.black)
                .frame(width: diameter, height: diameter)
                .background(.white.opacity(0.95), in: Circle())
                .shadow(color: .black.opacity(0.45), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel(state.isPlaying ? "一時停止" : "再生")
    }

    private func transportButton(_ symbol: String, label: String, command: WatchPlaybackCommand, diameter: CGFloat) -> some View {
        Button { sessionManager.send(command) } label: {
            Image(systemName: symbol)
                .font(.system(size: diameter * 0.37, weight: .semibold))
                .frame(width: diameter, height: diameter)
                .background {
                    Circle()
                        .fill(.black.opacity(0.38))
                        .frame(width: diameter - 4, height: diameter - 4)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel(label)
    }

    private var connectionText: String {
        sessionManager.errorMessage
            ?? (sessionManager.isPhoneReachable ? "iPhoneで曲を選んでください" : "iPhone未接続")
    }
}

private struct LayoutMetrics {
    let horizontalPadding: CGFloat
    let controlDiameter: CGFloat
    let controlSpacing: CGFloat
    let utilityControlSize: CGFloat
    let minimumVerticalSpacing: CGFloat
    let contentHeight: CGFloat

    init(size: CGSize) {
        horizontalPadding = max(8, size.width * 0.045)
        controlSpacing = max(6, size.width * 0.04)
        let availableControlWidth = size.width - horizontalPadding * 2 - controlSpacing * 2
        controlDiameter = min(max(availableControlWidth / 3, 44), 52)
        utilityControlSize = 32
        minimumVerticalSpacing = 2
        contentHeight = size.height
    }
}

private struct PlaybackDetailsView: View {
    var body: some View {
        List {
            Section("詳細") {
                Label("シャッフル", systemImage: "shuffle")
                Label("おすすめ再生", systemImage: "sparkles")
            }
            .foregroundStyle(.secondary)
        }
        .accessibilityHint("これらの機能は今後利用できるようになります")
    }
}

#if DEBUG
private struct NowPlayingView_Previews: PreviewProvider {
    static var previews: some View {
        ForEach(
            ["Apple Watch SE (40mm)", "Apple Watch SE (44mm)", "Apple Watch Ultra (49mm)"],
            id: \.self
        ) { deviceName in
            NowPlayingView()
                .environment(WatchSessionManager.preview)
                .previewDevice(PreviewDevice(rawValue: deviceName))
                .previewDisplayName(deviceName)
        }
    }
}
#endif
