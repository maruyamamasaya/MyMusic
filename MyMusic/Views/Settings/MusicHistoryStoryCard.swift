import SwiftUI

struct MusicHistoryStoryCard: View {
    let card: MusicHistoryCardCandidate
    let play: () -> Void

    var body: some View {
        Button(action: play) {
            HStack(alignment: .top, spacing: 16) {
                if let track = card.mainTrack {
                    AlbumArtworkView(artworkIdentifier: track.artworkIdentifier)
                        .frame(width: 104, height: 104)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .accessibilityHidden(true)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(card.title)
                        .font(.headline)
                        .foregroundStyle(.tint)
                    if let track = card.mainTrack {
                        Text(card.albumTitle ?? card.artistNames.first ?? track.title)
                            .font(.title3.weight(.semibold))
                            .lineLimit(2)
                    }
                    Text(card.subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    if card.tracks.count > 1 {
                        Text(card.tracks.dropFirst().map(\.title).joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    if card.mainTrack != nil {
                        Label("この記憶を再生", systemImage: "play.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tint)
                            .padding(.top, 2)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(.secondary.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}
