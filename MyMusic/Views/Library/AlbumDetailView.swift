import SwiftUI

struct AlbumDetailView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(FavoriteStore.self) private var favoriteStore
    let album: Album

    private var tracks: [Track] { libraryStore.tracks(for: album) }
    private var isFavorite: Bool { favoriteStore.isFavorite(album: album) }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    AlbumArtworkView(artworkIdentifier: album.artworkIdentifier)
                        .frame(maxWidth: 280)
                    Text(album.title).font(.title.bold()).multilineTextAlignment(.center)
                    Text(album.artistName).foregroundStyle(.secondary)
                    if let year = album.year {
                        Text(String(year)).font(.subheadline).foregroundStyle(.secondary)
                    }
                    PlayShuffleButtons(
                        isDisabled: tracks.isEmpty,
                        onPlay: { play(shuffled: false) },
                        onShuffle: { play(shuffled: true) }
                    )
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            Section("曲") {
                if tracks.isEmpty {
                    EmptyStateView(icon: "music.note.list", title: "曲がありません", message: "アルバムの曲が見つかりませんでした。")
                } else {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        PlayableTrackRowView(track: track) {
                            playerStore.playQueue(tracks, startingAt: index)
                        }
                    }
                }
            }
        }
        .navigationTitle(album.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(isFavorite ? "お気に入りから削除" : "お気に入りに追加", systemImage: isFavorite ? "heart.fill" : "heart") {
                favoriteStore.toggleFavorite(album: album)
            }
        }
    }

    private func play(shuffled: Bool) {
        let playbackTracks = shuffled
            ? tracks.filter(\.isEligibleForRegularPlayback)
            : tracks
        guard !playbackTracks.isEmpty else { return }
        playerStore.setShuffleEnabled(shuffled)
        playerStore.playQueue(playbackTracks, startingAt: 0)
    }
}
