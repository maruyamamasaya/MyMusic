import SwiftUI

struct HomeThemeCycleButton: View {
    @Environment(SettingsStore.self) private var settings

    private var themeNumber: Int {
        (AppTheme.allCases.firstIndex(of: settings.theme) ?? 0) + 1
    }

    var body: some View {
        Button {
            settings.cycleTheme()
        } label: {
            Text(themeNumber.formatted())
                .font(.subheadline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(ThemePalette.resolve(settings.theme).accent)
                .frame(width: 32, height: 32)
                .background(ThemePalette.resolve(settings.theme).surface, in: Circle())
                .overlay {
                    Circle().strokeBorder(ThemePalette.resolve(settings.theme).accent.opacity(0.65), lineWidth: 1)
                }
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("デザインテーマを切り替える")
        .accessibilityValue("\(themeNumber)、\(ThemePalette.resolve(settings.theme).title)")
        .accessibilityHint("タップすると次のテーマに切り替わります。4の次は1に戻ります")
    }
}
