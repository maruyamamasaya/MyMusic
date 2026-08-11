import SwiftUI

struct AlbumsView: View {
    let albums: [Album]
    init(albums: [Album] = PreviewData.albums) { self.albums = albums }
    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]
    var body: some View {
        ScrollView { LazyVGrid(columns: columns, alignment: .leading, spacing: 20) { ForEach(albums) { album in NavigationLink(value: album) { VStack(alignment: .leading) { AlbumArtworkView(artworkIdentifier: album.artworkIdentifier); Text(album.title).font(.headline).lineLimit(1); Text(album.artistName).font(.subheadline).foregroundStyle(.secondary).lineLimit(1) }.foregroundStyle(.primary) } } }.padding() }
            .navigationTitle("Albums").navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
    }
}
