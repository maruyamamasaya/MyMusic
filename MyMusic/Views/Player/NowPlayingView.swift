import SwiftUI

struct NowPlayingView: View {
    @Environment(PlayerStore.self) private var playerStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                AlbumArtworkView(artworkIdentifier: playerStore.currentTrack?.artworkIdentifier)
                    .frame(maxWidth: 320)

                VStack(spacing: 6) {
                    Text(playerStore.currentTrack?.title ?? "Not Playing")
                        .font(.title2.bold())
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                    Text(playerStore.currentTrack?.artistName ?? "")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Now Playing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
