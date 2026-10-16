import SwiftUI

/// A decorative accent for highly rated tracks; never participates in button interaction.
struct PreferenceSparklesView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            Group {
                if !reduceMotion && scenePhase == .active {
                    sparkles(size: geometry.size)
                        .phaseAnimator([false, true]) { content, glowing in
                            content
                                .opacity(glowing ? 1 : 0.25)
                                .scaleEffect(glowing ? 1.08 : 0.92)
                        } animation: { glowing in
                            .easeInOut(duration: glowing ? 1.1 : 1.6)
                        }
                } else {
                    sparkles(size: geometry.size)
                        .opacity(0.65)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func sparkles(size: CGSize) -> some View {
        ZStack {
            Image(systemName: "sparkle")
                .font(.system(size: 9, weight: .medium))
                .position(x: size.width * 0.12, y: size.height * 0.15)
            Image(systemName: "sparkle")
                .font(.system(size: 6, weight: .medium))
                .position(x: size.width * 0.88, y: size.height * 0.65)
            Image(systemName: "sparkle")
                .font(.system(size: 7, weight: .medium))
                .position(x: size.width * 0.25, y: size.height * 0.9)
        }
        .foregroundStyle(.yellow)
        .shadow(color: .orange.opacity(0.5), radius: 2)
    }
}
