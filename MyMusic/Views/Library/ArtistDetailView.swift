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
                        Button("Play", systemImage: "play.fill") { play(shuffled: false) }
                        Button("Shuffle", systemImage: "shuffle") { play(shuffled: true) }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(tracks.isEmpty)
                }
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
            }

            if !albums.isEmpty {
                Section("Albums") {
                    ForEach(albums) { album in
                        NavigationLink(value: album) {
                            HStack {
                                AlbumArtworkView(artworkIdentifier: album.artworkIdentifier)
                                    .frame(width: 52, height: 52)
                                VStack(alignment: .leading) {
                                    Text(album.title)
                                    Text("\(libraryStore.tracks(for: album).count) songs")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }

            Section("Songs") {
                if tracks.isEmpty {
                    EmptyStateView(icon: "music.note.list", title: "No Songs", message: "Artist tracks could not be found.")
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
            Button(isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: isFavorite ? "heart.fill" : "heart") {
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
