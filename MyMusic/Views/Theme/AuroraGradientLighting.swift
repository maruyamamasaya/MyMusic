import SwiftUI

/// Broad overlapping light curtains fade back into the shared pure-black foundation.
struct AuroraGradientLighting: View {
    let palette: ThemePalette

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                EllipticalGradient(colors: [.clear, palette.light.opacity(0.30), .clear],
                                   center: UnitPoint(x: 0.12, y: 0.15),
                                   startRadiusFraction: 0.02, endRadiusFraction: 0.75)
                EllipticalGradient(colors: [palette.accent.opacity(0.21), Color.blue.opacity(0.10), .clear],
                                   center: UnitPoint(x: 0.85, y: 0.38),
                                   startRadiusFraction: 0, endRadiusFraction: 0.65)
                LinearGradient(stops: [
                    .init(color: .clear, location: 0.15),
                    .init(color: palette.light.opacity(0.10), location: 0.40),
                    .init(color: palette.accent.opacity(0.12), location: 0.52),
                    .init(color: .clear, location: 0.72)
                ], startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .mask(LinearGradient(colors: [.white, .white.opacity(0.65), .clear],
                                 startPoint: .top, endPoint: .bottom))
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
