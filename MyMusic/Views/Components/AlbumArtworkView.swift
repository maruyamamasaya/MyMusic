import SwiftUI

struct AlbumArtworkView: View {
    let artworkIdentifier: String?
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(.secondary.opacity(0.15))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "music.note")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityLabel(image == nil ? "アートワークなし" : "アルバムアートワーク")
        .aspectRatio(1, contentMode: .fit)
        .task(id: artworkIdentifier) {
            image = nil
            guard let artworkIdentifier,
                  let data = await ArtworkService.shared.artworkData(for: artworkIdentifier) else { return }
            image = UIImage(data: data)
        }
    }
}
