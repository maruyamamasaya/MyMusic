import SwiftUI

/// Stable, irregular night sky; density scales with area rather than stretching a fixed grid.
struct CosmosStarField: View {
    var body: some View {
        Canvas { context, size in
            let count = min(240, max(45, Int(size.width * size.height / 1800)))
            for index in 0..<count {
                let xSeed: Int = (index * 127 + 43) % 997
                let square: Int = index * index
                let ySeed: Int = (square * 31 + index * 71 + 19) % 991
                let x: CGFloat = CGFloat(xSeed) / 997.0 * size.width
                let y: CGFloat = CGFloat(ySeed) / 991.0 * size.height
                let bright = index.isMultiple(of: 17)
                let medium = index.isMultiple(of: 5)
                let diameter: CGFloat = bright ? 1.8 : (medium ? 1.1 : 0.65)
                let opacity = bright ? 0.78 : (medium ? 0.43 : 0.22)
                let color: Color = index.isMultiple(of: 3) ? Color(red: 0.68, green: 0.80, blue: 1) : .white
                if bright {
                    let halo = CGRect(x: x - 3, y: y - 3, width: 6, height: 6)
                    context.fill(Path(ellipseIn: halo), with: .radialGradient(
                        Gradient(colors: [color.opacity(0.20), .clear]),
                        center: CGPoint(x: x, y: y), startRadius: 0, endRadius: 3))
                }
                context.fill(Path(ellipseIn: CGRect(x: x - diameter / 2, y: y - diameter / 2,
                                                    width: diameter, height: diameter)),
                             with: .color(color.opacity(opacity)))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
