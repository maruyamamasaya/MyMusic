import SwiftUI

struct HomeThemeCycleButton: View {
    @Environment(SettingsStore.self) private var settings
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private var themes: [AppTheme] { AppTheme.allCases }

    private var nextTheme: AppTheme {
        let index = themes.firstIndex(of: settings.theme) ?? 0
        return themes[(index + 1) % themes.count]
    }

    private func position(of theme: AppTheme) -> Int {
        let current = themes.firstIndex(of: settings.theme) ?? 0
        let index = themes.firstIndex(of: theme) ?? 0
        return (index - current + themes.count) % themes.count
    }

    private func iconAsset(for theme: AppTheme) -> String {
        switch theme {
        case .simpleDark: "ThemeIconDark"
        case .livingAurora: "ThemeIconAurora"
        case .pulseNeon: "ThemeIconPulse"
        case .blueCosmos: "ThemeIconCosmos"
        case .amberLounge: "ThemeIconAmber"
        case .sumiWashi: "ThemeIconSumi"
        case .reimei: "ThemeIconReimei"
        }
    }

    var body: some View {
        Button {
            settings.cycleTheme()
        } label: {
            ZStack {
                ForEach(themes) { theme in
                    let slot = position(of: theme)
                    let isCurrent = slot == 0
                    Image(iconAsset(for: theme))
                        .resizable()
                        .scaledToFit()
                        .frame(width: 23, height: 23)
                        .opacity(isCurrent ? 0.95 : 0.55)
                        .frame(width: 32, height: 32)
                        .background {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(.background.opacity(reduceTransparency ? 1 : (isCurrent ? 0.78 : 0.38)))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(.primary.opacity(isCurrent ? 0.24 : 0.12), lineWidth: 0.75)
                        }
                        .shadow(color: .black.opacity(isCurrent ? 0.16 : 0.04), radius: 3, x: 0, y: 2)
                        .scaleEffect(isCurrent ? 1 : 0.76)
                        .rotation3DEffect(.degrees(isCurrent ? -8 : -18), axis: (x: 0, y: 1, z: 0))
                        .offset(x: isCurrent ? -10 : (slot == 1 ? 13 : -21), y: isCurrent ? 3 : -5)
                        .opacity(slot < 2 ? 1 : 0)
                        .zIndex(isCurrent ? 2 : (slot == 1 ? 1 : 0))
                }
            }
            .frame(width: 62, height: 44)
            .contentShape(Rectangle())
            .animation(reduceMotion ? nil : .spring(response: 0.46, dampingFraction: 0.86), value: settings.theme)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("デザインテーマを切り替える")
        .accessibilityValue(ThemePalette.resolve(settings.theme).title)
        .accessibilityHint("タップすると\(ThemePalette.resolve(nextTheme).title)に切り替わります")
    }
}
