import SwiftUI

/// Static mobile composition: no timers, offscreen animation, images or per-row blur.
struct ThemeBackground: View {
    let theme: AppTheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        let palette = ThemePalette.resolve(theme)
        GeometryReader { proxy in
            ZStack {
                palette.base
                if theme != .simpleDark && !reduceTransparency && contrast != .increased {
                    RadialGradient(colors: [palette.light.opacity(palette.atmosphere), .clear],
                                   center: UnitPoint(x: 0.05, y: 0), startRadius: 0,
                                   endRadius: min(proxy.size.width * 1.1, proxy.size.height * 0.55))
                    RadialGradient(colors: [palette.accent.opacity(palette.atmosphere * 0.5), .clear],
                                   center: .bottomTrailing, startRadius: 0, endRadius: proxy.size.width * 0.65)
                    if theme == .blueCosmos {
                        CosmosStarField()
                    } else if theme == .pulseNeon {
                        PulseNeonLighting(palette: palette)
                    } else if theme == .livingAurora {
                        AuroraGradientLighting(palette: palette)
                    }
                }
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ThemeScreenModifier: ViewModifier {
    @Environment(\.appTheme) private var theme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background { ThemeBackground(theme: theme) }
            .toolbarBackground(
                LinearGradient(stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black.opacity(0.92), location: 0.35),
                    .init(color: .black.opacity(0.45), location: 0.75),
                    .init(color: .clear, location: 1)
                ], startPoint: .top, endPoint: .bottom),
                for: .navigationBar
            )
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

private struct ThemeSurfaceModifier: ViewModifier {
    @Environment(\.appTheme) private var theme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        let palette = ThemePalette.resolve(theme)
        let shape = RoundedRectangle(cornerRadius: palette.radius, style: .continuous)
        content
            .background(palette.surface.opacity(reduceTransparency ? 1 : 0.94), in: shape)
            .overlay {
                if theme != .simpleDark {
                shape.strokeBorder(LinearGradient(
                    colors: [palette.accent.opacity(contrast == .increased ? 0.65 : (theme == .pulseNeon ? 0.38 : 0.26)), .clear, palette.light.opacity(theme == .pulseNeon ? 0.20 : 0.12)],
                    startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                    .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    func themeScreen() -> some View { modifier(ThemeScreenModifier()) }
    func themeSurface() -> some View { modifier(ThemeSurfaceModifier()) }
}
