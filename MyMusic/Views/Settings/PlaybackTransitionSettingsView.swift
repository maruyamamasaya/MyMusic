import SwiftUI

struct PlaybackTransitionSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        List {
            Section {
                Toggle("フェードイン", isOn: fadeInEnabled)

                Picker("フェードイン時間", selection: fadeInDuration) {
                    ForEach(PlaybackTransitionSettings.selectableDurations, id: \.self) { duration in
                        Text(durationLabel(duration)).tag(duration)
                    }
                }
                .disabled(!settingsStore.playbackTransition.fadeInEnabled)
            } header: {
                Text("再生開始")
            } footer: {
                Text("曲の再生開始時に、設定した時間をかけて音量を上げます。")
            }

            Section {
                Toggle("フェードアウト", isOn: fadeOutEnabled)

                Picker("フェードアウト時間", selection: fadeOutDuration) {
                    ForEach(PlaybackTransitionSettings.selectableDurations, id: \.self) { duration in
                        Text(durationLabel(duration)).tag(duration)
                    }
                }
                .disabled(!settingsStore.playbackTransition.fadeOutEnabled)
            } header: {
                Text("再生終了・曲送り")
            } footer: {
                Text("曲の終了前と次の曲への切り替え前に、設定した時間をかけて音量を下げます。")
            }

            Section {
                LabeledContent("現在の設定", value: summary)
            } footer: {
                Text("既存の再生感を維持するため、初期状態ではフェードはオフです。設定は通常再生とハイライト再生で共有されます。")
            }
        }
        .navigationTitle("再生トランジション")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var fadeInEnabled: Binding<Bool> {
        Binding(
            get: { settingsStore.playbackTransition.fadeInEnabled },
            set: { settingsStore.setFadeInEnabled($0) }
        )
    }

    private var fadeInDuration: Binding<TimeInterval> {
        Binding(
            get: { settingsStore.playbackTransition.fadeInDuration },
            set: { settingsStore.setFadeInDuration($0) }
        )
    }

    private var fadeOutEnabled: Binding<Bool> {
        Binding(
            get: { settingsStore.playbackTransition.fadeOutEnabled },
            set: { settingsStore.setFadeOutEnabled($0) }
        )
    }

    private var fadeOutDuration: Binding<TimeInterval> {
        Binding(
            get: { settingsStore.playbackTransition.fadeOutDuration },
            set: { settingsStore.setFadeOutDuration($0) }
        )
    }

    private var summary: String {
        let settings = settingsStore.playbackTransition
        guard settings.fadeInEnabled || settings.fadeOutEnabled else { return "オフ" }
        var parts: [String] = []
        if settings.fadeInEnabled { parts.append("In \(durationLabel(settings.fadeInDuration))") }
        if settings.fadeOutEnabled { parts.append("Out \(durationLabel(settings.fadeOutDuration))") }
        return parts.joined(separator: " / ")
    }

    private func durationLabel(_ duration: TimeInterval) -> String {
        duration.formatted(.number.precision(.fractionLength(1))) + "秒"
    }
}
