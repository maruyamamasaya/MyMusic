import SwiftUI

struct AlbumsView: View {
    @State private var query = ""
    @AppStorage("library.albumsDisplayMode") private var displayMode = LibraryDisplayMode.artwork

    let albums: [Album]

    init(albums: [Album] = PreviewData.albums) { self.albums = albums }

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]

    private var filteredAlbums: [Album] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return albums }
        return albums.filter { album in
            album.title.localizedStandardContains(trimmedQuery)
                || album.artistName.localizedStandardContains(trimmedQuery)
        }
    }

    var body: some View {
        let displayedAlbums = filteredAlbums
        Group {
            if displayMode == .artwork {
                ScrollView {
                    artworkGrid(displaying: displayedAlbums)
                }
            } else {
                textList(displaying: displayedAlbums)
            }
        }
        .themeScreen()
        .navigationTitle("アルバム")
        .searchable(text: $query, prompt: "アルバム、アーティスト")
        .navigationDestination(for: Album.self) { AlbumDetailView(album: $0) }
        .toolbar {
            LibraryDisplayModeMenu(selection: $displayMode)
        }
    }

    @ViewBuilder
    private func artworkGrid(displaying albums: [Album]) -> some View {
        if albums.isEmpty {
            ContentUnavailableView.search(text: query)
                .padding(.top, 48)
        } else {
                LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                    ForEach(albums) { album in
                        NavigationLink(value: album) {
                            VStack(alignment: .leading) {
                                AlbumArtworkView(artworkIdentifier: album.artworkIdentifier)
                                Text(album.title).font(.headline).lineLimit(1)
                                Text(album.artistName).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                            }
                            .foregroundStyle(.primary)
                        }
                    }
                }
                .padding()
        }
    }

    private func textList(displaying albums: [Album]) -> some View {
        List {
            ForEach(albums) { album in
                NavigationLink(value: album) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(album.title).lineLimit(1)
                        Text(album.artistName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            if albums.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }
}
