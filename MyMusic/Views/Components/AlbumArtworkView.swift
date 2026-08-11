import SwiftUI

enum AlbumArtworkDisplayMode {
    case fill
    case fitWithBlurredBackground
}

struct AlbumArtworkView: View {
    let artworkIdentifier: String?
    var displayMode: AlbumArtworkDisplayMode = .fill
    @State private var image: UIImage?

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
            image = nil
            guard let artworkIdentifier,
                  let data = await ArtworkService.shared.artworkData(for: artworkIdentifier) else { return }
            image = UIImage(data: data)
        }
    }
}
