import SwiftUI

struct MiniPlayerView: View {
    let track: Track?
    let isPlaying: Bool
    let onPlayPause: () -> Void
    var body: some View {
        HStack { AlbumArtworkView(artworkIdentifier: track?.artworkIdentifier).frame(width: 44); VStack(alignment: .leading) { Text(track?.title ?? "Not Playing").lineLimit(1); Text(track?.artistName ?? "Choose a song").font(.caption).foregroundStyle(.secondary) }; Spacer(); Button(action: onPlayPause) { Image(systemName: isPlaying ? "pause.fill" : "play.fill") }.buttonStyle(.plain) }.padding(.horizontal).padding(.vertical, 8).background(.bar)
    }
}
