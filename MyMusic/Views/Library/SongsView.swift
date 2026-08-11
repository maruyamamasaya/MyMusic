import SwiftUI

struct SongsView: View {
    @Environment(PlayerStore.self) private var playerStore
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
                ForEach(tracks) { track in
                    Button {
                        playerStore.play(track)
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
                }
            }
        }
        .navigationTitle("Songs")
    }
}
