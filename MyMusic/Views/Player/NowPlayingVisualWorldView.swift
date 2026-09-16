import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI

/// An optional visual presentation of the existing player. All playback actions stay in PlayerStore.
struct NowPlayingVisualWorldView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(PlayerStore.self) private var player
    @Environment(TrackFeatureStore.self) private var features
    @Environment(TrackPreferenceStore.self) private var preferences

    let onQueue: () -> Void
    let onEqualizer: () -> Void
    let onAddToPlaylist: () -> Void
    let onAudioInformation: () -> Void
    let onTrackAdjustments: () -> Void

    @State private var artworkColor: Color = .indigo
    @State private var showsControls = false
    @State private var seekPreview: TimeInterval?

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                visualBackground
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) { toggleFavorite() }
                    .onTapGesture { if !player.isLoading { player.togglePlayPause() } }
                    .simultaneousGesture(holdAndSeek(width: geometry.size.width))
                    .simultaneousGesture(trackSwipe)
                    .accessibilityLabel("再生中のアート")
                    .accessibilityHint("ダブルタップでお気に入り。長押しで操作を表示")
                    .accessibilityAction(named: "再生または一時停止") { player.togglePlayPause() }
                    .accessibilityAction(named: "次の曲") { if player.hasNext { player.next() } }
                    .accessibilityAction(named: "前の曲") { if player.hasPrevious { player.previous() } }

                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    identity
                    if showsControls {
                        controls
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Text("長押しで操作")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.42))
                            .padding(.top, 20)
                            .accessibilityHidden(true)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .background(.black)
        .ignoresSafeArea(edges: .bottom)
        .task(id: player.currentTrack?.artworkIdentifier) {
            artworkColor = ThemePalette.resolve(theme).light
            guard let identifier = player.currentTrack?.artworkIdentifier,
                  let image = await ArtworkService.shared.artworkImage(for: identifier),
                  !Task.isCancelled else { return }
            artworkColor = ArtworkLightColor.extract(from: image) ?? ThemePalette.resolve(theme).light
        }
        .onChange(of: player.currentTrack?.id) { _, _ in
            seekPreview = nil
        }
    }

    private var visualBackground: some View {
        let palette = ThemePalette.resolve(theme)
        let values = player.currentTrack.flatMap { features.feature(for: $0.id)?.values }
        let energy = min(max(values?.energy ?? 0.45, 0), 1)
        let ambient = min(max(values?.ambient ?? 0.4, 0), 1)
        let brightness = min(max(values?.bright ?? 0.45, 0), 1)
        let calm = min(max(values?.calm ?? 0.5, 0), 1)
        let tempo = min(max((values?.tempo ?? 100) / 200, 0.25), 1)
        let level = player.isPlaying ? Double(player.spatialSnapshot.level) : 0
        let balance = Double(player.spatialSnapshot.balance)
        let width = Double(player.spatialSnapshot.width)
        let isStatic = reduceMotion || reduceTransparency || contrast == .increased

        return TimelineView(.animation(minimumInterval: 1.0 / 20.0, paused: !player.isPlaying || isStatic)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            let rate = 0.08 + energy * 0.18 + tempo * 0.16 - calm * 0.05
            let phase = isStatic ? 0 : time * rate
            GeometryReader { proxy in
                ZStack {
                    ThemeBackground(theme: theme)
                    if !reduceTransparency && contrast != .increased {
                        Ellipse()
                            .fill(RadialGradient(colors: [artworkColor.opacity(0.19 + calm * 0.05 + level * 0.22), .clear], center: .center, startRadius: 0, endRadius: proxy.size.width * 0.56))
                            .frame(width: proxy.size.width * (1.25 + width * 0.45), height: proxy.size.height * (0.58 + ambient * 0.28))
                            .position(x: proxy.size.width * (0.48 + balance * 0.16 + sin(phase) * 0.09), y: proxy.size.height * (0.32 + cos(phase * 0.7) * 0.07))
                        Ellipse()
                            .fill(RadialGradient(colors: [palette.accent.opacity(0.12 + level * 0.20), .clear], center: .center, startRadius: 0, endRadius: proxy.size.width * 0.42))
                            .frame(width: proxy.size.width * (0.88 + width * 0.42), height: proxy.size.height * 0.6)
                            .position(x: proxy.size.width * (0.62 - balance * 0.17 - sin(phase * 0.67) * 0.1), y: proxy.size.height * (0.65 + sin(phase * 0.8) * 0.07))
                        Ellipse()
                            .fill(RadialGradient(colors: [palette.light.opacity(0.05 + brightness * 0.1 + level * 0.08), .clear], center: .center, startRadius: 0, endRadius: proxy.size.width * 0.28))
                            .frame(width: proxy.size.width * 0.7, height: proxy.size.height * 0.38)
                            .position(x: proxy.size.width * (0.35 + sin(phase * 1.3) * 0.12), y: proxy.size.height * 0.48)
                    }
                    LinearGradient(colors: [.black.opacity(0.38), .clear, .black.opacity(0.12), .black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
            }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }

    private var identity: some View {
        HStack(spacing: 12) {
            AlbumArtworkView(artworkIdentifier: player.currentTrack?.artworkIdentifier)
                .frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 3) {
                Text(player.currentTrack?.title ?? "未再生")
                    .font(.headline)
                    .lineLimit(2)
                Text(player.currentTrack?.artistName ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            if let track = player.currentTrack, preferences.isFavorite(trackID: track.id) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)
                    .accessibilityLabel("お気に入り")
            }
        }
        .padding(12)
        .background(.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 16))
        .foregroundStyle(.white)
    }

    private var controls: some View {
        VStack(spacing: 15) {
            HStack {
                Text("操作")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Button("閉じる", systemImage: "xmark") { withAnimation { showsControls = false } }
                    .labelStyle(.iconOnly)
            }

            ProgressBarView(
                currentTime: seekPreview ?? player.currentTime,
                duration: player.duration,
                onSeek: player.seek
            )

            HStack(spacing: 24) {
                Button("前の曲", systemImage: "backward.end.fill") { player.previous() }
                    .disabled(!player.hasPrevious || player.isLoading)
                Button(player.isPlaying ? "一時停止" : "再生", systemImage: player.isPlaying ? "pause.fill" : "play.fill") {
                    player.togglePlayPause()
                }
                .disabled(player.isLoading)
                Button("次の曲", systemImage: "forward.end.fill") { player.next() }
                    .disabled(!player.hasNext || player.isLoading)
            }
            .font(.title2)
            .labelStyle(.iconOnly)
            .frame(maxWidth: .infinity)

            HStack(spacing: 18) {
                Button("シャッフル", systemImage: "shuffle") { player.toggleShuffle() }
                    .foregroundStyle(player.isShuffleEnabled ? ThemePalette.resolve(theme).accent : Color.secondary)
                Button("リピート", systemImage: player.repeatMode == .one ? "repeat.1" : "repeat") { player.cycleRepeatMode() }
                    .foregroundStyle(player.repeatMode == .off ? Color.secondary : ThemePalette.resolve(theme).accent)
                Spacer()
                if let track = player.currentTrack {
                    TrackFavoriteButton(track: track)
                }
                Button("オーディオ情報", systemImage: "waveform") { onAudioInformation() }
                Button("曲別調整", systemImage: "slider.horizontal.3") { onTrackAdjustments() }
            }
            .font(.title3)
            .labelStyle(.iconOnly)

            if let track = player.currentTrack {
                HStack(spacing: 12) {
                    PlaybackPreferenceButton(track: track, direction: .decrease, compact: true)
                    PlaybackPreferenceButton(track: track, direction: .increase, compact: true)
                    BoredomButton(track: track)
                    ListenLaterButton(track: track)
                    Spacer()
                    Button("プレイリストに追加", systemImage: "text.badge.plus", action: onAddToPlaylist)
                    Button("キュー", systemImage: "list.bullet", action: onQueue)
                    Button("EQ", systemImage: "slider.vertical.3", action: onEqualizer)
                }
                .labelStyle(.iconOnly)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .buttonStyle(.plain)
        .padding(.top, 12)
    }

    private var trackSwipe: some Gesture {
        DragGesture(minimumDistance: 40)
            .onEnded { value in
                guard !showsControls else { return }
                guard abs(value.translation.width) > abs(value.translation.height) * 1.5 else { return }
                if value.translation.width > 70, player.hasNext { player.next() }
                if value.translation.width < -70, player.hasPrevious { player.previous() }
            }
    }

    private func holdAndSeek(width: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.45)
            .sequenced(before: DragGesture(minimumDistance: 0))
            .onChanged { state in
                switch state {
                case .first(true):
                    withAnimation(.easeOut(duration: 0.2)) { showsControls = true }
                case .second(true, let drag?):
                    guard player.duration > 0 else { return }
                    seekPreview = min(max(player.currentTime + Double(drag.translation.width / max(width, 1)) * player.duration, 0), player.duration)
                default: break
                }
            }
            .onEnded { _ in
                if let seekPreview { player.seek(to: seekPreview) }
                seekPreview = nil
            }
    }

    private func toggleFavorite() {
        guard let track = player.currentTrack, track.isEligibleForRegularPlayback else { return }
        preferences.toggleFavorite(trackID: track.id)
    }
}

private enum ArtworkLightColor {
    static func extract(from image: UIImage) -> Color? {
        guard let ciImage = CIImage(image: image) else { return nil }
        let filter = CIFilter.areaAverage()
        filter.inputImage = ciImage
        filter.extent = ciImage.extent
        guard let output = filter.outputImage else { return nil }
        var pixel = [UInt8](repeating: 0, count: 4)
        CIContext(options: [.workingColorSpace: NSNull()]).render(
            output, toBitmap: &pixel, rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        let boost = 1.35
        return Color(.sRGB,
                     red: min(Double(pixel[0]) / 255 * boost, 1),
                     green: min(Double(pixel[1]) / 255 * boost, 1),
                     blue: min(Double(pixel[2]) / 255 * boost, 1),
                     opacity: 1)
    }
}
