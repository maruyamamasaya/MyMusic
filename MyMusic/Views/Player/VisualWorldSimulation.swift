import Foundation

/// Presentation-only inertial state. No playback operations or persistent data.
nonisolated struct VisualWorldSimulation {
    var clock = 0.0
    var excitation = 0.0
    var memory = 0.0
    var tonalHeight = 0.5
    var confidence = 0.0
    var bass = 0.0
    var mid = 0.0
    var treble = 0.0
    var bands = [Float](repeating: 0, count: 24)
    var waveform = [Float](repeating: 0, count: 48)
    var beat = 0.0
    private var accumulated = 0.0
    private var cooldown = 0.0
    private var beatCooldown = 0.0
    private var fluxBaseline = 0.0
    private var lastDate: Date?
    private var silentDuration = 0.0
    var resting: Bool { silentDuration >= 10 }

    mutating func suspend() { lastDate = nil }

    mutating func advance(date: Date, audio: VisualWorldAudioFrame, playing: Bool,
                          energy: Double, aggressive: Double, ambient: Double,
                          piano: Double = 0.5, tempo: Double = 100) {
        guard let lastDate else { self.lastDate = date; return }
        let dt = min(max(date.timeIntervalSince(lastDate), 0), 0.067)
        self.lastDate = date
        let unit = VisualWorldDynamics.unit
        let e = unit(energy), a = unit(aggressive)
        let active = playing && ProcessInfo.processInfo.systemUptime - audio.capturedAt < 0.3
        let low = active ? unit(Double(audio.bass)) : 0
        let medium = active ? unit(Double(audio.mid)) : 0
        let high = active ? unit(Double(audio.treble)) : 0
        let flux = active ? unit(Double(audio.flux)) : 0
        func smooth(_ old: Double, _ target: Double, _ decay: Double) -> Double {
            old + (target - old) * (1 - exp(-dt / (target > old ? 0.08 : decay)))
        }
        bass = smooth(bass, low, 0.6)
        mid = smooth(mid, medium, 0.9)
        treble = smooth(treble, high, 0.35)
        for i in 0..<24 {
            let target = active && i < audio.bands.count ? unit(Double(audio.bands[i])) : 0
            bands[i] = Float(smooth(Double(bands[i]), target, 0.5))
        }
        for i in 0..<waveform.count {
            let sample = active && i < audio.waveform.count && audio.waveform[i].isFinite
                ? min(1, max(-1, Double(audio.waveform[i]))) : 0
            waveform[i] = Float(Double(waveform[i]) + (sample-Double(waveform[i]))*(1-exp(-dt/0.09)))
        }
        beatCooldown = max(0, beatCooldown-dt)
        let threshold = max(0.055,fluxBaseline*1.7)
        beat *= exp(-dt/0.24)
        if active && beatCooldown == 0 && flux > threshold && (low > 0.1 || flux > 0.2) {
            beat = min(1,0.35+flux*2.2+low*0.3)
            beatCooldown = 0.2
        }
        fluxBaseline += (flux-fluxBaseline)*(1-exp(-dt/1.2))
        confidence = smooth(confidence, active ? unit(Double(audio.tonalConfidence)) : 0, 0.7)
        tonalHeight = smooth(tonalHeight, active ? unit(Double(audio.tonalHeight)) : 0.5, 1.2)
        silentDuration = playing ? 0 : silentDuration + dt
        // Energy remains after sound stops, then the entire clock goes to rest.
        let activity = max(bass, mid, treble)
        clock += dt * (0.07 + activity * (0.2 + e * 0.55 + unit(tempo / 200) * 0.2)) * (resting ? 0 : 1)
        cooldown = max(0, cooldown - dt)
        accumulated = min(1, max(0, accumulated + dt * (activity * 0.42 - 0.12)))
        if active && cooldown == 0 && flux > 0.08 && accumulated > 0.16 {
            excitation = min(1, accumulated + flux * 2)
            accumulated *= 0.3
            cooldown = 4 + (1 - a) * 3
        }
        excitation *= exp(-dt / (0.75 + unit(ambient)))
        memory = smooth(memory, activity, 1.2 + unit(ambient) * 2.5 + unit(piano) * 0.6)
    }
}
