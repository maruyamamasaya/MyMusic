import SwiftUI

struct FavoriteAlbumsView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(FavoriteStore.self) private var favoriteStore

    private var albums: [Album] {
        favoriteStore.favoriteAlbums(from: libraryStore.albums)
    }

    private var tracks: [Track] {
        uniqueTracks(albums.flatMap { libraryStore.tracks(for: $0) })
    }

    var body: some View {
        List {
            if albums.isEmpty {
                ContentUnavailableView(
                    "お気に入りのアルバムはありません",
                    systemImage: "square.stack",
                    description: Text("アルバム画面のハートから追加できます。")
                )
            } else {
                playbackControls

                Section("アルバム") {
                    ForEach(albums) { album in
                        NavigationLink {
                            AlbumDetailView(album: album)
                        } label: {
                            HStack(spacing: 12) {
                                AlbumArtworkView(artworkIdentifier: album.artworkIdentifier)
                                    .frame(width: 52, height: 52)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(album.title).lineLimit(1)
                                    Text(album.artistName)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .swipeActions {
                            Button("お気に入り解除", systemImage: "heart.slash", role: .destructive) {
                                favoriteStore.toggleFavorite(albumID: album.id)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("お気に入りのアルバム")
    }

    private var playbackControls: some View {
        Section {
            PlayShuffleButtons(
                isDisabled: tracks.isEmpty,
                onPlay: { play(shuffled: false) },
                onShuffle: { play(shuffled: true) }
            )
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    private func play(shuffled: Bool) {
        guard !tracks.isEmpty else { return }
        playerStore.setShuffleEnabled(shuffled)
        playerStore.playQueue(tracks, startingAt: 0)
    }
}

struct FavoriteArtistsView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(FavoriteStore.self) private var favoriteStore

    private var artists: [Artist] {
        favoriteStore.favoriteArtists(from: libraryStore.artists)
    }

    private var tracks: [Track] {
        uniqueTracks(artists.flatMap { libraryStore.tracks(for: $0) })
    }

    var body: some View {
        List {
            if artists.isEmpty {
                ContentUnavailableView(
                    "お気に入りのアーティストはいません",
                    systemImage: "music.mic",
                    description: Text("アーティスト画面のハートから追加できます。")
                )
            } else {
                playbackControls

                Section("アーティスト") {
                    ForEach(artists) { artist in
                        NavigationLink {
                            ArtistDetailView(artist: artist)
                        } label: {
                            Label(artist.name, systemImage: "person.circle")
                        }
                        .swipeActions {
                            Button("お気に入り解除", systemImage: "heart.slash", role: .destructive) {
                                favoriteStore.toggleFavorite(artistID: artist.id)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("お気に入りのアーティスト")
    }

    private var playbackControls: some View {
        Section {
            PlayShuffleButtons(
                isDisabled: tracks.isEmpty,
                onPlay: { play(shuffled: false) },
                onShuffle: { play(shuffled: true) }
            )
            .frame(maxWidth: .infinity)
            .listRowBackground(Color.clear)
        }
    }

    private func play(shuffled: Bool) {
        guard !tracks.isEmpty else { return }
        playerStore.setShuffleEnabled(shuffled)
        playerStore.playQueue(tracks, startingAt: 0)
    }
}

private func uniqueTracks(_ tracks: [Track]) -> [Track] {
    var seen: Set<Track.ID> = []
    return tracks.filter { seen.insert($0.id).inserted }
}
