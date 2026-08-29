import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        List {
            Section {
                Toggle(isOn: volumeNormalizationBinding) {
                    Label("音量ノーマライズ", systemImage: "speaker.wave.2.bubble")
                }

                NavigationLink {
                    PlaybackTransitionSettingsView()
                } label: {
                    Label("再生トランジション", systemImage: "waveform.path")
                }

                NavigationLink {
                    EqualizerSettingsView()
                } label: {
                    Label("イコライザ", systemImage: "slider.vertical.3")
                }
            } header: {
                Text("オーディオ")
            } footer: {
                Text("Macで解析された音量情報を利用して、極端に音量の異なる曲のみ補正します。")
            }

            Section {
                NavigationLink {
                    AnalyticsView()
                } label: {
                    Label("分析", systemImage: "chart.bar.xaxis")
                }

                NavigationLink {
                    MusicHistoryView()
                } label: {
                    Label("音楽史", systemImage: "calendar.badge.clock")
                }
            }

            Section("Beta機能") {
                NavigationLink {
                    TrackFeatureSettingsView()
                } label: {
                    Label("音楽特徴量", systemImage: "waveform.badge.magnifyingglass")
                }
            }

            Section("データ管理") {
                NavigationLink {
                    DataManagementView()
                } label: {
                    Label("データの読み込み・書き出し", systemImage: "externaldrive")
                }
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var volumeNormalizationBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.volumeNormalizationEnabled },
            set: { settingsStore.setVolumeNormalizationEnabled($0) }
        )
    }
}
