import SwiftUI

struct VisualWorldSettingsView: View {
    @Environment(SettingsStore.self) private var settings

    var body: some View {
        List {
            Section {
                ForEach(VisualWorldStyle.allCases) { style in
                    Button {
                        settings.setVisualWorldStyle(style)
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: symbol(for: style))
                                .frame(width: 28)
                                .foregroundStyle(style == .twilight
                                    ? Color(red: 1, green: 0.61, blue: 0.39)
                                    : ThemePalette.resolve(style.themePalette).accent)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(style.title).foregroundStyle(.primary)
                                Text(style.detail).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            if settings.visualWorldStyle == style {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .accessibilityValue(settings.visualWorldStyle == style ? "選択中" : "未選択")
                }
            } footer: {
                Text("再生中のアート画面に適用します。アプリのテーマとは別に保存されます。")
            }
        }
        .themeScreen()
        .navigationTitle("再生中のビジュアル")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func symbol(for style: VisualWorldStyle) -> String {
        switch style {
        case .photonSphere: "circle.dotted.circle"
        case .lightGates: "waveform.path"
        case .nightSky: "moon.stars"
        case .twilight: "sun.horizon.fill"
        }
    }
}
