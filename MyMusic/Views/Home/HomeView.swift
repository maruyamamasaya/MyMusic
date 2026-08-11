import SwiftUI

struct HomeView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @State private var isRecentTracksExpanded = false
    @State private var isFavoriteTracksExpanded = false

    private var recentTracks: [Track] {
        playbackHistoryStore.recentTracks(from: libraryStore.tracks, limit: 10)
    }

    private var favoriteTracks: [Track] {
        playbackHistoryStore.favoriteTracks(from: libraryStore.tracks, limit: 10)
    }

    private var mostPlayedTracks: [Track] {
        playbackHistoryStore.mostPlayedTracks(from: libraryStore.tracks, limit: 10)
    }

    private var isReady: Bool {
        libraryStore.isInitialLoadComplete && playbackHistoryStore.isLoaded
    }

    var body: some View {
        NavigationStack {
            Group {
                if isReady {
                    libraryContent
                } else {
                    ProgressView("ライブラリを読み込み中…")
                }
            }
            .navigationTitle("ホーム")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    NavigationLink {
                        SettingsView()
                    } label: {
                        Label("設定", systemImage: "gearshape")
                    }
                }
            }
        }
    }

    private var libraryContent: some View {
        List {
            Section {
                if recentTracks.isEmpty {
                    ContentUnavailableView(
                        "再生履歴はありません",
                        systemImage: "clock",
                        description: Text("再生した曲がここに表示されます。")
                    )
                } else {
                    trackButtons(
                        isRecentTracksExpanded ? recentTracks : Array(recentTracks.prefix(3)),
                        queue: recentTracks
                    )
                }
            } header: {
                expandableSectionHeader(
                    title: "最近再生した曲",
                    isExpanded: $isRecentTracksExpanded,
                    showsButton: recentTracks.count > 3
                )
            }

            Section {
                if favoriteTracks.isEmpty {
                    ContentUnavailableView(
                        "お気に入りはありません",
                        systemImage: "heart",
                        description: Text("お気に入りに追加した曲がここに表示されます。")
                    )
                } else {
                    trackButtons(
                        isFavoriteTracksExpanded ? favoriteTracks : Array(favoriteTracks.prefix(3)),
                        queue: favoriteTracks
                    )
                }
            } header: {
                expandableSectionHeader(
                    title: "お気に入り",
                    isExpanded: $isFavoriteTracksExpanded,
                    showsButton: favoriteTracks.count > 3
                )
            }


            Section("よく再生する曲") {
                if mostPlayedTracks.isEmpty {
                    ContentUnavailableView(
                        "再生回数の記録はありません",
                        systemImage: "chart.bar",
                        description: Text("一定時間再生した曲がここに表示されます。")
                    )
                } else {
                    trackButtons(mostPlayedTracks)
                }
            }
        }
    }

    @ViewBuilder
    private func expandableSectionHeader(
        title: String,
        isExpanded: Binding<Bool>,
        showsButton: Bool
    ) -> some View {
        HStack {
            Text(title)

            Spacer()

            if showsButton {
                Button(isExpanded.wrappedValue ? "閉じる" : "すべて表示") {
                    isExpanded.wrappedValue.toggle()
                }
                .textCase(nil)
            }
        }
    }

    @ViewBuilder
    private func trackButtons(_ tracks: [Track], queue: [Track]? = nil) -> some View {
        let queueTracks = queue ?? tracks

        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
            Button {
                let queueIndex = queueTracks.firstIndex(where: { $0.id == track.id }) ?? index
                playerStore.playQueue(queueTracks, startingAt: queueIndex)
            } label: {
                TrackRowView(track: track)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
