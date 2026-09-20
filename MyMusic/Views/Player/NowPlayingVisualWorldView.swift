import SwiftUI

struct NowPlayingVisualWorldView: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.scenePhase) private var scenePhase
    @Environment(PlayerStore.self) private var player
    @Environment(TrackFeatureStore.self) private var features
    @Environment(TrackPreferenceStore.self) private var preferences

    var isFrontmost = true

    @State private var artworkColors: VisualWorldArtworkColors?
    @State private var motion = VisualWorldDynamics()
    @State private var simulation = VisualWorldSimulation()
    @State private var metalUnavailable = false
    @State private var thermal = ProcessInfo.processInfo.thermalState
    @State private var thermalRecovery: Task<Void, Never>?
    @State private var lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled

    private var values: TrackFeatureValues? {
        player.currentTrack.flatMap { features.feature(for: $0.id)?.values }
    }
    private var style: VisualWorldStyle { settings.visualWorldStyle }
    private var isAnimating: Bool {
        isFrontmost && scenePhase == .active && (player.isPlaying || !simulation.resting)
            && thermal != .critical
            && !reduceMotion && !reduceTransparency && contrast != .increased
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            visualBackground
                .ignoresSafeArea()
                .allowsHitTesting(false)
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .gesture(artworkTapGesture)
                .accessibilityElement()
                .accessibilityLabel("再生中のビジュアル")
                .accessibilityHint("1回タップで再生または一時停止、2回タップでいいねを切り替えます")
                .accessibilityAction(named: "再生または一時停止") { togglePlayback() }
                .accessibilityAction(named: "いいねを切り替え") { toggleFavorite() }
            VStack {
                Spacer(minLength: 0)
                VisualWorldController()
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .background(.black)
        .task(id: player.currentTrack?.artworkIdentifier) {
            guard let identifier = player.currentTrack?.artworkIdentifier else { artworkColors = nil; return }
            let colors = await VisualWorldPaletteService.shared.colors(for: identifier)
            guard !Task.isCancelled else { return }
            withAnimation(.easeInOut(duration: 0.8)) { artworkColors = colors }
        }
        .onChange(of: isAnimating) { _, _ in motion.suspend(); simulation.suspend() }
        .onChange(of: analysisEnabled, initial: true) { _, enabled in player.setVisualAnalysisEnabled(enabled) }
        .onDisappear { player.setVisualAnalysisEnabled(false); thermalRecovery?.cancel() }
        .onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
            let next = ProcessInfo.processInfo.thermalState
            thermalRecovery?.cancel()
            if next.rawValue >= thermal.rawValue {
                thermal = next
            } else {
                thermalRecovery = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(30))
                    guard !Task.isCancelled else { return }
                    thermal = ProcessInfo.processInfo.thermalState
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
            lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        }
    }

    private var analysisEnabled: Bool {
        isAnimating && player.isPlaying
    }

    private var artworkTapGesture: some Gesture {
        TapGesture(count: 2)
            .exclusively(before: TapGesture())
            .onEnded { value in
                switch value {
                case .first: toggleFavorite()
                case .second: togglePlayback()
                }
            }
    }

    private func togglePlayback() {
        guard player.currentTrack != nil && !player.isLoading else { return }
        player.togglePlayPause()
    }

    private func toggleFavorite() {
        guard let track = player.currentTrack, track.isEligibleForRegularPlayback else { return }
        preferences.toggleFavorite(trackID: track.id)
    }

    private var frameInterval: Double {
        thermal == .serious ? 1.0 / 15 : (lowPower ? 1.0 / 20 : 1.0 / 30)
    }

    private var visualBackground: some View {
        let palette = ThemePalette.resolve(style.themePalette)
        let primary = artworkColors.map { color($0.primary) }
            ?? (style == .twilight ? Color(red: 0.63, green: 0.28, blue: 0.52)
                : style == .plasmaSpark ? Color(red: 0.38, green: 0.24, blue: 0.9)
                : style == .visualizer ? Color(red: 0.12, green: 0.68, blue: 0.92)
                : style == .photonSphere ? .indigo : palette.light)
        let secondary = artworkColors.map { color($0.secondary) }
            ?? (style == .twilight ? Color(red: 1, green: 0.54, blue: 0.31)
                : style == .plasmaSpark ? Color(red: 0.2, green: 0.78, blue: 1)
                : style == .visualizer ? Color(red: 0.69, green: 0.34, blue: 0.96)
                : palette.accent)
        let energy = values?.energy ?? 0.5
        let speed = energy * 0.55 + min((values?.tempo ?? 100) / 180, 1) * 0.3 + (1 - (values?.calm ?? 0.5)) * 0.15
        return TimelineView(.animation(minimumInterval: frameInterval,
                                       paused: !isAnimating)) { timeline in
            ZStack {
                if !metalUnavailable {
                    VisualWorldMetalView(uniforms: metalUniforms(primary: primary, secondary: secondary),
                                         active: isAnimating, lowPower: lowPower || thermal == .serious,
                                         frameInterval: frameInterval,
                                         onFailure: { metalUnavailable = true })
                } else {
                    VisualWorldScene(style: style, primary: primary, secondary: secondary,
                                     motion: motion, worldSeed: player.visualWorldSeed,
                                     energy: energy, ambient: values?.ambient ?? 0.5,
                                     brightness: values?.bright ?? 0.5,
                                     aggressive: values?.aggressive ?? 0.5,
                                     electronic: values?.electronic ?? 0.5,
                                     bands: simulation.bands, waveform: simulation.waveform,
                                     bass: simulation.bass, mid: simulation.mid,
                                     treble: simulation.treble, beat: simulation.beat,
                                     burstAge: simulation.burstAge,
                                     burstBass: simulation.burstBass,
                                     burstMid: simulation.burstMid,
                                     burstTreble: simulation.burstTreble,
                                     burstSerial: simulation.burstSerial,
                                     subdued: reduceTransparency || contrast == .increased)
                }
                LinearGradient(stops: [.init(color: .clear, location: 0.76),
                                       .init(color: .black.opacity(0.68), location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            .onChange(of: timeline.date) { _, date in
                guard isAnimating else { return }
                simulation.advance(date: date, audio: player.visualAudioFrame, playing: player.isPlaying,
                                   energy: energy, aggressive: values?.aggressive ?? 0.5,
                                   ambient: values?.ambient ?? 0.5, piano: values?.piano ?? 0.5,
                                   tempo: values?.tempo ?? 100)
                motion.advance(date: date, level: Double(player.spatialSnapshot.level), speed: speed)
            }
        }
    }

    private func metalUniforms(primary: Color, secondary: Color) -> VisualWorldUniforms {
        func vector(_ color: Color) -> SIMD4<Float> {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
            // Lighting and reflection take place in linear RGB.
            func linear(_ x: CGFloat) -> Float { Float(x <= 0.04045 ? x / 12.92 : pow((x + 0.055) / 1.055, 2.4)) }
            return SIMD4(linear(r), linear(g), linear(b), 1)
        }
        var u = VisualWorldUniforms()
        let themeIndex: Float = switch style {
        case .photonSphere: 0
        case .lightGates: 2
        case .nightSky: 3
        case .twilight: 4
        case .plasmaSpark: 5
        case .visualizer: 6
        }
        u.viewport = SIMD4(1, 1, Float(simulation.clock), themeIndex)
        u.motion = SIMD4(0, 0, Float(simulation.excitation), Float(simulation.memory))
        u.sound = SIMD4(Float(simulation.bass), Float(simulation.mid), Float(simulation.treble), 0)
        func unit(_ value: Double?) -> Float { Float(VisualWorldDynamics.unit(value ?? 0.5)) }
        u.character = SIMD4(unit(values?.energy), unit(values?.aggressive), unit(values?.ambient), unit(values?.bright))
        u.material = SIMD4(unit(values?.dark), unit(values?.electronic), unit(values?.piano), Float(artworkColors?.dominantShare ?? 0.6))
        u.spatial = SIMD4(0, Float(simulation.beat), 0, 0)
        u.burst = SIMD4(Float(simulation.burstAge), Float(simulation.burstBass),
                        Float(simulation.burstMid), Float(simulation.burstTreble))
        if style == .plasmaSpark {
            let points = PlasmaSparkPattern.points(seed: player.visualWorldSeed,
                                                    serial: simulation.burstSerial,
                                                    mid: simulation.burstMid)
            let packed = stride(from: 0, to: 8, by: 2).map { index in
                SIMD4(Float(points[index].x), Float(points[index].y),
                      Float(points[index + 1].x), Float(points[index + 1].y))
            }
            u.plasma0 = packed[0]; u.plasma1 = packed[1]
            u.plasma2 = packed[2]; u.plasma3 = packed[3]
            u.plasma4 = SIMD4(Float(points[8].x), Float(points[8].y), 0, 0)
        }
        u.spatial.z = Float(simulation.burstSerial)
        if style == .visualizer {
            u.spatial.w = Float(VisualizerRipplePattern.index(
                bass: simulation.burstBass, mid: simulation.burstMid,
                treble: simulation.burstTreble, serial: simulation.burstSerial))
        }
        let value = sin(player.visualWorldSeed * 127.1 + 311.7) * 43758.5453
        u.layout.x = Float((value - floor(value)) * 2 * .pi)
        u.tonal = SIMD4(Float(simulation.tonalHeight), Float(simulation.confidence), Float(player.visualWorldSeed), 0)
        u.primary = vector(primary); u.secondary = vector(secondary)
        u.accent = artworkColors.map { vector(color($0.accent)) } ?? (u.primary * 0.35 + u.secondary * 0.65)
        func band(_ offset: Int) -> SIMD4<Float> {
            SIMD4(simulation.bands[offset], simulation.bands[offset+1], simulation.bands[offset+2], simulation.bands[offset+3])
        }
        u.band0 = band(0); u.band1 = band(4); u.band2 = band(8)
        u.band3 = band(12); u.band4 = band(16); u.band5 = band(20)
        func wave(_ offset: Int) -> SIMD4<Float> {
            SIMD4(simulation.waveform[offset], simulation.waveform[offset+1],
                  simulation.waveform[offset+2], simulation.waveform[offset+3])
        }
        u.wave0 = wave(0); u.wave1 = wave(4); u.wave2 = wave(8); u.wave3 = wave(12)
        u.wave4 = wave(16); u.wave5 = wave(20); u.wave6 = wave(24); u.wave7 = wave(28)
        u.wave8 = wave(32); u.wave9 = wave(36); u.wave10 = wave(40); u.wave11 = wave(44)
        return u
    }

    private func color(_ rgb: VisualWorldRGB) -> Color {
        Color(.sRGB, red: rgb.red, green: rgb.green, blue: rgb.blue, opacity: 1)
    }
}
