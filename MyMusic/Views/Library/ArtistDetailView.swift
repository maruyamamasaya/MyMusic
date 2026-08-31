import SwiftUI

struct ArtistDetailView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(FavoriteStore.self) private var favoriteStore
    let artist: Artist

    private var tracks: [Track] { libraryStore.tracks(for: artist) }
    private var albums: [Album] { libraryStore.albums(for: artist) }
    private var isFavorite: Bool { favoriteStore.isFavorite(artistID: artist.id) }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(.secondary)
                    Text(artist.name).font(.largeTitle.bold()).multilineTextAlignment(.center)
                    PlayShuffleButtons(
                        isDisabled: tracks.isEmpty,
                        onPlay: { play(shuffled: false) },
                        onShuffle: { play(shuffled: true) }
                    )
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            if !albums.isEmpty {
                Section("アルバム") {
                    ForEach(albums) { album in
                        NavigationLink {
                            AlbumDetailView(album: album)
                        } label: {
                            HStack {
                                AlbumArtworkView(artworkIdentifier: album.artworkIdentifier)
                                    .frame(width: 52, height: 52)
                                VStack(alignment: .leading) {
                                    Text(album.title)
                                    Text("\(libraryStore.tracks(for: album).count)曲")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Section("曲") {
                if tracks.isEmpty {
                    EmptyStateView(icon: "music.note.list", title: "曲がありません", message: "アーティストの曲が見つかりませんでした。")
                } else {
                    ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                        PlayableTrackRowView(track: track) {
                            playerStore.playQueue(
                                tracks,
                                startingAt: index,
                                startContext: PlaybackStartContext(kind: .manual, source: .artist)
                            )
                        }
                    }
                }
            }
        }
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button(isFavorite ? "お気に入りから削除" : "お気に入りに追加", systemImage: isFavorite ? "heart.fill" : "heart") {
                favoriteStore.toggleFavorite(artistID: artist.id)
            }
        }
    }

    private func play(shuffled: Bool) {
        let playbackTracks = shuffled
            ? tracks.filter(\.isEligibleForRegularPlayback)
            : tracks
        guard !playbackTracks.isEmpty else { return }
        playerStore.setShuffleEnabled(shuffled)
        playerStore.playQueue(
            playbackTracks,
            startingAt: 0,
            startContext: PlaybackStartContext(kind: .manual, source: shuffled ? .shuffle : .artist)
        )
    }
}
