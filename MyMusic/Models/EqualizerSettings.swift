import Foundation

struct EqualizerBand: Codable, Hashable, Identifiable, Sendable {
    let frequency: Double
    var gain: Float

    var id: Double { frequency }
}

struct EqualizerSettings: Codable, Hashable, Sendable {
    static let frequencies: [Double] = [31, 62, 125, 250, 500, 1_000, 2_000, 4_000, 8_000, 16_000]

    var isEnabled: Bool
    var preamp: Float
    var bands: [EqualizerBand]

    static let flat = EqualizerSettings(
        isEnabled: false,
        preamp: 0,
        bands: frequencies.map { EqualizerBand(frequency: $0, gain: 0) }
    )

    mutating func normalize() {
        let savedGains = Dictionary(uniqueKeysWithValues: bands.map { ($0.frequency, $0.gain) })
        bands = Self.frequencies.map {
            EqualizerBand(frequency: $0, gain: min(max(savedGains[$0] ?? 0, -12), 12))
        }
        preamp = min(max(preamp, -12), 0)
    }
}

struct EqualizerPreset: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var preamp: Float
    var gains: [Float]
    let isBuiltIn: Bool

    init(id: UUID = UUID(), name: String, preamp: Float, gains: [Float], isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.preamp = preamp
        self.gains = gains
        self.isBuiltIn = isBuiltIn
    }

    func settings(isEnabled: Bool = true) -> EqualizerSettings {
        let normalizedGains = Array((gains + Array(repeating: 0, count: EqualizerSettings.frequencies.count)).prefix(EqualizerSettings.frequencies.count))
        return EqualizerSettings(
            isEnabled: isEnabled,
            preamp: preamp,
            bands: zip(EqualizerSettings.frequencies, normalizedGains).map {
                EqualizerBand(frequency: $0.0, gain: $0.1)
            }
        )
    }

    static let builtIns: [EqualizerPreset] = [
        EqualizerPreset(name: "フラット", preamp: 0, gains: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0], isBuiltIn: true),
        EqualizerPreset(name: "ロック", preamp: -3, gains: [4, 3, 2, 0, -1, 1, 3, 4, 4, 3], isBuiltIn: true),
        EqualizerPreset(name: "ポップ", preamp: -3, gains: [-1, 1, 3, 4, 2, 0, 1, 3, 4, 2], isBuiltIn: true),
        EqualizerPreset(name: "ジャズ", preamp: -2.5, gains: [3, 2, 1, 2, -1, -1, 0, 2, 3, 4], isBuiltIn: true),
        EqualizerPreset(name: "クラシック", preamp: -2, gains: [3, 2, 1, 0, -1, -1, 0, 2, 3, 4], isBuiltIn: true),
        EqualizerPreset(name: "エレクトロニック", preamp: -4, gains: [5, 4, 1, 0, -2, 1, 2, 3, 5, 4], isBuiltIn: true),
        EqualizerPreset(name: "ボーカル", preamp: -2.5, gains: [-2, -1, 0, 2, 4, 4, 3, 2, 0, -1], isBuiltIn: true),
        EqualizerPreset(name: "低音強調", preamp: -5, gains: [6, 5, 4, 2, 0, -1, -2, -2, -1, 0], isBuiltIn: true),
        EqualizerPreset(name: "高音強調", preamp: -4, gains: [-2, -2, -1, 0, 1, 2, 4, 5, 6, 5], isBuiltIn: true)
    ]
}
