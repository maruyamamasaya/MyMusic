import SwiftUI

struct NowPlayingView: View {
    let track: Track?
    let isPlaying: Bool
    var body: some View { VStack(spacing: 28) { Spacer(); AlbumArtworkView(artworkIdentifier: track?.artworkIdentifier).frame(maxWidth: 340); VStack { Text(track?.title ?? "Not Playing").font(.title2.bold()); Text(track?.artistName ?? "Choose a song").foregroundStyle(.secondary) }; ProgressBarView(currentTime: 0, duration: track?.duration ?? 0); PlaybackControlsView(isPlaying: isPlaying); Spacer() }.padding() }
}
