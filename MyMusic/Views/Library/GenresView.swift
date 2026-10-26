import SwiftUI

struct GenresView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @State private var query = ""
    let genres: [Genre]

    private var filteredGenres: [Genre] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedQuery.isEmpty ? genres : genres.filter {
            $0.name.localizedStandardContains(trimmedQuery)
        }
    }

    var body: some View {
        let displayedGenres = filteredGenres
        List(displayedGenres) { genre in
            NavigationLink(value: genre) {
                HStack {
                    Label(genre.name, systemImage: "guitars")
                        .lineLimit(1)
                    Spacer()
                    Text("\(genre.trackIDs.count)曲")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .overlay {
            if displayedGenres.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .themeScreen()
        .navigationTitle("ジャンル")
        .searchable(text: $query, prompt: "ジャンル")
        .safeAreaInset(edge: .top, spacing: 0) {
            LibraryPlaybackBar(
                tracks: libraryStore.tracks(for: displayedGenres.flatMap(\.trackIDs))
            ) {
                Text("\(displayedGenres.count)ジャンル")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationDestination(for: Genre.self) { genre in
            SongsView(tracks: libraryStore.tracks(for: genre.trackIDs), title: genre.name)
        }
    }
}
