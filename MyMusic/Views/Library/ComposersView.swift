import SwiftUI

struct ComposersView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @State private var query = ""

    let composers: [Composer]

    private var filteredComposers: [Composer] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return composers }
        return composers.filter { $0.name.localizedStandardContains(trimmedQuery) }
    }

    var body: some View {
        List {
            ForEach(filteredComposers) { composer in
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

            if filteredComposers.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .navigationTitle("作曲者")
        .searchable(text: $query, prompt: "作曲者")
        .navigationDestination(for: Composer.self) { composer in
            SongsView(tracks: tracks(for: composer.trackIDs), title: composer.name)
        }
    }

    private func tracks(for trackIDs: [Track.ID]) -> [Track] {
        let tracksByID = Dictionary(uniqueKeysWithValues: libraryStore.tracks.map { ($0.id, $0) })
        return trackIDs.compactMap { tracksByID[$0] }
    }
}
