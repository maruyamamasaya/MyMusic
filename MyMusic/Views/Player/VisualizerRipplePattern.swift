import Foundation

/// Stable for the lifetime of a detected attack. Variants are grouped by the
/// frequency range that excites them, then rotated by the burst serial.
nonisolated enum VisualizerRipplePattern {
    static let count = 8

    static func index(bass: Double, mid: Double, treble: Double, serial: Int) -> Int {
        let group: [Int]
        if bass >= mid && bass >= treble {
            group = [0, 1, 6]
        } else if mid >= treble {
            group = [3, 5, 7]
        } else {
            group = [2, 4]
        }
        return group[((serial % group.count) + group.count) % group.count]
    }
}
