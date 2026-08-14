import SwiftUI

struct ArtistsView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @State private var query = ""
    @AppStorage("library.artistsDisplayMode") private var displayMode = LibraryDisplayMode.text

    let artists: [Artist]

    init(artists: [Artist] = PreviewData.artists) { self.artists = artists }

    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 16)]

    private var filteredArtists: [Artist] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return artists }
        return artists.filter { $0.name.localizedStandardContains(trimmedQuery) }
    }

    var body: some View {
        Group {
            if displayMode == .artwork {
                ScrollView {
                    artworkGrid
                }
            } else {
                textList
            }
        }
        .navigationTitle("アーティスト")
        .searchable(text: $query, prompt: "アーティスト")
        .navigationDestination(for: Artist.self) { ArtistDetailView(artist: $0) }
        .toolbar {
            LibraryDisplayModeMenu(selection: $displayMode)
        }
    }

    private var textList: some View {
        List {
            ForEach(filteredArtists) { artist in
                NavigationLink(value: artist) {
                    Label(artist.name, systemImage: "person.circle")
                }
            }

            if filteredArtists.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
    }

    @ViewBuilder
    private var artworkGrid: some View {
        if filteredArtists.isEmpty {
            ContentUnavailableView.search(text: query)
                .padding(.top, 48)
        } else {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 20) {
                ForEach(filteredArtists) { artist in
                    NavigationLink(value: artist) {
                        VStack(alignment: .leading) {
                            AlbumArtworkView(artworkIdentifier: artworkIdentifier(for: artist))
                            Text(artist.name).font(.headline).lineLimit(1)
                            Text("\(artist.albumIDs.count)アルバム")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
            .padding()
        }
    }

    private func artworkIdentifier(for artist: Artist) -> String? {
        let identifiers = libraryStore.albums(for: artist).compactMap(\.artworkIdentifier)
        guard !identifiers.isEmpty else { return nil }
        let index = Int(UInt(bitPattern: artist.id.hashValue) % UInt(identifiers.count))
        return identifiers[index]
    }
}
