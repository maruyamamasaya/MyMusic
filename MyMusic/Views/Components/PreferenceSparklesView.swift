import SwiftUI

/// Presentation only: the stored rating may exceed the selection weight ceiling.
struct PreferenceSparklesView: View {
    var level = 5

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false

    private var animates: Bool { !reduceMotion && scenePhase == .active && isVisible }
    private var stage: Int { min(15, max(8, level)) - 7 }

    var body: some View {
        GeometryReader { geometry in
            if level >= 8 {
                let overflow = CGFloat(4 + stage * 2)
                TimelineView(.animation(minimumInterval: 1.0 / 30, paused: !animates)) { timeline in
                    let time = animates ? timeline.date.timeIntervalSinceReferenceDate : 0
                    Canvas { context, size in
                        drawCelebration(context: &context, size: size, time: time)
                    }
                }
                .frame(width: geometry.size.width + overflow * 2,
                       height: geometry.size.height + overflow * 2)
                .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            } else if animates {
                sparkles(size: geometry.size)
                    .phaseAnimator([false, true]) { content, glowing in
                        content.opacity(glowing ? 1 : 0.25)
                            .scaleEffect(glowing ? 1.08 : 0.92)
                    } animation: { glowing in
                        .easeInOut(duration: glowing ? 1.1 : 1.6)
                    }
            } else {
                sparkles(size: geometry.size).opacity(0.65)
            }
        }
        .onAppear { isVisible = true }
        .onDisappear { isVisible = false }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawCelebration(context: inout GraphicsContext, size: CGSize, time: Double) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let radius = min(size.width, size.height) * 0.38
        let count = 5 + stage * 2
        let rotation = time * (0.18 + Double(stage) * 0.025)
        // Soft light stays behind the stars; the control's hit area never grows.
        let glow = CGRect(x: center.x - radius, y: center.y - radius,
                          width: radius * 2, height: radius * 2)
        context.fill(Path(ellipseIn: glow), with: .radialGradient(
            Gradient(colors: [.yellow.opacity(0.05 + Double(stage) * 0.018), .clear]),
            center: center, startRadius: 0, endRadius: radius))

        if stage >= 3 {
            for ring in 0..<(1 + (stage - 3) / 2) {
                let ringRadius = radius * (0.72 + Double(ring) * 0.13)
                let arc = Path { path in
                    path.addArc(center: center, radius: ringRadius,
                                startAngle: .radians(rotation + Double(ring) * 2.1),
                                endAngle: .radians(rotation + Double(ring) * 2.1 + 1.3 + Double(stage) * 0.12),
                                clockwise: false)
                }
                context.stroke(arc, with: .color(starColor(index: ring, time: time).opacity(0.5)),
                               lineWidth: 0.7 + Double(stage) * 0.1)
            }
        }
        for index in 0..<count {
            let angle = Double(index) / Double(count) * .pi * 2 + rotation
            let pulse = 0.5 + 0.5 * sin(time * 2.2 + Double(index) * 2.4)
            let orbit = radius * (index.isMultiple(of: 2) ? 1 : 0.78)
            let point = CGPoint(x: center.x + cos(angle) * orbit,
                                y: center.y + sin(angle) * orbit)
            let length = (2.2 + Double(stage) * 0.48) * (0.65 + pulse * 0.55)
            let star = Path { path in
                for vertex in 0..<8 {
                    let a = Double(vertex) * .pi / 4 + rotation * 0.25
                    let r = vertex.isMultiple(of: 2) ? length : length * 0.24
                    let p = CGPoint(x: point.x + cos(a) * r, y: point.y + sin(a) * r)
                    if vertex == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                path.closeSubpath()
            }
            let color = starColor(index: index, time: time)
            var halo = context
            halo.addFilter(.blur(radius: 1.5 + Double(stage) * 0.25))
            halo.fill(star, with: .color(color.opacity(0.45)))
            context.fill(star, with: .color(color.opacity(0.55 + pulse * 0.45)))
        }
    }

    private func starColor(index: Int, time: Double) -> Color {
        if stage < 4 { return index.isMultiple(of: 3) ? .white : .yellow }
        return Color(hue: (Double(index) * 0.137 + time * 0.035).truncatingRemainder(dividingBy: 1),
                     saturation: 0.5 + Double(stage) * 0.04, brightness: 1)
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
