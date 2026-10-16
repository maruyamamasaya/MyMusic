import SwiftUI

struct PlaybackPreferenceButton: View {
    @Environment(TrackPreferenceStore.self) private var preferenceStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let track: Track
    let direction: Direction
    var compact = false
    var circularBackground = false

    @State private var effectTrigger = 0
    @State private var isBursting = false

    enum Direction {
        case decrease
        case increase

        var adjustment: Int { self == .increase ? 1 : -1 }
        var systemImage: String { self == .increase ? "hand.thumbsup" : "hand.thumbsdown" }
        var accessibilityLabel: String { self == .increase ? "再生頻度を増やす" : "再生頻度を減らす" }
    }

    private var preference: Int {
        preferenceStore.playbackPreference(for: track.id)
    }

    private var level: Int {
        direction == .increase ? max(0, preference) : max(0, -preference)
    }

    private var isActive: Bool { level > 0 }

    var body: some View {
        Button(action: updatePreference) {
            ZStack(alignment: .topTrailing) {

                preferenceImage
                    .font(compact ? .body : .title3)
                    .frame(width: compact ? 30 : 42, height: 36)
                    .symbolEffect(.bounce, options: .speed(1.5), value: effectTrigger)
                    .scaleEffect(isBursting && !reduceMotion ? (direction == .increase && level >= 8 ? 1.24 + Double(level - 7) * 0.025 : 1.24) : 1)

                if isActive {
                    Text("\(level)")
                        .font(.system(size: compact ? 8 : 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(usesGradient ? AnyShapeStyle(effectGradient) : AnyShapeStyle(effectColor), in: Capsule())
                        .offset(x: compact ? 2 : 0, y: -2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
        }
        .overlay {
            if direction == .increase && level >= 5 {
                PreferenceSparklesView(level: level)
            }
        }
        .overlay {
            if !reduceMotion && direction == .increase && level >= 8 {
                Circle()
                    .stroke(effectGradient, lineWidth: 1.5 + Double(level - 7) * 0.2)
                    .frame(width: compact ? 28 : 36, height: compact ? 28 : 36)
                    .keyframeAnimator(initialValue: 1.0, trigger: effectTrigger) { content, progress in
                        content
                            .scaleEffect(1 + progress * (0.5 + Double(level - 7) * 0.13))
                            .opacity(1 - progress)
                    } keyframes: { _ in
                        MoveKeyframe(0)
                        LinearKeyframe(1, duration: 0.55 + Double(level - 7) * 0.035)
                    }
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .disabled(preferenceStore.isImporting)
        .buttonStyle(PreferenceButtonStyle(circular: circularBackground))
        .sensoryFeedback(.impact(weight: .light, intensity: min(1, 0.35 + Double(level) * 0.06)), trigger: effectTrigger)
        .accessibilityLabel(direction.accessibilityLabel)
        .accessibilityValue(preference == 0 ? "未評価" : "\(preference > 0 ? "プラス" : "マイナス")\(abs(preference))、上限15、選曲への効果は10で最大")
    }

    @ViewBuilder
    private var preferenceImage: some View {
        let image = Image(systemName: isActive ? "\(direction.systemImage).fill" : direction.systemImage)

        if usesGradient {
            image.foregroundStyle(effectGradient)
        } else {
            image.foregroundStyle(isActive ? effectColor : .secondary)
        }
    }

    private var usesGradient: Bool { direction == .increase && level >= 3 }

    private var effectGradient: AngularGradient {
        AngularGradient(colors: gradientColors, center: .center)
    }

    private var gradientColors: [Color] {
        switch min(level, 10) {
        case 3: [.cyan, .teal, .blue, .cyan]
        case 4: [.green, .mint, .cyan, .green]
        case 5: [.yellow, .green, .orange, .yellow]
        case 6: [.orange, .yellow, .red, .orange]
        case 7: [.pink, .red, .purple, .pink]
        case 8: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .red]
        case 9: [.pink, .red, .orange, .yellow, .green, .mint, .cyan, .blue, .indigo, .purple, .pink]
        case 10: [.red, .orange, .yellow, .green, .mint, .cyan, .blue, .indigo, .purple, .pink, .red]
        default: [effectColor, effectColor]
        }
    }

    private var effectColor: Color {
        guard isActive else { return .secondary }
        let progress = Double(min(level, 10)) / 10
        if direction == .increase {
            return Color(
                hue: 0.56 + progress * 0.16,
                saturation: 0.45 + progress * 0.5,
                brightness: 0.72 + progress * 0.28
            )
        }
        return Color(
            hue: 0.60,
            saturation: 0.40 + progress * 0.55,
            brightness: 0.96 - progress * 0.38
        )
    }

    private func updatePreference() {
        if direction == .increase {
            preferenceStore.increasePlaybackPreference(for: track.id)
        } else {
            preferenceStore.decreasePlaybackPreference(for: track.id)
        }

        effectTrigger += 1
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            isBursting = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.easeOut(duration: 0.38)) {
                isBursting = false
            }
        }
    }
}

private struct PreferenceButtonStyle: ButtonStyle {
    let circular: Bool

    func makeBody(configuration: Configuration) -> some View {
        if circular {
            configuration.label
                .frame(width: 42, height: 42)
                .background(.ultraThinMaterial, in: Circle())
                .opacity(configuration.isPressed ? 0.65 : 1)
                .scaleEffect(configuration.isPressed ? 0.94 : 1)
        } else {
            configuration.label
        }
    }
}
