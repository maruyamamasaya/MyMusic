import SwiftUI

/// A tessellated optical-glass field. Deterministic facets, no timers or blur.
struct PulseNeonLighting: View {
    let palette: ThemePalette

    private enum Glass {
        static let columns = 5
        static let rowHeight: CGFloat = 115
        static let edgeWidth: CGFloat = 0.45
        static let edgeOpacity = 0.18
        static let reflectionOpacity = 0.08
    }

    var body: some View {
        Canvas { context, size in
            let rows = max(3, Int(ceil(size.height / Glass.rowHeight)))
            let cellWidth = size.width / CGFloat(Glass.columns)
            let cellHeight = size.height / CGFloat(rows)
            func point(_ column: Int, _ row: Int) -> CGPoint {
                let shift = row.isMultiple(of: 2) ? 0.0 : 0.35
                return CGPoint(x: (CGFloat(column) + shift) * cellWidth,
                               y: CGFloat(row) * cellHeight)
            }
            for row in 0..<rows {
                for column in -1..<Glass.columns {
                    let a = point(column, row)
                    let b = point(column + 1, row)
                    let c = point(column + 1, row + 1)
                    let d = point(column, row + 1)
                    let triangles = [[a, b, d], [b, c, d]]
                    for (index, points) in triangles.enumerated() {
                        var facet = Path()
                        facet.addLines(points)
                        facet.closeSubpath()
                        let color = (row + column + index).isMultiple(of: 3) ? palette.accent : palette.light
                        let bright = (row * 7 + column * 3 + index).isMultiple(of: 5)
                        context.fill(facet, with: .linearGradient(
                            Gradient(colors: [color.opacity(bright ? Glass.reflectionOpacity : 0.018), .clear]),
                            startPoint: points[0], endPoint: points[2]))
                        context.stroke(facet, with: .color(color.opacity(Glass.edgeOpacity)),
                                       lineWidth: Glass.edgeWidth)
                        if bright {
                            var edge = Path()
                            edge.move(to: points[0]); edge.addLine(to: points[1])
                            context.stroke(edge, with: .linearGradient(
                                Gradient(colors: [.clear, color.opacity(0.65), .clear]),
                                startPoint: points[0], endPoint: points[1]), lineWidth: 0.7)
                        }
                    }
                }
            }
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
