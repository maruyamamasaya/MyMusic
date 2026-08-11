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
        .alert("Playback Error", isPresented: errorIsPresented) {
            Button("OK") { playerStore.dismissError() }
        } message: {
            Text(playerStore.errorMessage ?? "Playback failed.")
        }
    }

    private var errorIsPresented: Binding<Bool> {
        Binding(
            get: { playerStore.errorMessage != nil },
            set: { if !$0 { playerStore.dismissError() } }
        )
    }
}
