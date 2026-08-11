import UIKit

extension UIImage {
    nonisolated func squareCropped(to targetSize: CGSize) -> UIImage {
        guard size.width > 0, size.height > 0, targetSize.width > 0, targetSize.height > 0 else { return self }
        let scale = max(targetSize.width / size.width, targetSize.height / size.height)
        let drawSize = CGSize(width: size.width * scale, height: size.height * scale)
        let origin = CGPoint(
            x: (targetSize.width - drawSize.width) / 2,
            y: (targetSize.height - drawSize.height) / 2
        )
        return UIGraphicsImageRenderer(size: targetSize).image { _ in
            draw(in: CGRect(origin: origin, size: drawSize))
        }
    }
}
