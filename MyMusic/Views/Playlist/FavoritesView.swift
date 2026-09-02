import SwiftUI

struct FavoritesView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(TrackPreferenceStore.self) private var preferenceStore

    private var tracks: [Track] {
        preferenceStore.favoriteTracks(from: libraryStore.tracks)
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
                    PlayShuffleButtons(
                        isDisabled: tracks.isEmpty,
                        onPlay: { play(shuffled: false) },
                        onShuffle: { play(shuffled: true) }
                    )
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section("曲") {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        PlayableTrackRowView(track: track) {
                            playerStore.playQueue(
                                tracks,
                                startingAt: index,
                                startContext: PlaybackStartContext(kind: .manual, source: .favorite)
                            )
                        }
                        .swipeActions {
                            Button("お気に入り解除", systemImage: "heart.slash", role: .destructive) {
                                preferenceStore.toggleFavorite(trackID: track.id)
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
        playerStore.playQueue(
            tracks,
            startingAt: 0,
            startContext: PlaybackStartContext(kind: .manual, source: shuffled ? .shuffle : .favorite)
        )
    }
}
