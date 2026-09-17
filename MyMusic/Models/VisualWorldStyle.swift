import Foundation

/// Stable identifiers for the artwork shown on the Now Playing screen.
enum VisualWorldStyle: String, CaseIterable, Identifiable, Codable {
    case photonSphere = "simple-dark"
    case lightGates = "pulse-neon"
    case nightSky = "blue-cosmos"
    case twilight = "twilight"

    var id: String { rawValue }

    init?(rawValue: String) {
        switch rawValue {
        case "simple-dark", "living-aurora": self = .photonSphere
        case "pulse-neon": self = .lightGates
        case "blue-cosmos": self = .nightSky
        case "twilight": self = .twilight
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .photonSphere: "Photon Sphere"
        case .lightGates: "Pulse Neon"
        case .nightSky: "Blue Cosmos"
        case .twilight: "薄明"
        }
    }

    var detail: String {
        switch self {
        case .photonSphere: "光の球体"
        case .lightGates: "光のゲート"
        case .nightSky: "星が瞬く夜空"
        case .twilight: "雲と光がゆっくり移ろう空"
        }
    }

    var themePalette: AppTheme {
        AppTheme(rawValue: rawValue) ?? .livingAurora
    }
}
