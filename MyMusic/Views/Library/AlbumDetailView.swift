import SwiftUI

struct AlbumDetailView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @Environment(FavoriteStore.self) private var favoriteStore
    let album: Album

    private var tracks: [Track] { libraryStore.tracks(for: album) }
    private var isFavorite: Bool { favoriteStore.isFavorite(albumID: album.id) }

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

            Section("Songs") {
                if tracks.isEmpty {
                    EmptyStateView(icon: "music.note.list", title: "No Songs", message: "Album tracks could not be found.")
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
            Button(isFavorite ? "Remove from Favorites" : "Add to Favorites", systemImage: isFavorite ? "heart.fill" : "heart") {
                favoriteStore.toggleFavorite(albumID: album.id)
            }
        }
    }

    private func play(shuffled: Bool) {
        guard !tracks.isEmpty else { return }
        playerStore.setShuffleEnabled(shuffled)
        playerStore.playQueue(tracks, startingAt: 0)
    }
}
