import SwiftUI

struct AlbumDetailView: View {
    let album: Album
    var body: some View {
        ScrollView { VStack(spacing: 16) { AlbumArtworkView(artworkIdentifier: album.artworkIdentifier).frame(maxWidth: 280); Text(album.title).font(.title.bold()); Text(album.artistName).foregroundStyle(.secondary); if let year = album.year { Text(String(year)).font(.subheadline).foregroundStyle(.secondary) }; HStack { Button("Play", systemImage: "play.fill") {}; Button("Shuffle", systemImage: "shuffle") {} }.buttonStyle(.borderedProminent); EmptyStateView(icon: "music.note.list", title: "No Songs", message: "Album tracks will appear here.") }.padding() }.navigationTitle(album.title).navigationBarTitleDisplayMode(.inline)
    }
}
