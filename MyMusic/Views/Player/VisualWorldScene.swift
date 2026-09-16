import SwiftUI

/// Bounded procedural geometry; no audio operations, assets, random allocation or full-screen blur.
struct VisualWorldScene: View {
    let theme: AppTheme
    let primary: Color
    let secondary: Color
    let motion: VisualWorldDynamics
    var energy = 0.5
    var ambient = 0.5
    var brightness = 0.5
    var subdued = false

    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
            var light = context
            light.blendMode = .plusLighter
            light.opacity = subdued ? 0.28 : (theme == .simpleDark ? 0.62 : 1)
            atmosphere(context: &light, size: size)
            switch theme {
            case .livingAurora, .simpleDark: ribbons(context: &light, size: size)
            case .pulseNeon: portals(context: &light, size: size)
            case .blueCosmos: orbits(context: &light, size: size)
            }
        }
        .accessibilityHidden(true)
    }

    private var t: Double { motion.time }
    private var intensity: Double { 0.45 + brightness * 0.2 + motion.level * 0.45 + motion.impulse * 0.2 }

    private func atmosphere(context: inout GraphicsContext, size: CGSize) {
        let w = size.width, h = size.height
        let centers = [
            CGPoint(x: w * (0.4 + sin(t * 0.3) * 0.22 + motion.balance * 0.12), y: h * 0.35),
            CGPoint(x: w * (0.65 + cos(t * 0.23) * 0.2), y: h * 0.65)
        ]
        for i in 0..<2 {
            let radius = w * (0.8 + motion.width * 0.35)
            context.fill(Path(ellipseIn: CGRect(x: centers[i].x - radius, y: centers[i].y - radius,
                                               width: radius * 2, height: radius * 2)),
                         with: .radialGradient(Gradient(colors: [(i == 0 ? primary : secondary).opacity(0.22 * intensity), .clear]),
                                               center: centers[i], startRadius: 0, endRadius: radius))
        }
    }

    private func ribbonPoint(_ u: Double, strand: Double, bundle: Int, size: CGSize) -> CGPoint {
        let w = size.width, h = size.height
        let offset = Double(bundle) * 1.65
        let wave = sin(u * 5.0 + t * 0.63 + offset)
        let fold = sin(u * 10.5 - t * 0.85 + offset) * (0.035 + energy * 0.035)
        let separation = strand * (0.025 + 0.08 * pow(sin(u * .pi + t * 0.22), 2))
        let expansion = 1 + motion.width * 0.3 + motion.impulse * 0.13
        return CGPoint(
            x: w * (-0.28 + u * 1.56 + motion.balance * 0.13),
            y: h * (0.43 + wave * 0.20 * expansion + fold + separation + Double(bundle - 1) * 0.065)
        )
    }

    private func ribbons(context: inout GraphicsContext, size: CGSize) {
        let bundles = theme == .simpleDark ? 2 : 3
        for bundle in 0..<bundles {
            for strand in 0..<12 {
                let lane = Double(strand) / 11 - 0.5
                var path = Path()
                for step in 0...72 {
                    let point = ribbonPoint(Double(step) / 72, strand: lane, bundle: bundle, size: size)
                    if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                let colors = bundle == 1 ? [secondary, primary] : [primary, secondary]
                let shading = GraphicsContext.Shading.linearGradient(
                    Gradient(colors: [colors[0].opacity(0.05), colors[0], colors[1], colors[1].opacity(0.05)]),
                    startPoint: CGPoint(x: 0, y: size.height * 0.3),
                    endPoint: CGPoint(x: size.width, y: size.height * 0.65))
                if strand % 4 == 0 {
                    var halo = context
                    halo.opacity *= 0.08 * intensity
                    halo.stroke(path, with: shading, style: StrokeStyle(lineWidth: 19 + motion.level * 14, lineCap: .round))
                    halo.opacity *= 1.6
                    halo.stroke(path, with: shading, lineWidth: 6)
                }
                var filament = context
                filament.opacity *= (0.25 + Double(strand % 4) * 0.12) * intensity
                filament.stroke(path, with: shading, lineWidth: strand % 3 == 0 ? 1.6 : 0.7)
                let head = (t * 0.16 + Double(strand) * 0.041 + Double(bundle) * 0.29).truncatingRemainder(dividingBy: 1)
                filament.opacity *= 0.75
                filament.stroke(path.trimmedPath(from: max(head - 0.1, 0), to: head),
                                with: .color(.white.opacity(0.65)), lineWidth: 1)
            }
        }
        for index in 0..<70 {
            let u = (fraction(index * 37) + t * (0.055 + fraction(index * 13) * 0.035)).truncatingRemainder(dividingBy: 1)
            let point = ribbonPoint(u, strand: fraction(index * 17) * 2 - 1, bundle: index % bundles, size: size)
            let opacity = sin(u * .pi) * (0.25 + fraction(index * 23) * 0.5)
            dot(context: &context, point: point, radius: 0.8 + fraction(index * 11) * 1.2,
                color: index % 3 == 0 ? .white : secondary, opacity: opacity)
        }
    }

    private func portals(context: inout GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width * (0.5 + sin(t * 0.3) * 0.12 + motion.balance * 0.1),
                             y: size.height * (0.43 + cos(t * 0.21) * 0.065))
        for ring in 0..<14 {
            let depth = (Double(ring) / 14 + t * (0.065 + energy * 0.035)).truncatingRemainder(dividingBy: 1)
            let scale = 0.09 + pow(depth, 2.1) * 2.3
            let radius = size.width * scale * (1 + motion.impulse * 0.16)
            let rotation = t * 0.15 + Double(ring) * 0.13
            var path = Path()
            for vertex in 0...6 {
                let angle = Double(vertex) / 6 * .pi * 2 + rotation
                let point = CGPoint(x: center.x + cos(angle) * radius * (1 + motion.width * 0.3),
                                    y: center.y + sin(angle) * radius * 1.18)
                if vertex == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            let alpha = min(depth * 5, 1) * min((1 - depth) * 5, 1)
            let color = ring % 3 == 0 ? primary : secondary
            var ringContext = context
            ringContext.opacity *= alpha * intensity
            ringContext.stroke(path, with: .color(color.opacity(0.055)), lineWidth: 20)
            ringContext.stroke(path, with: .color(color.opacity(0.22)), lineWidth: 3)
            ringContext.stroke(path, with: .color(color.opacity(0.7)), lineWidth: 0.8)
            let head = (t * 0.15 + Double(ring) * 0.12).truncatingRemainder(dividingBy: 1)
            ringContext.stroke(path.trimmedPath(from: max(0, head - 0.16), to: head),
                               with: .color(.white.opacity(0.75)), lineWidth: 1.2)
        }
        for index in 0..<60 {
            let depth = (fraction(index * 19) + t * 0.08).truncatingRemainder(dividingBy: 1)
            let angle = fraction(index * 43) * .pi * 2 + t * 0.09
            let radius = pow(depth, 2) * size.height * 0.9
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            dot(context: &context, point: point, radius: 0.5 + depth * 1.6,
                color: secondary, opacity: sin(depth * .pi) * 0.65)
        }
    }

    private func orbitPoint(angle: Double, ring: Double, size: CGSize) -> (CGPoint, Double) {
        let a = angle + t * (0.2 + ring * 0.01)
        let radius = size.width * (0.29 + ring * 0.009) * (1 + motion.width * 0.4 + motion.impulse * 0.14)
        let z = sin(a) * 0.65
        let tilt = -0.48 + sin(t * 0.16) * 0.32
        let x = cos(a) * radius
        let y = sin(a) * radius * (0.5 + ambient * 0.3)
        let perspective = 1 / (1 - z * 0.3)
        let point = CGPoint(x: size.width * (0.5 + motion.balance * 0.1) + (x * cos(tilt) - y * sin(tilt)) * perspective,
                            y: size.height * 0.45 + (x * sin(tilt) + y * cos(tilt)) * perspective)
        return (point, z)
    }

    private func orbits(context: inout GraphicsContext, size: CGSize) {
        for index in 0..<100 {
            let depth = fraction(index * 13)
            let x = (fraction(index * 53) + sin(t * 0.07) * (0.03 + depth * 0.035) + 1).truncatingRemainder(dividingBy: 1)
            let y = (fraction(index * 31) + t * (0.003 + depth * 0.009)).truncatingRemainder(dividingBy: 1)
            dot(context: &context, point: CGPoint(x: x * size.width, y: y * size.height),
                radius: 0.4 + depth, color: .white, opacity: 0.12 + depth * 0.35)
        }
        for ring in 0..<28 {
            var path = Path()
            for step in 0...90 {
                let angle = Double(step) / 90 * .pi * 2
                let (point, _) = orbitPoint(angle: angle, ring: Double(ring), size: size)
                if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            let color = ring % 4 == 0 ? primary : secondary
            if ring % 5 == 0 { context.stroke(path, with: .color(color.opacity(0.055 * intensity)), lineWidth: 15) }
            context.stroke(path, with: .color(color.opacity((0.12 + motion.level * 0.16) * intensity)), lineWidth: 0.7)
        }
        for index in 0..<135 {
            let ring = fraction(index * 47) * 28
            let angle = fraction(index * 29) * .pi * 2 + t * (0.2 + fraction(index * 11) * 0.35)
            let (point, z) = orbitPoint(angle: angle, ring: ring, size: size)
            dot(context: &context, point: point, radius: 0.65 + (z + 1) * 0.9,
                color: index % 5 == 0 ? .white : (index % 2 == 0 ? primary : secondary),
                opacity: (0.35 + (z + 1) * 0.23) * intensity)
        }
    }

    private func dot(context: inout GraphicsContext, point: CGPoint, radius: Double, color: Color, opacity: Double) {
        let shape = Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
        context.fill(shape, with: .color(color.opacity(min(opacity, 1))))
        if radius > 1.5 {
            let halo = Path(ellipseIn: CGRect(x: point.x - radius * 3, y: point.y - radius * 3, width: radius * 6, height: radius * 6))
            context.fill(halo, with: .radialGradient(Gradient(colors: [color.opacity(opacity * 0.22), .clear]), center: point, startRadius: 0, endRadius: radius * 3))
        }
    }

    private func fraction(_ seed: Int) -> Double {
        (Double(seed + 1) * 0.61803398875).truncatingRemainder(dividingBy: 1)
    }
}
