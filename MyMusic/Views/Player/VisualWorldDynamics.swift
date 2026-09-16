import Foundation

/// Display-only envelopes and a pauseable clock; does not detect beats or frequency bands.
nonisolated struct VisualWorldDynamics {
    private(set) var time = 0.0
    private(set) var level = 0.0
    private(set) var width = 0.0
    private(set) var balance = 0.0
    private(set) var impulse = 0.0
    private var slowLevel = 0.0
    private var previousDate: Date?

    mutating func suspend() { previousDate = nil }

    mutating func advance(date: Date, level rawLevel: Double, width rawWidth: Double,
                          balance rawBalance: Double, speed: Double) {
        guard let previousDate else {
            self.previousDate = date
            return
        }
        let dt = min(max(date.timeIntervalSince(previousDate), 0), 0.1)
        self.previousDate = date
        time += dt * (0.35 + Self.unit(speed) * 0.75)
        let target = Self.unit(rawLevel)
        level += (target - level) * (1 - exp(-dt / (target > level ? 0.075 : 0.42)))
        slowLevel += (target - slowLevel) * (1 - exp(-dt / 0.8))
        width += (Self.unit(rawWidth) - width) * (1 - exp(-dt / 0.3))
        let targetBalance = rawBalance.isFinite ? min(max(rawBalance, -1), 1) : 0
        balance += (targetBalance - balance) * (1 - exp(-dt / 0.25))
        impulse = max(impulse * exp(-dt / 0.45), min(max(level - slowLevel - 0.035, 0) * 3, 1))
    }

    static func unit(_ value: Double) -> Double { value.isFinite ? min(max(value, 0), 1) : 0 }
}
