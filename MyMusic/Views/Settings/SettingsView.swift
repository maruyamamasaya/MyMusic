import SwiftUI

struct SettingsView: View {
    var body: some View {
        List {
            Section("オーディオ") {
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
            }

            Section("データ管理") {
                NavigationLink {
                    DataManagementView()
                } label: {
                    Label("Import / Export", systemImage: "externaldrive")
                }
            }
        }
        .navigationTitle("設定")
        .navigationBarTitleDisplayMode(.inline)
    }
}
