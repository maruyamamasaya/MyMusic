import SwiftUI

struct AlbumArtworkView: View {
    let artworkIdentifier: String?
    @State private var image: UIImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.secondary.opacity(0.15))

                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
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
