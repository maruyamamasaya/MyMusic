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
