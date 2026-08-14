import SwiftUI

struct PlayableTrackRowView: View {
    let track: Track
    var showsArtwork = true
    let onPlay: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Button(action: onPlay) {
                TrackRowView(track: track, showsArtwork: showsArtwork)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            TrackFavoriteButton(track: track)
        }
    }
}
