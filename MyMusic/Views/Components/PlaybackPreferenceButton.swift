import SwiftUI

struct PlaybackPreferenceButton: View {
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore

    let track: Track
    let direction: Direction
    var compact = false

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
        playbackHistoryStore.playbackPreference(for: track.id)
    }

    private var level: Int {
        direction == .increase ? max(0, preference) : max(0, -preference)
    }

    private var isActive: Bool { level > 0 }

    var body: some View {
        Button(action: updatePreference) {
            ZStack(alignment: .topTrailing) {
                if isBursting {
                    Circle()
                        .stroke(effectColor.opacity(0.7), lineWidth: 2)
                        .frame(width: compact ? 28 : 36, height: compact ? 28 : 36)
                        .scaleEffect(1.65)
                        .opacity(0)
                        .transition(.identity)
                }

                preferenceImage
                    .font(compact ? .body : .title3)
                    .frame(width: compact ? 30 : 42, height: 36)
                    .symbolEffect(.bounce, value: effectTrigger)
                    .scaleEffect(isBursting ? 1.16 : 1)

                if isActive {
                    Text("\(level)")
                        .font(.system(size: compact ? 8 : 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 4)
                        .frame(minWidth: 16, minHeight: 16)
                        .background(effectColor, in: Capsule())
                        .offset(x: compact ? 2 : 0, y: -2)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light, intensity: min(1, 0.35 + Double(level) * 0.06)), trigger: effectTrigger)
        .accessibilityLabel(direction.accessibilityLabel)
        .accessibilityValue(preference == 0 ? "未評価" : "\(preference > 0 ? "プラス" : "マイナス")\(abs(preference))、10段階中")
    }

    @ViewBuilder
    private var preferenceImage: some View {
        let image = Image(systemName: isActive ? "\(direction.systemImage).fill" : direction.systemImage)

        if direction == .increase, level == PlaybackHistoryStore.maximumPreference {
            image.foregroundStyle(
                AngularGradient(
                    colors: [.red, .orange, .yellow, .green, .cyan, .blue, .purple, .pink, .red],
                    center: .center
                )
            )
        } else {
            image.foregroundStyle(isActive ? effectColor : .secondary)
        }
    }

    private var effectColor: Color {
        guard isActive else { return .secondary }
        let progress = Double(level) / Double(PlaybackHistoryStore.maximumPreference)
        if direction == .increase {
            return Color(
                hue: 0.56 + progress * 0.16,
                saturation: 0.45 + progress * 0.5,
                brightness: 0.72 + progress * 0.28
            )
        }
        return Color(
            hue: 0.055,
            saturation: 0.78 - progress * 0.53,
            brightness: 0.92 - progress * 0.27
        )
    }

    private func updatePreference() {
        if direction == .increase {
            playbackHistoryStore.increasePlaybackPreference(for: track.id)
        } else {
            playbackHistoryStore.decreasePlaybackPreference(for: track.id)
        }

        effectTrigger += 1
        withAnimation(.spring(response: 0.2, dampingFraction: 0.5)) {
            isBursting = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.easeOut(duration: 0.2)) {
                isBursting = false
            }
        }
    }
}
