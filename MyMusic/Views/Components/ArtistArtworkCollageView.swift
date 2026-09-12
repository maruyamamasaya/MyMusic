import SwiftUI

struct ArtistArtworkCollageView: View {
    let artworkIdentifiers: [String?]

    private let tileSpacing: CGFloat = 3
    private let cornerRadius: CGFloat = 22

    var body: some View {
        ZStack {
            collage
                .scaleEffect(1.12)
                .blur(radius: 28)
                .saturation(1.35)
                .opacity(0.7)

            RadialGradient(
                colors: [.white.opacity(0.42), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 150
            )
            .scaleEffect(1.22)
            .blur(radius: 18)
            .blendMode(.screen)

            collage
                .shadow(color: .black.opacity(0.24), radius: 18, y: 10)
                .overlay {
                    LinearGradient(
                        colors: [.white.opacity(0.22), .clear, .black.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                    .allowsHitTesting(false)
                }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("アーティストのアルバムアートワーク")
    }

    private var collage: some View {
        GeometryReader { proxy in
            let tileLength = (min(proxy.size.width, proxy.size.height) - tileSpacing) / 2

            LazyVGrid(
                columns: Array(repeating: GridItem(.fixed(tileLength), spacing: tileSpacing), count: 2),
                spacing: tileSpacing
            ) {
                ForEach(Array(normalizedArtworkIdentifiers.enumerated()), id: \.offset) { _, identifier in
                    AlbumArtworkView(artworkIdentifier: identifier)
                        .frame(width: tileLength, height: tileLength)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    private var normalizedArtworkIdentifiers: [String?] {
        var identifiers = Array(artworkIdentifiers.prefix(4))
        identifiers.append(contentsOf: repeatElement(nil, count: max(0, 4 - identifiers.count)))
        return identifiers
    }
}
