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
        let displayedComposers = filteredComposers
        List {
            ForEach(displayedComposers) { composer in
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

            if displayedComposers.isEmpty {
                ContentUnavailableView.search(text: query)
            }
        }
        .themeScreen()
        .navigationTitle("作曲者")
        .searchable(text: $query, prompt: "作曲者")
        .navigationDestination(for: Composer.self) { composer in
            SongsView(tracks: libraryStore.tracks(for: composer.trackIDs), title: composer.name)
        }
    }
}
