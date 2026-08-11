import SwiftUI

struct SongsView: View {
    @Environment(PlayerStore.self) private var playerStore
    @State private var trackToAddToPlaylist: Track?
    let tracks: [Track]

    init(tracks: [Track] = PreviewData.tracks) {
        self.tracks = tracks
    }

    var body: some View {
        List {
            if playerStore.currentTrack != nil {
                Section("Playing") {
                    SingleTrackControlsView()
                }
            }

            Section("Songs") {
                ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                    Button {
                        playerStore.playQueue(tracks, startingAt: index)
                    } label: {
                        HStack(spacing: 8) {
                            if playerStore.currentTrack?.id == track.id {
                                Image(systemName: playerStore.isPlaying ? "speaker.wave.2.fill" : "pause.fill")
                                    .foregroundStyle(.tint)
                                    .frame(width: 18)
                            }
                            TrackRowView(track: track)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button("Add to Playlist", systemImage: "text.badge.plus") {
                            trackToAddToPlaylist = track
                        }
                    }
                }
            }
        }
        .navigationTitle("Songs")
        .sheet(item: $trackToAddToPlaylist) { track in
            AddToPlaylistSheet(track: track)
        }
    }
}
