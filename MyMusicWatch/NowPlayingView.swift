import ImageIO
import SwiftUI

struct NowPlayingView: View {
    @Environment(WatchSessionManager.self) private var sessionManager
    @State private var showsPreferences = false

    var body: some View {
        GeometryReader { proxy in
            let metrics = LayoutMetrics(size: proxy.size, safeAreaInsets: proxy.safeAreaInsets)
            ZStack {
                artworkBackground
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                LinearGradient(
                    colors: [.black.opacity(0.72), .black.opacity(0.38), .black.opacity(0.76)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                mainContent(metrics: metrics)
            }
        }
        .foregroundStyle(.white)
        .sheet(isPresented: $showsPreferences) {
            PreferenceControlsView(sessionManager: sessionManager)
        }
    }

    private func mainContent(metrics: LayoutMetrics) -> some View {
        let state = sessionManager.playbackState
        return VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 4) {
                trackInformation(for: state)
                Button { showsPreferences = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 40, height: 36)
                        .background(.black.opacity(0.32), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("お気に入りと再生傾向")
            }

            Spacer(minLength: metrics.minimumVerticalSpacing)
            playbackProgress(for: state)

            HStack(spacing: metrics.controlSpacing) {
                transportButton("backward.fill", label: "前の曲", command: .previous, diameter: metrics.controlDiameter)
                playPauseButton(for: state, diameter: metrics.controlDiameter)
                transportButton("forward.fill", label: "次の曲", command: .next, diameter: metrics.controlDiameter)
            }
            .frame(maxWidth: .infinity)
            .disabled(!sessionManager.isPhoneReachable || state.trackID == nil)

            HStack(spacing: 5) {
                Image(systemName: "speaker.wave.2.fill")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.82))
                Text("音量")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.82))
                Spacer(minLength: 4)
                CompanionVolumeControl()
                    .frame(width: metrics.volumeControlWidth, height: metrics.volumeHeight)
                    .contentShape(Rectangle())
                    .accessibilityLabel("iPhoneの音量")
                    .accessibilityHint("選択してDigital Crownを回すと音量を調整できます")
            }
            .frame(height: metrics.volumeHeight)
            .padding(.horizontal, 7)
            .background(.black.opacity(0.30), in: Capsule())
            .offset(y: metrics.volumeVerticalAdjustment)
        }
        .padding(.top, metrics.contentTopPadding)
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.bottom, metrics.contentBottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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

    @ViewBuilder
    private func playbackProgress(for state: WatchPlaybackState) -> some View {
        if state.duration > 0 {
            ProgressView(value: min(state.currentTime, state.duration), total: state.duration)
                .tint(.white)
                .accessibilityLabel("再生位置")
                .padding(.bottom, 4)
        }
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
                .background(.black.opacity(0.38), in: Circle())
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
    let contentTopPadding: CGFloat
    let contentBottomPadding: CGFloat
    let controlDiameter: CGFloat
    let controlSpacing: CGFloat
    let volumeHeight: CGFloat
    let volumeControlWidth: CGFloat
    let volumeVerticalAdjustment: CGFloat
    let minimumVerticalSpacing: CGFloat

    init(size: CGSize, safeAreaInsets: EdgeInsets) {
        horizontalPadding = max(8, size.width * 0.045)
        contentTopPadding = max(safeAreaInsets.top, 5)
        contentBottomPadding = max(safeAreaInsets.bottom, 3)
        controlSpacing = max(6, size.width * 0.04)
        let availableControlWidth = size.width - horizontalPadding * 2 - controlSpacing * 2
        controlDiameter = min(max(availableControlWidth / 3, 44), 52)
        volumeHeight = size.height < 210 ? 28 : 38
        volumeControlWidth = size.height < 210 ? 40 : 48
        volumeVerticalAdjustment = size.height < 210 ? -6 : 0
        minimumVerticalSpacing = size.height < 210 ? 3 : 7
    }
}

private struct PreferenceControlsView: View {
    let sessionManager: WatchSessionManager

    var body: some View {
        let state = sessionManager.playbackState
        VStack(spacing: 8) {
            Text("曲の設定").font(.headline)
            HStack(spacing: 8) {
                actionButton(state.isFavorite ? "heart.fill" : "heart", label: state.isFavorite ? "お気に入りから削除" : "お気に入りに追加", value: state.isFavorite ? "お気に入り" : "未登録", command: .toggleFavorite)
                actionButton(state.playbackPreference > 0 ? "hand.thumbsup.fill" : "hand.thumbsup", label: "再生頻度を増やす", value: preferenceAccessibilityValue, command: .increasePlaybackPreference)
                actionButton(state.playbackPreference < 0 ? "hand.thumbsdown.fill" : "hand.thumbsdown", label: "再生頻度を減らす", value: preferenceAccessibilityValue, command: .decreasePlaybackPreference)
            }
            Text(preferenceLabel)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .disabled(!sessionManager.isPhoneReachable || state.trackID == nil)
        .padding(.horizontal, 8)
    }

    private func actionButton(_ symbol: String, label: String, value: String, command: WatchPlaybackCommand) -> some View {
        Button { sessionManager.send(command) } label: {
            Image(systemName: symbol)
                .font(.title3)
                .frame(width: 48, height: 48)
        }
        .buttonStyle(.bordered)
        .buttonBorderShape(.circle)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    private var preferenceLabel: String {
        let value = sessionManager.playbackState.playbackPreference
        guard value != 0 else { return "再生傾向: 未評価" }
        return "再生傾向: \(value > 0 ? "Good" : "Bad") \(abs(value))/10"
    }

    private var preferenceAccessibilityValue: String {
        let value = sessionManager.playbackState.playbackPreference
        guard value != 0 else { return "未評価" }
        return "\(value > 0 ? "グッド" : "バッド") \(abs(value))、10段階中"
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
