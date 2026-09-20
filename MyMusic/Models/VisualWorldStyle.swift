import Foundation

/// Stable identifiers for the artwork shown on the Now Playing screen.
enum VisualWorldStyle: String, CaseIterable, Identifiable, Codable {
    case photonSphere = "simple-dark"
    case lightGates = "pulse-neon"
    case nightSky = "blue-cosmos"
    case twilight = "twilight"
    case plasmaSpark = "plasma-spark"
    case visualizer = "visualizer"

    var id: String { rawValue }

    init?(rawValue: String) {
        switch rawValue {
        case "simple-dark", "living-aurora": self = .photonSphere
        case "pulse-neon": self = .lightGates
        case "blue-cosmos": self = .nightSky
        case "twilight": self = .twilight
        case "plasma-spark": self = .plasmaSpark
        case "visualizer": self = .visualizer
        default: return nil
        }
    }

    var title: String {
        switch self {
        case .photonSphere: "Photon Sphere"
        case .lightGates: "Pulse Neon"
        case .nightSky: "Blue Cosmos"
        case .twilight: "薄明"
        case .plasmaSpark: "Plasma Spark"
        case .visualizer: "Visualizer"
        }
    }

    var detail: String {
        switch self {
        case .photonSphere: "光の球体"
        case .lightGates: "光のゲート"
        case .nightSky: "星が瞬く夜空"
        case .twilight: "雲と光がゆっくり移ろう空"
        case .plasmaSpark: "音に走る一瞬の稲妻"
        case .visualizer: "一本の波形・光子・波紋"
        }
    }

    var themePalette: AppTheme {
        AppTheme(rawValue: rawValue) ?? (self == .visualizer ? .pulseNeon : .livingAurora)
    }
}
