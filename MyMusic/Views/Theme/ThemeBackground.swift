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
                        Canvas { context, size in
                            for index in 0..<32 {
                                let x = CGFloat((index * 73 + 19) % 307) / 307 * size.width
                                let y = CGFloat((index * 113 + 31) % 397) / 397 * size.height
                                let diameter: CGFloat = index % 9 == 0 ? 1.8 : 0.8
                                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: diameter, height: diameter)),
                                             with: .color(.white.opacity(index % 9 == 0 ? 0.20 : 0.07)))
                            }
                        }
                    } else if theme == .pulseNeon {
                        PulseNeonLighting(palette: palette)
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
            .toolbarBackground(ThemePalette.resolve(theme).base, for: .navigationBar)
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
                    colors: [palette.accent.opacity(contrast == .increased ? 0.65 : (theme == .pulseNeon ? 0.85 : 0.26)), .clear, palette.light.opacity(theme == .pulseNeon ? 0.48 : 0.12)],
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
