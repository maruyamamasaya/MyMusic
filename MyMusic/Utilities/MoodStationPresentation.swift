import Foundation

extension StationMood {
    var title: String {
        switch self {
        case .relax: "落ち着きたい"
        case .uplift: "気分を上げたい"
        case .focus: "集中したい"
        case .immerse: "浸りたい"
        case .stimulate: "刺激がほしい"
        case .surprise: "特に決めずに任せたい"
        }
    }

    var symbol: String {
        switch self {
        case .relax: "leaf"
        case .uplift: "sun.max"
        case .focus: "scope"
        case .immerse: "moon.stars"
        case .stimulate: "bolt"
        case .surprise: "sparkles"
        }
    }
}

extension StationSound {
    var title: String {
        switch self {
        case .any: "指定しない"
        case .vocals: "ボーカル"
        case .instrumental: "インストゥルメンタル"
        case .electronic: "電子的な音"
        case .ambient: "アンビエントな音"
        case .piano: "ピアノ"
        }
    }

    var symbol: String {
        switch self {
        case .any: "slider.horizontal.3"
        case .vocals: "person.wave.2"
        case .instrumental: "music.note"
        case .electronic: "waveform.path.ecg"
        case .ambient: "cloud"
        case .piano: "pianokeys"
        }
    }
}

extension StationAnswers {
    var summary: String {
        [mood.title, sound.title].joined(separator: " · ")
    }
}
