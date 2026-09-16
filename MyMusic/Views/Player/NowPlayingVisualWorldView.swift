import SwiftUI

struct NowPlayingVisualWorldView: View {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PlayerStore.self) private var player
    @Environment(TrackFeatureStore.self) private var features
    @Environment(TrackPreferenceStore.self) private var preferences

    var isFrontmost = true
    let onQueue: () -> Void
    let onEqualizer: () -> Void
    let onAddToPlaylist: () -> Void
    let onAudioInformation: () -> Void
    let onTrackAdjustments: () -> Void

    @State private var artworkColors: VisualWorldArtworkColors?
    @State private var showsControls = false
    @State private var expanded = false
    @State private var suggestedDirection = 0
    @State private var revealFeedback = 0
    @State private var motion = VisualWorldDynamics()

    private var values: TrackFeatureValues? {
        player.currentTrack.flatMap { features.feature(for: $0.id)?.values }
    }
    private var isAnimating: Bool {
        isFrontmost && scenePhase == .active && player.isPlaying
            && !reduceMotion && !reduceTransparency && contrast != .increased
    }

    var body: some View {
        let shouldReduceMotion = reduceMotion
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                visualBackground
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(revealGesture)
                    .accessibilityElement()
                    .accessibilityLabel("音楽のアート。操作を表示")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { reveal(expanded: false) }
                VStack(spacing: 14) {
                    Spacer(minLength: 0)
                    identity
                    if showsControls {
                        VisualWorldController(
                            expanded: $expanded, suggestedDirection: suggestedDirection,
                            maximumHeight: geometry.size.height * 0.63,
                            onClose: { withAnimation(.easeOut(duration: 0.2)) { showsControls = false } },
                            onQueue: onQueue, onEqualizer: onEqualizer,
                            onAddToPlaylist: onAddToPlaylist, onAudioInformation: onAudioInformation,
                            onTrackAdjustments: onTrackAdjustments
                        )
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    } else {
                        Button { reveal(expanded: false) } label: {
                            Text("タップで操作 · 長押しで詳細")
                                .font(.caption2)
                                .foregroundStyle(.white.opacity(contrast == .increased ? 0.9 : 0.6))
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("コントローラーを表示")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 10)
            }
            .keyframeAnimator(initialValue: CGFloat.zero, trigger: revealFeedback) { content, offset in
                content.offset(x: shouldReduceMotion ? 0 : offset)
            } keyframes: { _ in
                LinearKeyframe(-2.5, duration: 0.05)
                LinearKeyframe(2, duration: 0.06)
                LinearKeyframe(-1, duration: 0.06)
                LinearKeyframe(0, duration: 0.08)
            }
        }
        .background(.black)
        .sensoryFeedback(.impact(weight: .light), trigger: revealFeedback)
        .task(id: player.currentTrack?.artworkIdentifier) {
            artworkColors = nil
            guard let identifier = player.currentTrack?.artworkIdentifier else { return }
            let colors = await VisualWorldPaletteService.shared.colors(for: identifier)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.8)) { artworkColors = colors }
        }
        .onChange(of: isAnimating) { _, _ in motion.suspend() }
        .onChange(of: player.currentTrack?.id) { _, _ in suggestedDirection = 0 }
    }

    private var visualBackground: some View {
        let palette = ThemePalette.resolve(theme)
        let primary = artworkColors.map { color($0.primary) } ?? (theme == .simpleDark ? .indigo : palette.light)
        let secondary = artworkColors.map { color($0.secondary) } ?? palette.accent
        let energy = values?.energy ?? 0.5
        let speed = energy * 0.55 + min((values?.tempo ?? 100) / 180, 1) * 0.3 + (1 - (values?.calm ?? 0.5)) * 0.15
        return TimelineView(.animation(minimumInterval: ProcessInfo.processInfo.isLowPowerModeEnabled ? 1.0 / 20 : 1.0 / 30,
                                       paused: !isAnimating)) { timeline in
            ZStack {
                VisualWorldScene(theme: theme, primary: primary, secondary: secondary,
                                 motion: motion, energy: energy, ambient: values?.ambient ?? 0.5,
                                 brightness: values?.bright ?? 0.5,
                                 subdued: reduceTransparency || contrast == .increased)
                LinearGradient(stops: [.init(color: .clear, location: 0.62),
                                       .init(color: .black.opacity(0.68), location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            .onChange(of: timeline.date) { _, date in
                guard isAnimating else { return }
                motion.advance(date: date, level: Double(player.spatialSnapshot.level),
                               width: Double(player.spatialSnapshot.width),
                               balance: Double(player.spatialSnapshot.balance), speed: speed)
            }
        }
    }

    private var identity: some View {
        HStack(spacing: 12) {
            AlbumArtworkView(artworkIdentifier: player.currentTrack?.artworkIdentifier)
                .frame(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 4) {
                Text(player.currentTrack?.title ?? "未再生")
                    .font(.headline)
                    .lineLimit(2)
                Text(player.currentTrack?.artistName ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.75))
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            if let track = player.currentTrack, preferences.isFavorite(trackID: track.id) {
                Image(systemName: "heart.fill").foregroundStyle(.pink).accessibilityLabel("お気に入り")
            }
        }
        .padding(12)
        .background(.black.opacity(0.48), in: RoundedRectangle(cornerRadius: 16))
        .foregroundStyle(.white)
    }

    /// Exclusive recognition: no background gesture can call a playback or preference API.
    private var revealGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.85, maximumDistance: 18)
            .onEnded { _ in
                revealFeedback += 1
                reveal(expanded: true)
            }
            .exclusively(before:
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) * 1.4 else { return }
                        suggestedDirection = value.translation.width > 0 ? 1 : -1
                        reveal(expanded: false)
                    }
            )
            .exclusively(before: TapGesture().onEnded { reveal(expanded: false) })
    }

    private func reveal(expanded: Bool) {
        withAnimation(.spring(response: reduceMotion ? 0.01 : 0.3, dampingFraction: 0.86)) {
            if !showsControls || expanded { self.expanded = expanded }
            showsControls = true
        }
    }

    private func color(_ rgb: VisualWorldRGB) -> Color {
        Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }
}
