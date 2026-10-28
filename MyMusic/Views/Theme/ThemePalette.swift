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
            Self(title: "Living Aurora", subtitle: "幾重にも流れる、極夜の光", symbol: "sparkles",
                 base: .black, surface: Color(hex: 0x101116),
                 accent: Color(hex: 0x75E3DE), light: Color(hex: 0x9376EE), radius: 22, atmosphere: 0.12)
        case .pulseNeon:
            Self(title: "Pulse Neon", subtitle: "重なる光学ガラスと、細い光", symbol: "waveform.path",
                 base: .black, surface: Color(hex: 0x0D1114),
                 accent: Color(hex: 0x7FFFA6), light: Color(hex: 0x19B879), radius: 12, atmosphere: 0.14)
        case .amberLounge:
            Self(title: "Amber Lounge", subtitle: "琥珀の灯りで、音にくつろぐ", symbol: "flame",
                 base: .black, surface: Color(hex: 0x17120D),
                 accent: Color(hex: 0xF2C078), light: Color(hex: 0xA76A31), radius: 22, atmosphere: 0.12)
        case .reimei:
            Self(title: "黎明", subtitle: "夜がほどけ、音が目覚める", symbol: "sunrise",
                 base: .black, surface: Color(hex: 0x12141A),
                 accent: Color(hex: 0xE7B5A4), light: Color(hex: 0x8F94AD), radius: 20, atmosphere: 0.08)
        case .sumiWashi:
            Self(title: "墨和紙", subtitle: "墨の余白に、音を聴く", symbol: "square.on.square",
                 base: .black, surface: Color(hex: 0x141414),
                 accent: Color(hex: 0xD8D8D8), light: Color(hex: 0x8D8D8D), radius: 20, atmosphere: 0.08)
        case .blueCosmos:
            Self(title: "Blue Cosmos", subtitle: "天の川の奥へ、星をたどる", symbol: "moon.stars",
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
