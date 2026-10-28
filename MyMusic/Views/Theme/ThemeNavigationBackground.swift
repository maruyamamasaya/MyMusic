import SwiftUI
import UIKit

/// Puts the fixed texture in the native bar's background, below both title sizes and buttons.
@MainActor
enum ThemeNavigationBackground {
    private static var cachedKey = ""
    private static var cachedImage: UIImage?

    static func style(theme: AppTheme, viewport: CGSize?, opaque: Bool) -> AnyShapeStyle {
        guard !opaque, theme != .simpleDark, let viewport,
              viewport.width > 0, viewport.height > 0 else { return AnyShapeStyle(Color.black) }
        let key = "\(theme.rawValue)-\(viewport.width)-\(viewport.height)"
        if key != cachedKey {
            let renderer = ImageRenderer(content:
                ThemeBackground(theme: theme, extendsIntoSafeArea: false)
                    .environment(\.themeBackgroundViewport, nil)
                    .frame(width: viewport.width, height: viewport.height)
            )
            renderer.scale = 2
            if let full = renderer.cgImage {
                // Keep only the upper band, enough for expanded navigation titles.
                let height = min(full.height, 480)
                if let crop = full.cropping(to: CGRect(x: 0, y: 0, width: full.width, height: height)) {
                    cachedImage = UIImage(cgImage: crop, scale: 2, orientation: .up)
                    cachedKey = key
                }
            }
        }
        guard let image = cachedImage else { return AnyShapeStyle(Color.black) }
        return AnyShapeStyle(ImagePaint(image: Image(uiImage: image), scale: 1))
    }
}
