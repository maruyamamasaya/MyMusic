import SwiftUI

struct TrackRowView: View {
    let track: Track
    var body: some View {
        HStack(spacing: 12) {
            AlbumArtworkView(artworkIdentifier: track.artworkIdentifier).frame(width: 48)
            VStack(alignment: .leading) {
                Text(track.title).lineLimit(1)
                Text([track.artistName, track.albumTitle].compactMap { $0 }.joined(separator: " • ")).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            Text(TimeFormatter.string(from: track.duration)).font(.caption).foregroundStyle(.secondary).monospacedDigit()
            Image(systemName: "ellipsis").foregroundStyle(.secondary)
        }
    }
}
