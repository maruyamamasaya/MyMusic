import SwiftUI

struct AddToPlaylistSheet: View {
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(\.dismiss) private var dismiss
    let track: Track

    @State private var isCreatingPlaylist = false
    @State private var newPlaylistName = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button("New Playlist", systemImage: "plus") {
                        newPlaylistName = ""
                        isCreatingPlaylist = true
                    }
                }

                Section("Choose Playlist") {
                    if playlistStore.playlists.isEmpty {
                        Text("No playlists yet")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(playlistStore.playlists) { playlist in
                            let alreadyAdded = playlistStore.contains(track.id, in: playlist.id)
                            Button {
                                playlistStore.addTrack(track, to: playlist.id)
                                dismiss()
                            } label: {
                                HStack {
                                    Text(playlist.name).foregroundStyle(.primary)
                                    Spacer()
                                    if alreadyAdded {
                                        Label("Added", systemImage: "checkmark")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .disabled(alreadyAdded)
                        }
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .alert("New Playlist", isPresented: $isCreatingPlaylist) {
                TextField("Playlist Name", text: $newPlaylistName)
                Button("Cancel", role: .cancel) {}
                Button("Create") {
                    if let playlistID = playlistStore.createPlaylist(named: newPlaylistName) {
                        playlistStore.addTrack(track, to: playlistID)
                        dismiss()
                    }
                }
                .disabled(newPlaylistName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}
