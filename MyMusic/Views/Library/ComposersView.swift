import SwiftUI

struct ComposersView: View {
    @Environment(LibraryStore.self) private var libraryStore
    let composers: [Composer]

    var body: some View {
        List(composers) { composer in
            NavigationLink(value: composer) {
                HStack {
                    Label(composer.name, systemImage: "music.quarternote.3")
                        .lineLimit(1)
                    Spacer()
                    Text("\(composer.trackIDs.count)曲")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Composers")
        .navigationDestination(for: Composer.self) { composer in
            SongsView(tracks: tracks(for: composer.trackIDs), title: composer.name)
        }
    }

    private func tracks(for trackIDs: [Track.ID]) -> [Track] {
        let tracksByID = Dictionary(uniqueKeysWithValues: libraryStore.tracks.map { ($0.id, $0) })
        return trackIDs.compactMap { tracksByID[$0] }
    }
}
