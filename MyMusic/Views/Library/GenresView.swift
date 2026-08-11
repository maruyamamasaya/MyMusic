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
        .navigationTitle("Genres")
        .navigationDestination(for: Genre.self) { genre in
            SongsView(tracks: tracks(for: genre.trackIDs), title: genre.name)
        }
    }

    private func tracks(for trackIDs: [Track.ID]) -> [Track] {
        let tracksByID = Dictionary(uniqueKeysWithValues: libraryStore.tracks.map { ($0.id, $0) })
        return trackIDs.compactMap { tracksByID[$0] }
    }
}
