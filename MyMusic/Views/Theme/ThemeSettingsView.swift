import SwiftUI

struct ThemeSettingsView: View {
    var body: some View {
        ScrollView {
            ThemeCatalogView()
        }
        .themeScreen()
        .navigationTitle("テーマ")
        .navigationBarTitleDisplayMode(.inline)
    }

}

/// Shared with offscreen rendering checks; ScrollView is verified in Simulator.
struct ThemeCatalogView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
            VStack(alignment: .leading, spacing: 20) {
                Text("音楽を聴く空間を選ぶ")
                    .font(.title2.weight(.semibold))
                Text("シンプルな黒から、ほのかな光のある空間まで。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                ForEach(AppTheme.allCases) { theme in
                    themeCard(theme)
                }
                Text("選択は自動保存され、すべての画面に反映されます。端末の外観設定にかかわらず、各テーマ固有の配色を使用します。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(20)
    }

    private func themeCard(_ theme: AppTheme) -> some View {
        let palette = ThemePalette.resolve(theme)
        let selected = settings.theme == theme
        return Button {
            settings.setTheme(theme)
        } label: {
            VStack(alignment: .leading, spacing: 22) {
                HStack {
                    Image(systemName: palette.symbol).font(.title2).foregroundStyle(palette.accent)
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.title2).foregroundStyle(selected ? palette.accent : .secondary)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(palette.title).font(.title2.weight(.semibold))
                    Text(palette.subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    Image(systemName: "music.note").font(.title3).foregroundStyle(palette.accent)
                        .frame(width: 44, height: 44)
                        .background(palette.light.opacity(0.16), in: RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("MyMusic").font(.subheadline.weight(.medium))
                        Text("あなたの音楽、あなたの空間").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "play.fill").foregroundStyle(palette.accent)
                }
                .padding(14)
                .themeSurface()
            }
            .padding(22)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background { ThemeBackground(theme: theme) }
            .clipShape(RoundedRectangle(cornerRadius: palette.radius))
            .overlay {
                RoundedRectangle(cornerRadius: palette.radius)
                    .strokeBorder(palette.accent.opacity(selected ? 0.75 : 0.18), lineWidth: selected ? 2 : 1)
            }
            .environment(\.appTheme, theme)
            .foregroundStyle(.primary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(palette.title + "、" + palette.subtitle)
        .accessibilityValue(selected ? "選択中" : "未選択")
        .accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
