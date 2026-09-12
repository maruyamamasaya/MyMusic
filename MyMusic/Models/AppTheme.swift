import Foundation

/// Stable preference identifiers; visual tokens belong to the presentation layer.
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case simpleDark = "simple-dark"
    case livingAurora = "living-aurora"
    case pulseNeon = "pulse-neon"
    case blueCosmos = "blue-cosmos"

    var id: String { rawValue }
}
