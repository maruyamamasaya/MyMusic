import SwiftUI

/// Pulse-only light sculpture. Fixed geometry keeps black breathing space between two rails.
/// Layered strokes simulate bloom without blur or continuous GPU animation.
struct PulseNeonLighting: View {
    let palette: ThemePalette

    private enum Light {
        static let haloWidth: CGFloat = 30
        static let haloOpacity = 0.045
        static let bloomWidth: CGFloat = 12
        static let bloomOpacity = 0.13
        static let tubeWidth: CGFloat = 3
        static let coreWidth: CGFloat = 0.8
        static let nodeRadius: CGFloat = 2.5
    }

    var body: some View {
        Canvas { context, size in
            let rails: [(points: [CGPoint], color: Color)] = [
                ([CGPoint(x: size.width * 0.76, y: -16),
                  CGPoint(x: size.width * 0.93, y: size.height * 0.19),
                  CGPoint(x: size.width * 0.93, y: size.height * 0.43),
                  CGPoint(x: size.width + 16, y: size.height * 0.52)], palette.accent),
                ([CGPoint(x: -16, y: size.height * 0.55),
                  CGPoint(x: size.width * 0.065, y: size.height * 0.64),
                  CGPoint(x: size.width * 0.065, y: size.height * 0.81),
                  CGPoint(x: size.width * 0.24, y: size.height + 16)], palette.light)
            ]
            for rail in rails {
                var path = Path()
                path.addLines(rail.points)
                context.stroke(path, with: .color(rail.color.opacity(Light.haloOpacity)),
                               style: StrokeStyle(lineWidth: Light.haloWidth, lineJoin: .round))
                context.stroke(path, with: .color(rail.color.opacity(Light.bloomOpacity)),
                               style: StrokeStyle(lineWidth: Light.bloomWidth, lineJoin: .round))
                context.stroke(path, with: .color(rail.color.opacity(0.9)),
                               style: StrokeStyle(lineWidth: Light.tubeWidth, lineJoin: .bevel))
                context.stroke(path, with: .color(.white.opacity(0.85)),
                               style: StrokeStyle(lineWidth: Light.coreWidth, lineJoin: .bevel))
                let node = rail.points[1]
                context.fill(Path(ellipseIn: CGRect(x: node.x - Light.nodeRadius,
                                                    y: node.y - Light.nodeRadius,
                                                    width: Light.nodeRadius * 2,
                                                    height: Light.nodeRadius * 2)), with: .color(.white))
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
