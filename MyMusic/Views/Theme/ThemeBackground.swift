import SwiftUI

/// Bundled photographic textures; no timers, motion sensors or per-row blur.
struct ThemeBackground: View {
    let theme: AppTheme
    var extendsIntoSafeArea = true
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.themeBackgroundViewport) private var viewport

    private var textureAsset: String? {
        switch theme {
        case .simpleDark: nil
        case .livingAurora: "ThemeTextureAurora"
        case .pulseNeon: "ThemeTextureNeon"
        case .blueCosmos: "ThemeTextureCosmos"
        case .amberLounge: "ThemeTextureAmber"
        case .sumiWashi: "ThemeTextureSumi"
        case .reimei: "ThemeTextureReimei"
        }
    }

    var body: some View {
        if extendsIntoSafeArea {
            composition.ignoresSafeArea()
        } else {
            composition
        }
    }

    private var composition: some View {
        let palette = ThemePalette.resolve(theme)
        return GeometryReader { proxy in
            let localFrame = proxy.frame(in: .global)
            let source = viewport ?? localFrame
            ZStack(alignment: .topLeading) {
                palette.base
                if theme != .simpleDark && !reduceTransparency && contrast != .increased {
                    if let texture = textureAsset {
                        Image(texture)
                            .resizable()
                            .saturation(theme == .sumiWashi ? 0 : 1)
                            .hueRotation(.degrees(theme == .pulseNeon ? -65 : 0))
                            .scaledToFill()
                            .frame(width: source.width, height: source.height)
                            .clipped()
                            .overlay {
                                Color.black.opacity(0.20)
                            }
                            .offset(x: source.minX - localFrame.minX, y: source.minY - localFrame.minY)
                    }
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .topLeading)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct ThemeScreenModifier: ViewModifier {
    @Environment(\.appTheme) private var theme

    @Environment(\.themeBackgroundViewport) private var viewport
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background { ThemeBackground(theme: theme) }
            .toolbarBackground(
                ThemeNavigationBackground.style(theme: theme, viewport: viewport?.size,
                                                opaque: reduceTransparency || contrast == .increased),
                for: .navigationBar
            )
            .toolbarBackground(.visible, for: .navigationBar)
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


private struct ThemeBackgroundViewportKey: EnvironmentKey {
    static let defaultValue: CGRect? = nil
}

extension EnvironmentValues {
    var themeBackgroundViewport: CGRect? {
        get { self[ThemeBackgroundViewportKey.self] }
        set { self[ThemeBackgroundViewportKey.self] = newValue }
    }
}
