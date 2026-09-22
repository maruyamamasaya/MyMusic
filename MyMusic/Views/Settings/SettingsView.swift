import SwiftUI

struct SettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        List {
            Section("デザイン") {
                NavigationLink {
                    ThemeSettingsView()
                } label: {
                    Label("テーマ", systemImage: "sparkles")
                        .badge(ThemePalette.resolve(settingsStore.theme).title)
                }
                NavigationLink {
                    VisualWorldSettingsView()
                } label: {
                    Label("再生中のビジュアル", systemImage: "sparkles.rectangle.stack")
                        .badge(settingsStore.visualWorldStyle.title)
                }
            }

            Section {
                Toggle(isOn: sourceSampleRateMatchingBinding) {
                    Label("音源レート優先", systemImage: "waveform.badge.checkmark")
                }

                NavigationLink {
                    HiResDirectOutputProbeView()
                } label: {
                    Label("USB DAC 出力レート", systemImage: "waveform.path.ecg.rectangle")
                }

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
                Text("音源レート優先はUSB DAC接続時に曲と同じサンプルレートをiOSへ要求します。USB DAC 出力レートでは、内蔵の無音PCMで44.1〜192 kHzの出力準備と確認ができます。音量ノーマライズはMacで解析された音量情報を利用します。")
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

                NavigationLink {
                    LibraryCleanupCandidatesView()
                } label: {
                    Label("ライブラリ整理候補", systemImage: "rectangle.stack.badge.minus")
                }

                NavigationLink {
                    PlaybackBehaviorView()
                } label: {
                    Label("再生傾向", systemImage: "chart.line.uptrend.xyaxis")
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
        .themeScreen()
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var volumeNormalizationBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.volumeNormalizationEnabled },
            set: { settingsStore.setVolumeNormalizationEnabled($0) }
        )
    }

    private var sourceSampleRateMatchingBinding: Binding<Bool> {
        Binding(
            get: { settingsStore.sourceSampleRateMatchingEnabled },
            set: { settingsStore.setSourceSampleRateMatchingEnabled($0) }
        )
    }
}
