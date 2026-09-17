import Foundation

/// Display-only level envelope and a pauseable clock.
nonisolated struct VisualWorldDynamics {
    private(set) var time = 0.0
    private(set) var level = 0.0
    private var previousDate: Date?

    mutating func suspend() { previousDate = nil }

    mutating func advance(date: Date, level rawLevel: Double, speed: Double) {
        guard let previousDate else {
            self.previousDate = date
            return
        }
        let dt = min(max(date.timeIntervalSince(previousDate), 0), 0.1)
        self.previousDate = date
        time += dt * (0.35 + Self.unit(speed) * 0.75)
        let target = Self.unit(rawLevel)
        level += (target - level) * (1 - exp(-dt / (target > level ? 0.075 : 0.42)))
    }

    static func unit(_ value: Double) -> Double { value.isFinite ? min(max(value, 0), 1) : 0 }
}
