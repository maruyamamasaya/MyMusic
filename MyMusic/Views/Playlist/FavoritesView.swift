import SwiftUI

struct FavoritesView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore

    private var tracks: [Track] {
        playbackHistoryStore.favoriteTracks(from: libraryStore.tracks)
    }

    var body: some View {
        List {
            if tracks.isEmpty {
                ContentUnavailableView(
                    "お気に入りはありません",
                    systemImage: "heart",
                    description: Text("曲のメニューまたは再生画面から追加できます。")
                )
            } else {
                Section {
                    HStack(spacing: 12) {
                        Button("再生", systemImage: "play.fill") { play(shuffled: false) }
                            .buttonStyle(.borderedProminent)
                        Button("シャッフル", systemImage: "shuffle") { play(shuffled: true) }
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section("曲") {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        Button {
                            playerStore.playQueue(tracks, startingAt: index)
                        } label: {
                            TrackRowView(track: track)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .swipeActions {
                            Button("お気に入り解除", systemImage: "heart.slash", role: .destructive) {
                                playbackHistoryStore.toggleFavorite(trackID: track.id)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("お気に入り")
    }

    private func play(shuffled: Bool) {
        guard !tracks.isEmpty else { return }
        playerStore.setShuffleEnabled(shuffled)
        playerStore.playQueue(tracks, startingAt: 0)
    }
}
