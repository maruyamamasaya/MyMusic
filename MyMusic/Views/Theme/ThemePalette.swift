import SwiftUI

/// The single source of truth for theme art direction. See Documentation/Themes.md.
struct ThemePalette {
    let title: String
    let subtitle: String
    let symbol: String
    let base: Color
    let surface: Color
    let accent: Color
    let light: Color
    let radius: CGFloat
    let atmosphere: Double

    static func resolve(_ theme: AppTheme) -> Self {
        switch theme {
        case .simpleDark:
            Self(title: "シンプルダーク", subtitle: "音楽とアートワークが主役", symbol: "moon.fill",
                 base: .black, surface: Color(hex: 0x1C1C1E),
                 accent: .accentColor, light: .clear, radius: 20, atmosphere: 0)
        case .livingAurora:
            Self(title: "Living Aurora", subtitle: "柔らかな光に包まれる", symbol: "sparkles",
                 base: .black, surface: Color(hex: 0x101116),
                 accent: Color(hex: 0x75E3DE), light: Color(hex: 0x9376EE), radius: 22, atmosphere: 0.12)
        case .pulseNeon:
            Self(title: "Pulse Neon", subtitle: "闇を切り裂く、光のビート", symbol: "waveform.path",
                 base: .black, surface: Color(hex: 0x0D1114),
                 accent: Color(hex: 0x63E6F5), light: Color(hex: 0x4263FF), radius: 12, atmosphere: 0.38)
        case .blueCosmos:
            Self(title: "Blue Cosmos", subtitle: "静かな夜空へ、深く", symbol: "moon.stars",
                 base: .black, surface: Color(hex: 0x0E121A),
                 accent: Color(hex: 0xA4CCFF), light: Color(hex: 0x3F6FBE), radius: 24, atmosphere: 0.11)
        }
    }
}

extension Color {
    fileprivate init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

private struct AppThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .livingAurora
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[AppThemeKey.self] }
        set { self[AppThemeKey.self] = newValue }
    }
}
