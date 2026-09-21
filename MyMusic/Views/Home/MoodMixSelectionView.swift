import SwiftUI

struct MoodMixSelectionView: View {
    @Environment(StationStore.self) private var stationStore
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMix: MoodMixKind?
    @State private var errorMessage: String?
    @State private var availableMixes: Set<MoodMixKind> = []
    @State private var isPreparing = true

    var body: some View {
        NavigationStack {
            Group {
                if isPreparing || stationStore.isLoading {
                    ProgressView("音楽ライブラリを準備中…")
                } else if availableMixes.isEmpty {
                    ContentUnavailableView(
                        stationStore.availableFeatureCount == 0 ? "選曲に使える特徴量がありません" : "選べるMoodがありません",
                        systemImage: "waveform.path",
                        description: Text("通常再生の対象曲に、違いを判定できるTrack Featureが必要です。")
                    )
                } else {
                    List {
                        if let errorMessage {
                            Label(errorMessage, systemImage: "info.circle")
                                .foregroundStyle(.secondary)
                        }
                        Section {
                            ForEach(MoodMixKind.allCases) { kind in
                                Button {
                                    errorMessage = nil
                                    selectedMix = kind
                                } label: {
                                    HStack(spacing: 14) {
                                        Image(systemName: kind.systemImage)
                                            .font(.title3)
                                            .frame(width: 34)
                                            .foregroundStyle(.tint)
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(kind.title).font(.headline).foregroundStyle(.primary)
                                            Text(availableMixes.contains(kind) ? kind.subtitle : "対象の曲がありません")
                                                .font(.caption).foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if selectedMix == kind {
                                            ProgressView()
                                        } else {
                                            Image(systemName: "play.fill").foregroundStyle(.tint)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(!availableMixes.contains(kind) || selectedMix != nil)
                            }
                        } header: {
                            Text("Moodを選んで再生")
                        } footer: {
                            Text("曲の特徴を今のライブラリ内で比べて選びます。")
                        }
                    }
                }
            }
            .navigationTitle("Mood Mix")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("閉じる", systemImage: "xmark") { dismiss() }
                }
            }
        }
        .themeScreen()
        .presentationDetents([.medium, .large])
        .task {
            await stationStore.prepare()
            guard !Task.isCancelled else { return }
            availableMixes = Set(stationStore.availableMoodMixes)
            isPreparing = false
        }
        .task(id: selectedMix) {
            guard let selectedMix else { return }
            let played = await stationStore.playMoodMix(selectedMix)
            guard !Task.isCancelled else { return }
            if played {
                dismiss()
            } else {
                errorMessage = "再生できる曲がありません。別のMoodを選んでください。"
                self.selectedMix = nil
            }
        }
    }
}
