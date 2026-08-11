import SwiftUI

struct PlaylistDetailView: View {
    @Environment(PlaylistStore.self) private var playlistStore
    @Environment(LibraryStore.self) private var libraryStore
    @Environment(PlayerStore.self) private var playerStore
    let playlistID: Playlist.ID

    private var playlist: Playlist? { playlistStore.playlist(id: playlistID) }
    private var tracks: [Track] { playlistStore.tracks(for: playlistID, in: libraryStore.tracks) }

    var body: some View {
        List {
            if let playlist {
                Section {
                    HStack(spacing: 12) {
                        Button("Play", systemImage: "play.fill") { play(shuffled: false) }
                            .buttonStyle(.borderedProminent)
                            .disabled(tracks.isEmpty)
                        Button("Shuffle", systemImage: "shuffle") { play(shuffled: true) }
                            .buttonStyle(.bordered)
                            .disabled(tracks.isEmpty)
                    }
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                }

                Section("Songs") {
                    if tracks.isEmpty {
                        ContentUnavailableView(
                            "No Available Songs",
                            systemImage: "music.note.list",
                            description: Text("Add songs from the library, or rescan if files are unavailable.")
                        )
                    } else {
                        ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                            Button { playerStore.playQueue(tracks, startingAt: index) } label: {
                                TrackRowView(track: track)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions {
                                Button("Remove", systemImage: "trash", role: .destructive) {
                                    playlistStore.removeTrack(track.id, from: playlistID)
                                }
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView("Playlist Not Found", systemImage: "questionmark.folder")
            }
        }
        .navigationTitle(playlist?.name ?? "Playlist")
        .navigationBarTitleDisplayMode(.large)
    }

    private func play(shuffled: Bool) {
        guard !tracks.isEmpty else { return }
        playerStore.setShuffleEnabled(shuffled)
        playerStore.playQueue(tracks, startingAt: 0)
    }
}
