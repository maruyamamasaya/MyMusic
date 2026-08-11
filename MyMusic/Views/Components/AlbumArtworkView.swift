import SwiftUI

struct AlbumArtworkView: View {
    let artworkIdentifier: String?

    var body: some View {
        RoundedRectangle(cornerRadius: 10)
            .fill(.secondary.opacity(0.15))
            .overlay { Image(systemName: "music.note").font(.largeTitle).foregroundStyle(.secondary) }
            .accessibilityLabel(artworkIdentifier == nil ? "No album artwork" : "Album artwork")
            .aspectRatio(1, contentMode: .fit)
    }
}
