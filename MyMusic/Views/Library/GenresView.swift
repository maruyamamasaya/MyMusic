import SwiftUI

struct GenresView: View {
    @Environment(LibraryStore.self) private var libraryStore
    let genres: [Genre]

    var body: some View {
        List(genres) { genre in
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
        .themeScreen()
        .navigationTitle("ジャンル")
        .navigationDestination(for: Genre.self) { genre in
            SongsView(tracks: libraryStore.tracks(for: genre.trackIDs), title: genre.name)
        }
    }
}
