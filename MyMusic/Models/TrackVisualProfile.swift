import Foundation

/// Slowly changing character of a track. Realtime spectrum and beats remain in VisualWorldSimulation.
nonisolated struct TrackVisualProfile: Equatable, Sendable {
    var energy: Float = 0.5
    var bassWeight: Float = 0.5
    var trebleWeight: Float = 0.5
    var rhythmicity: Float = 0.5
    var atmospheric: Float = 0.5
    var aggression: Float = 0.5
    var calmness: Float = 0.5
    var brightness: Float = 0.5

    static func make(from values: TrackFeatureValues?) -> Self {
        guard let values else { return Self() }
        func score(_ value: Double?) -> Float {
            guard let value, value.isFinite else { return 0.5 }
            return Float(min(max(value, 0), 1))
        }
        let energy = score(values.energy)
        let calm = score(values.calm)
        let bright = score(values.bright)
        let dark = score(values.dark)
        let rhythmic = score(values.electronic) * 0.6 + score(values.drumAndBass) * 0.4
        // The imported feature schema has no measured low/high frequency balance.
        // These are deliberately modest tendencies, never substitutes for the live spectrum.
        let bass = 0.5 + (score(values.drumAndBass) - 0.5) * 0.5 + (dark - 0.5) * 0.2
        let treble = 0.5 + (bright - 0.5) * 0.5 - (dark - 0.5) * 0.15
        return Self(energy: energy, bassWeight: min(max(bass, 0), 1),
                    trebleWeight: min(max(treble, 0), 1), rhythmicity: rhythmic,
                    atmospheric: score(values.ambient), aggression: score(values.aggressive),
                    calmness: calm, brightness: bright)
    }

    func approaching(_ target: Self, dt: Double) -> Self {
        let amount = Float(1 - exp(-min(max(dt, 0), 0.1) / 1.15))
        func blend(_ a: Float, _ b: Float) -> Float { a + (b - a) * amount }
        return Self(energy: blend(energy, target.energy),
                    bassWeight: blend(bassWeight, target.bassWeight),
                    trebleWeight: blend(trebleWeight, target.trebleWeight),
                    rhythmicity: blend(rhythmicity, target.rhythmicity),
                    atmospheric: blend(atmospheric, target.atmospheric),
                    aggression: blend(aggression, target.aggression),
                    calmness: blend(calmness, target.calmness),
                    brightness: blend(brightness, target.brightness))
    }

    var motionSpeed: Float { max(0.55, min(1.5, 0.8 + energy * 0.45 + trebleWeight * 0.3 - atmospheric * 0.3 - bassWeight * 0.12)) }
    var density: Float { max(0.7, min(1.3, 0.8 + brightness * 0.35 + rhythmicity * 0.18 - calmness * 0.1)) }
    var glow: Float { max(0.7, min(1.3, 0.78 + atmospheric * 0.23 + energy * 0.2 + brightness * 0.15)) }
    var turbulence: Float { max(0.4, min(1.4, 0.55 + aggression * 0.7 + energy * 0.2 - calmness * 0.25)) }
}
