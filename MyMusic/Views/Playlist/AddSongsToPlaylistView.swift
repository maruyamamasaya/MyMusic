import SwiftUI

struct AddSongsToPlaylistView: View {
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(\.dismiss) private var dismiss
    let playlistID: Playlist.ID

    @State private var selection: Set<Track.ID> = []
    @State private var searchText = ""

    private var playlist: Playlist? {
        playlistStore.playlist(id: playlistID)
    }

    private var tracks: [Track] {
        libraryStore.tracks.filter {
            guard playlist?.kind.accepts($0) == true else { return false }
            return searchText.isEmpty || $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.artistName.localizedCaseInsensitiveContains(searchText) ||
                ($0.albumTitle?.localizedCaseInsensitiveContains(searchText) == true)
        }
    }

    var body: some View {
        NavigationStack {
            List(tracks) { track in
                Button {
                    if !selection.insert(track.id).inserted { selection.remove(track.id) }
                } label: {
                    HStack {
                        Image(systemName: selection.contains(track.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selection.contains(track.id) ? Color.accentColor : .secondary)
                        VStack(alignment: .leading) {
                            Text(track.title).foregroundStyle(.primary).lineLimit(1)
                            Text(track.artistName).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "曲、アーティスト、アルバムを検索")
            .navigationTitle(playlist?.kind == .work ? "作業用の曲を追加" : "曲を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("キャンセル") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("\(selection.count)曲を追加") {
                        playlistStore.addTracks(libraryStore.tracks.filter { selection.contains($0.id) }, to: playlistID)
                        dismiss()
                    }.disabled(selection.isEmpty)
                }
            }
        }
    }
}
