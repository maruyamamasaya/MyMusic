import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("オーディオ") {
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
}
