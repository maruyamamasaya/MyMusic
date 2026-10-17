import Combine
import Observation
import UIKit

/// Notification-driven monitoring, scoped to the visible, active scenery HUD.
@MainActor
@Observable
final class SceneryBatteryService {
    private(set) var percentage: Int?
    private(set) var isCharging = false
    @ObservationIgnored private var subscriptions = Set<AnyCancellable>()
    @ObservationIgnored private var previousMonitoring: Bool?

    func start() {
        guard previousMonitoring == nil else { return }
        let device = UIDevice.current
        previousMonitoring = device.isBatteryMonitoringEnabled
        device.isBatteryMonitoringEnabled = true
        refresh()
        NotificationCenter.default.publisher(for: UIDevice.batteryLevelDidChangeNotification)
            .merge(with: NotificationCenter.default.publisher(for: UIDevice.batteryStateDidChangeNotification))
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            }
            .store(in: &subscriptions)
    }

    func stop() {
        subscriptions.removeAll()
        if let previousMonitoring {
            UIDevice.current.isBatteryMonitoringEnabled = previousMonitoring
        }
        previousMonitoring = nil
    }

    private func refresh() {
        let device = UIDevice.current
        let level = device.batteryLevel
        isCharging = device.batteryState == .charging || device.batteryState == .full
        percentage = level.isFinite && level >= 0 && level <= 1
            ? Int((level * 100).rounded()) : nil
    }
}
