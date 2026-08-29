import SwiftUI

struct FavoriteAlbumsView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(FavoriteStore.self) private var favoriteStore

    private var albums: [Album] {
        favoriteStore.favoriteAlbums(from: libraryStore.albums)
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
                Section("アルバム") {
                    ForEach(albums) { album in
                        Button {
                            playRandomly(libraryStore.tracks(for: album))
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
                                Spacer(minLength: 8)
                                Image(systemName: "shuffle")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("このアルバムをランダム再生")
                        .swipeActions {
                            Button("お気に入り解除", systemImage: "heart.slash", role: .destructive) {
                                favoriteStore.toggleFavorite(album: album)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("お気に入りのアルバム")
    }

    private func playRandomly(_ sourceTracks: [Track]) {
        let playbackTracks = playbackHistoryStore.preferenceWeightedShuffle(sourceTracks)
        guard !playbackTracks.isEmpty else { return }
        playerStore.setShuffleEnabled(true)
        playerStore.playQueue(playbackTracks, startingAt: 0)
    }
}

struct FavoriteArtistsView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(PlaybackHistoryStore.self) private var playbackHistoryStore
    @Environment(FavoriteStore.self) private var favoriteStore

    private var artists: [Artist] {
        favoriteStore.favoriteArtists(from: libraryStore.artists)
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
                Section("アーティスト") {
                    ForEach(artists) { artist in
                        Button {
                            playRandomly(libraryStore.tracks(for: artist))
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.circle")
                                    .font(.title2)
                                    .foregroundStyle(.tint)
                                Text(artist.name)
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 8)
                                Image(systemName: "shuffle")
                                    .foregroundStyle(.tint)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("このアーティストをランダム再生")
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

    private func playRandomly(_ sourceTracks: [Track]) {
        let playbackTracks = playbackHistoryStore.preferenceWeightedShuffle(sourceTracks)
        guard !playbackTracks.isEmpty else { return }
        playerStore.setShuffleEnabled(true)
        playerStore.playQueue(playbackTracks, startingAt: 0)
    }
}
