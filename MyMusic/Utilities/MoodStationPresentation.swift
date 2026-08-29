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
        case .soft: "静かでやわらかい"
        case .light: "軽くて心地いい"
        case .rhythmic: "リズムに乗れる"
        case .heavy: "重くて力強い"
        case .bright: "明るく華やか"
        case .dark: "暗くて深い"
        }
    }

    var symbol: String {
        switch self {
        case .soft: "cloud"
        case .light: "wind"
        case .rhythmic: "waveform"
        case .heavy: "flame"
        case .bright: "sparkles"
        case .dark: "moon"
        }
    }
}

extension StationRefinement {
    var firstTitle: String {
        switch self {
        case .vocals: "歌を聴きたい"
        case .texture: "生っぽい"
        case .intensity: "穏やか"
        }
    }

    var secondTitle: String {
        switch self {
        case .vocals: "音そのものを楽しみたい"
        case .texture: "電子的"
        case .intensity: "激しい"
        }
    }

    var explanation: String {
        switch self {
        case .vocals: "ボーカルとインスト、今はどちらを楽しみたい？"
        case .texture: "電子音の少なさ・多さを目安に、音色を選びます。"
        case .intensity: "最後に、音の勢いを少しだけ調整します。"
        }
    }
}

extension StationAnswers {
    var summary: String {
        var parts = [mood.title, sound.title]
        if let refinement, let direction {
            parts.append(direction == .first ? refinement.firstTitle : refinement.secondTitle)
        }
        return parts.joined(separator: " · ")
    }
}
