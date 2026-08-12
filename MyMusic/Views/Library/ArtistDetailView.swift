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
                    HStack {
                        Button("再生", systemImage: "play.fill") { play(shuffled: false) }
                        Button("シャッフル", systemImage: "shuffle") { play(shuffled: true) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(tracks.isEmpty)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            if !albums.isEmpty {
                Section("アルバム") {
                    ForEach(albums) { album in
                        NavigationLink(value: album) {
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
                            playerStore.playQueue(tracks, startingAt: index)
                        }
                    }
                }
            }
        }
        .navigationTitle(artist.name)
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
        .toolbar {
            Button(isFavorite ? "お気に入りから削除" : "お気に入りに追加", systemImage: isFavorite ? "heart.fill" : "heart") {
                favoriteStore.toggleFavorite(artistID: artist.id)
            }
        }
    }

    private func play(shuffled: Bool) {
        guard !tracks.isEmpty else { return }
        playerStore.setShuffleEnabled(shuffled)
        playerStore.playQueue(tracks, startingAt: 0)
    }
}
