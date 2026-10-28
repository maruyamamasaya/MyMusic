import Foundation

/// Stable preference identifiers; visual tokens belong to the presentation layer.
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case simpleDark = "simple-dark"
    case livingAurora = "living-aurora"
    case pulseNeon = "pulse-neon"
    case blueCosmos = "blue-cosmos"
    case amberLounge = "amber-lounge"
    case sumiWashi = "sumi-washi"
    case reimei = "reimei"

    var id: String { rawValue }
}
