import SwiftUI

struct TrackFingerprintBuildView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var buildStore = TrackFingerprintBuildStore()

    var body: some View {
        @Bindable var buildStore = buildStore

        List {
            Section {
                LabeledContent("作成済み", value: "\(buildStore.completedCount)曲")
                LabeledContent("未作成", value: "\(buildStore.missingCount)曲")
                if buildStore.totalCount > 0 {
                    ProgressView(value: buildStore.progress)
                }
            } header: {
                Text("進捗")
            } footer: {
                Text("Fingerprintは1曲完了するたびに保存されます。画面を離れても、次回は未作成曲から再開します。")
            }

            Section {
                Toggle("iCloud上の曲も処理する", isOn: $buildStore.allowDownloading)
                    .disabled(buildStore.isRunning)

                if buildStore.isRunning {
                    Button("一時停止", systemImage: "pause.fill", role: .cancel) {
                        buildStore.pause()
                    }
                } else {
                    Button("Fingerprint作成を開始", systemImage: "waveform.badge.magnifyingglass") {
                        buildStore.start(
                            tracks: libraryStore.unfilteredTracks,
                            folders: libraryStore.libraryFolders
                        )
                    }
                    .disabled(cannotStart)
                }
            } header: {
                Text("作成")
            } footer: {
                if playerStore.isPlaying || playerStore.isLoading {
                    Text("再生を一時停止してから開始してください。再生が始まるとFingerprint作成は停止します。")
                } else if libraryStore.isLoading {
                    Text("Libraryの読み込み・再スキャン完了後に開始できます。")
                } else {
                    Text("既定では端末上ですぐ読める曲だけを処理します。iCloud上の曲を含めると、通信・download・発熱が発生する場合があります。")
                }
            }

            if buildStore.isRunning || buildStore.currentTrackTitle != nil {
                Section("処理中") {
                    LabeledContent("曲", value: buildStore.currentTrackTitle ?? "準備中")
                    ProgressView()
                }
            }

            if buildStore.downloadRequiredCount > 0 || buildStore.failedCount > 0 {
                Section("今回の結果") {
                    if buildStore.downloadRequiredCount > 0 {
                        LabeledContent("iCloud待ち", value: "\(buildStore.downloadRequiredCount)曲")
                    }
                    if buildStore.failedCount > 0 {
                        LabeledContent("読込失敗", value: "\(buildStore.failedCount)曲")
                    }
                }
            }

            if let message = buildStore.message {
                Section { Text(message).foregroundStyle(.secondary) }
            }
        }
        .navigationTitle("Track Fingerprint")
        .navigationBarTitleDisplayMode(.inline)
        .task { await refresh() }
        .onDisappear { buildStore.pause() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { buildStore.pause() }
        }
        .onChange(of: playerStore.isPlaying) { _, isPlaying in
            if isPlaying { buildStore.pause() }
        }
        .onChange(of: playerStore.isLoading) { _, isLoading in
            if isLoading { buildStore.pause() }
        }
        .onChange(of: libraryStore.isLoading) { _, isLoading in
            if isLoading { buildStore.pause() }
        }
    }

    private var cannotStart: Bool {
        buildStore.isRunning || buildStore.missingCount == 0
            || playerStore.isPlaying || playerStore.isLoading || libraryStore.isLoading
            || libraryStore.libraryFolders.isEmpty
    }

    private func refresh() async {
        await buildStore.refresh(tracks: libraryStore.unfilteredTracks)
    }
}
