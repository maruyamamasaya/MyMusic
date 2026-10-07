import Foundation

/// warmUp returns only after synchronously stopping and disposing its queue.
@MainActor
enum HiResRatePreparation {
    static func run(
        deactivate: () throws -> Void,
        wait: (Int) async throws -> Void,
        configure: () throws -> Void,
        activate: () throws -> Void,
        warmUp: (Int) async throws -> Double?
    ) async throws -> Double? {
        var hardwareRate: Double?
        for attempt in 0..<2 {
            try Task.checkCancellation()
            try deactivate()
            try await wait(attempt == 0 ? 300 : 160)
            try Task.checkCancellation()
            try configure()
            try activate()
            hardwareRate = try await warmUp(attempt)
            try Task.checkCancellation()
        }
        return hardwareRate
    }
}
