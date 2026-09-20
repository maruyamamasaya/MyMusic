import CoreGraphics
import Foundation

/// Twenty-four authored, edge-to-edge silhouettes. Coordinates are in unit screen space.
nonisolated enum PlasmaSparkPattern {
    struct Design {
        let start: CGPoint
        let end: CGPoint
        let bends: [CGFloat]
    }

    static let designs: [Design] = [
        .init(start: .init(x: 0, y: 0.27), end: .init(x: 1, y: 0.61), bends: [0.025,-0.052,0.083,-0.031,0.054,-0.071,0.033]),
        .init(start: .init(x: 1, y: 0.19), end: .init(x: 0, y: 0.73), bends: [-0.042,0.019,-0.075,0.066,-0.038,0.082,-0.024]),
        .init(start: .init(x: 0, y: 0.49), end: .init(x: 1, y: 0.31), bends: [0.052,0.087,-0.013,-0.078,-0.024,0.061,0.012]),
        .init(start: .init(x: 1, y: 0.82), end: .init(x: 0, y: 0.36), bends: [0.016,-0.047,-0.096,-0.012,0.073,0.029,-0.047]),
        .init(start: .init(x: 0, y: 0.74), end: .init(x: 1, y: 0.47), bends: [-0.028,-0.081,0.012,0.068,0.099,-0.025,-0.069]),
        .init(start: .init(x: 0.23, y: 0), end: .init(x: 0.72, y: 1), bends: [0.044,-0.034,-0.089,-0.016,0.059,0.014,-0.053]),
        .init(start: .init(x: 0.79, y: 1), end: .init(x: 0.29, y: 0), bends: [-0.048,0.018,0.077,-0.009,-0.083,-0.021,0.041]),
        .init(start: .init(x: 0.43, y: 0), end: .init(x: 0.18, y: 1), bends: [0.025,0.071,-0.012,-0.067,0.006,0.064,-0.021]),
        .init(start: .init(x: 0.11, y: 1), end: .init(x: 0.55, y: 0), bends: [-0.029,-0.067,0.021,0.085,0.012,-0.044,0.036]),
        .init(start: .init(x: 0.62, y: 0), end: .init(x: 0.91, y: 1), bends: [0.051,-0.017,-0.073,-0.035,0.049,0.091,0.018]),
        .init(start: .init(x: 0, y: 0.11), end: .init(x: 1, y: 0.88), bends: [-0.031,0.055,0.091,0.019,-0.047,-0.083,0.014]),
        .init(start: .init(x: 1, y: 0.08), end: .init(x: 0, y: 0.91), bends: [0.035,0.074,-0.022,-0.087,-0.039,0.058,0.019]),
        .init(start: .init(x: 0.05, y: 0), end: .init(x: 0.97, y: 1), bends: [0.017,-0.061,0.029,0.094,0.022,-0.069,-0.017]),
        .init(start: .init(x: 0.95, y: 0), end: .init(x: 0.03, y: 1), bends: [-0.029,0.065,0.012,-0.081,-0.012,0.073,0.031]),
        .init(start: .init(x: 0.14, y: 1), end: .init(x: 0.98, y: 0), bends: [0.049,0.012,-0.064,-0.097,-0.017,0.068,0.025]),
        .init(start: .init(x: 0.87, y: 1), end: .init(x: 0.02, y: 0), bends: [-0.014,-0.073,0.009,0.083,0.046,-0.045,-0.082]),
        .init(start: .init(x: 0, y: 0.42), end: .init(x: 1, y: 0.79), bends: [0.074,0.028,-0.044,-0.095,-0.016,0.054,-0.029]),
        .init(start: .init(x: 1, y: 0.53), end: .init(x: 0, y: 0.16), bends: [-0.066,-0.013,0.082,0.031,-0.058,-0.097,-0.025]),
        .init(start: .init(x: 0.33, y: 0), end: .init(x: 0.61, y: 1), bends: [-0.075,-0.016,0.058,0.093,0.004,-0.051,0.026]),
        .init(start: .init(x: 0.68, y: 1), end: .init(x: 0.39, y: 0), bends: [0.068,0.019,-0.052,-0.013,0.084,0.032,-0.037]),
        .init(start: .init(x: 0, y: 0.06), end: .init(x: 1, y: 0.38), bends: [-0.018,0.046,0.091,0.027,-0.064,-0.021,0.052]),
        .init(start: .init(x: 1, y: 0.94), end: .init(x: 0, y: 0.64), bends: [0.027,-0.053,-0.014,0.078,0.033,-0.087,-0.041]),
        .init(start: .init(x: 0.08, y: 0), end: .init(x: 0.92, y: 1), bends: [-0.043,0.025,0.084,0.011,-0.075,-0.034,0.049]),
        .init(start: .init(x: 0.96, y: 1), end: .init(x: 0.12, y: 0), bends: [0.036,0.082,0.009,-0.063,-0.012,0.071,-0.028])
    ]

    static func points(seed: Double, serial: Int, mid: Double) -> [CGPoint] {
        let seedIndex = Int((abs(seed).truncatingRemainder(dividingBy: 1) * Double(designs.count)).rounded(.down))
        let design = designs[(seedIndex + serial * 7) % designs.count]
        let dx = design.end.x - design.start.x
        let dy = design.end.y - design.start.y
        let length = hypot(dx, dy)
        let normal = CGPoint(x: -dy / length, y: dx / length)
        let knots: [CGFloat] = [0, 0.11, 0.22, 0.35, 0.47, 0.59, 0.73, 0.86, 1]
        let amplitude = CGFloat(0.88 + min(1, max(0, mid)) * 0.24)
        return knots.enumerated().map { index, q in
            let bend = index == 0 || index == 8 ? 0 : design.bends[index - 1] * amplitude
            return CGPoint(x: design.start.x + dx * q + normal.x * bend,
                           y: design.start.y + dy * q + normal.y * bend)
        }
    }

    /// Two narrow forks continue from the main path to a screen edge.
    static func branches(seed: Double, serial: Int, mid: Double) -> [[CGPoint]] {
        let points = points(seed: seed, serial: serial, mid: mid)
        let seedIndex = Int((abs(seed).truncatingRemainder(dividingBy: 1) * Double(designs.count)).rounded(.down))
        let designIndex = (seedIndex + serial * 7) % designs.count
        return (0..<2).map { branch in
            let anchor = branch == 0 ? 2 + designIndex % 2 : 5 + designIndex % 2
            let base = points[anchor]
            let tangent = CGPoint(x: points[anchor+1].x-points[anchor-1].x,
                                  y: points[anchor+1].y-points[anchor-1].y)
            let length = max(0.001,hypot(tangent.x,tangent.y))
            let normal = CGPoint(x: -tangent.y/length,y: tangent.x/length)
            let side: CGFloat = (designIndex + branch).isMultiple(of: 2) ? 1 : -1
            let direction = CGPoint(x: tangent.x/length*0.28+normal.x*side*0.96,
                                    y: tangent.y/length*0.28+normal.y*side*0.96)
            let edgeX = direction.x > 0 ? (1-base.x)/direction.x : direction.x < 0 ? -base.x/direction.x : .infinity
            let edgeY = direction.y > 0 ? (1-base.y)/direction.y : direction.y < 0 ? -base.y/direction.y : .infinity
            let reach = min(edgeX, edgeY)
            let tip = CGPoint(x: min(1,max(0,base.x+direction.x*reach)),
                              y: min(1,max(0,base.y+direction.y*reach)))
            let sign: CGFloat = (designIndex + branch).isMultiple(of: 3) ? 1 : -1
            let turns: [(CGFloat,CGFloat)] = [(0,0),(0.24,0.028),(0.49,-0.034),(0.75,0.022),(1,0)]
            return turns.enumerated().map { index, turn in
                if index == 4 { return tip }
                return CGPoint(x: base.x+direction.x*reach*turn.0+normal.x*turn.1*sign,
                               y: base.y+direction.y*reach*turn.0+normal.y*turn.1*sign)
            }
        }
    }
}
