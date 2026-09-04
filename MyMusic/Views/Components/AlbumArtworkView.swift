import SwiftUI

enum AlbumArtworkDisplayMode {
    case fill
    case fitWithBlurredBackground
}

struct AlbumArtworkView: View {
    let artworkIdentifier: String?
    var displayMode: AlbumArtworkDisplayMode = .fill
    @State private var loadedArtwork: LoadedArtworkImage?

    private var image: UIImage? { loadedArtwork?.image }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.secondary.opacity(0.15))

                if let image {
                    switch displayMode {
                    case .fill:
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    case .fitWithBlurredBackground:
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                            .scaleEffect(1.12)
                            .blur(radius: 20)
                            .overlay(.black.opacity(0.12))

                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(width: proxy.size.width, height: proxy.size.height)
                    }
                } else {
                    Image(systemName: "music.note")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .accessibilityLabel(image == nil ? "アートワークなし" : "アルバムアートワーク")
        .aspectRatio(1, contentMode: .fit)
        .task(id: artworkIdentifier) {
            guard loadedArtwork?.identifier != artworkIdentifier else { return }
            let loadedImage: UIImage? = if let artworkIdentifier {
                await ArtworkService.shared.artworkImage(for: artworkIdentifier)
            } else {
                nil
            }
            guard !Task.isCancelled else { return }
            loadedArtwork = LoadedArtworkImage(identifier: artworkIdentifier, image: loadedImage)
        }
    }
}

private struct LoadedArtworkImage {
    let identifier: String?
    let image: UIImage?
}
