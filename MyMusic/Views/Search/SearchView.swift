import SwiftUI

struct SearchView: View {
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    @State private var query = ""

    private var results: [Track] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else { return [] }
        return libraryStore.tracks.filter { track in
            track.title.localizedStandardContains(trimmedQuery)
                || track.artistName.localizedStandardContains(trimmedQuery)
                || (track.albumTitle?.localizedStandardContains(trimmedQuery) == true)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    ContentUnavailableView(
                        "ライブラリを検索",
                        systemImage: "magnifyingglass",
                        description: Text("曲名、アーティスト名、アルバム名から検索できます。")
                    )
                } else if results.isEmpty {
                    ContentUnavailableView(
                        "検索結果がありません",
                        systemImage: "magnifyingglass",
                        description: Text("別のキーワードを試してください。")
                    )
                } else {
                    List {
                        ForEach(Array(results.enumerated()), id: \.element.id) { index, track in
                            Button {
                                playerStore.playQueue(results, startingAt: index)
                            } label: {
                                TrackRowView(track: track)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("検索")
            .searchable(text: $query, prompt: "曲、アーティスト、アルバム")
        }
    }
}
