import SwiftUI

struct HomeView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore

    private var recentTracks: [Track] {
        playbackHistoryStore.recentTracks(from: libraryStore.tracks, limit: 10)
    }

    private var favoriteTracks: [Track] {
        playbackHistoryStore.favoriteTracks(from: libraryStore.tracks, limit: 10)
    }

    var body: some View {
        NavigationStack {
            List {
                Section("最近再生した曲") {
                    if recentTracks.isEmpty {
                        ContentUnavailableView(
                            "再生履歴はありません",
                            systemImage: "clock",
                            description: Text("再生した曲がここに表示されます。")
                        )
                    } else {
                        trackButtons(recentTracks)
                    }
                }

                Section("お気に入り") {
                    if favoriteTracks.isEmpty {
                        ContentUnavailableView(
                            "お気に入りはありません",
                            systemImage: "heart",
                            description: Text("お気に入りに追加した曲がここに表示されます。")
                        )
                    } else {
                        trackButtons(favoriteTracks)
                    }
                }
            }
            .navigationTitle("ホーム")
        }
    }

    @ViewBuilder
    private func trackButtons(_ tracks: [Track]) -> some View {
        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
            Button {
                playerStore.playQueue(tracks, startingAt: index)
            } label: {
                TrackRowView(track: track)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }
}
