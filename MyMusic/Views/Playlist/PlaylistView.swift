import SwiftUI

struct PlaylistView: View {
    @Environment(PlaylistStore.self) private var playlistStore
    @State private var isCreatingPlaylist = false
    @State private var newPlaylistName = ""
    @State private var playlistToRename: Playlist?
    @State private var renameText = ""
    @State private var playlistToDelete: Playlist?

    var body: some View {
        NavigationStack {
            Group {
                if playlistStore.playlists.isEmpty {
                    ContentUnavailableView {
                        Label("No Playlists", systemImage: "music.note.list")
                    } description: {
                        Text("Create playlists to organize your favorite music.")
                    } actions: {
                        Button("New Playlist", systemImage: "plus") { presentCreatePlaylist() }
                            .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(playlistStore.playlists) { playlist in
                            NavigationLink(value: playlist.id) {
                                HStack {
                                    Label(playlist.name, systemImage: "music.note.list")
                                        .lineLimit(1)
                                    Spacer()
                                    Text(playlist.trackIDs.count, format: .number)
                                        .foregroundStyle(.secondary)
                                    Text(playlist.trackIDs.count == 1 ? "song" : "songs")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contextMenu {
                                Button("Rename", systemImage: "pencil") { presentRename(playlist) }
                                Button("Delete", systemImage: "trash", role: .destructive) { playlistToDelete = playlist }
                            }
                            .swipeActions {
                                Button("Delete", systemImage: "trash", role: .destructive) { playlistToDelete = playlist }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Playlists")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Playlist", systemImage: "plus") { presentCreatePlaylist() }
                }
            }
            .navigationDestination(for: Playlist.ID.self) { playlistID in
                PlaylistDetailView(playlistID: playlistID)
            }
            .alert("New Playlist", isPresented: $isCreatingPlaylist) {
                TextField("Playlist Name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) {}
                Button("Create") { playlistStore.createPlaylist(named: newPlaylistName) }
                    .disabled(trimmed(newPlaylistName).isEmpty)
            }
            .alert("Rename Playlist", isPresented: renameIsPresented) {
                TextField("Playlist Name", text: $renameText)
                Button("Cancel", role: .cancel) { playlistToRename = nil }
                Button("Save") {
                    if let playlistToRename { playlistStore.renamePlaylist(id: playlistToRename.id, to: renameText) }
                    playlistToRename = nil
                }
                .disabled(trimmed(renameText).isEmpty)
            }
            .confirmationDialog(
                "Delete \(playlistToDelete?.name ?? "Playlist")?",
                isPresented: deleteIsPresented,
                titleVisibility: .visible
            ) {
                Button("Delete Playlist", role: .destructive) {
                    if let playlistToDelete { playlistStore.deletePlaylist(id: playlistToDelete.id) }
                    playlistToDelete = nil
                }
                Button("Cancel", role: .cancel) { playlistToDelete = nil }
            } message: {
                Text("The playlist will be deleted. Music files will not be affected.")
            }
            .alert("Playlist Error", isPresented: errorIsPresented) {
                Button("OK") { playlistStore.dismissError() }
            } message: {
                Text(playlistStore.errorMessage ?? "An unknown error occurred.")
            }
            .task { await playlistStore.loadIfNeeded() }
        }
    }

    private var renameIsPresented: Binding<Bool> {
        Binding(get: { playlistToRename != nil }, set: { if !$0 { playlistToRename = nil } })
    }

    private var deleteIsPresented: Binding<Bool> {
        Binding(get: { playlistToDelete != nil }, set: { if !$0 { playlistToDelete = nil } })
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(get: { playlistStore.errorMessage != nil }, set: { if !$0 { playlistStore.dismissError() } })
    }

    private func presentCreatePlaylist() {
        newPlaylistName = ""
        isCreatingPlaylist = true
    }

    private func presentRename(_ playlist: Playlist) {
        renameText = playlist.name
        playlistToRename = playlist
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
