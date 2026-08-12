import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    enum Appearance { case system, light, dark }
    var appearance: Appearance = .system
    var crossfadeEnabled = false
    var volumeNormalizationEnabled = false
    var gaplessPlaybackEnabled = true

    private(set) var equalizer: EqualizerSettings
    @ObservationIgnored private weak var equalizerController: EqualizerControlling?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let equalizerKey = "equalizerSettings"

    init(equalizerController: EqualizerControlling? = nil, defaults: UserDefaults = .standard) {
        self.equalizerController = equalizerController
        self.defaults = defaults
        if let data = defaults.data(forKey: equalizerKey),
           var saved = try? JSONDecoder().decode(EqualizerSettings.self, from: data) {
            saved.normalize()
            equalizer = saved
        } else {
            equalizer = .flat
        }
        equalizerController?.applyEqualizer(equalizer)
    }

    func setEqualizerEnabled(_ isEnabled: Bool) {
        equalizer.isEnabled = isEnabled
        applyAndSaveEqualizer()
    }

    func setPreamp(_ gain: Float) {
        equalizer.preamp = min(max(gain, -12), 0)
        applyAndSaveEqualizer()
    }

    func setBandGain(_ gain: Float, at index: Int) {
        guard equalizer.bands.indices.contains(index) else { return }
        equalizer.bands[index].gain = min(max(gain, -12), 12)
        applyAndSaveEqualizer()
    }

    func resetEqualizer() {
        let wasEnabled = equalizer.isEnabled
        equalizer = .flat
        equalizer.isEnabled = wasEnabled
        applyAndSaveEqualizer()
    }

    private func applyAndSaveEqualizer() {
        equalizerController?.applyEqualizer(equalizer)
        if let data = try? JSONEncoder().encode(equalizer) {
            defaults.set(data, forKey: equalizerKey)
        }
    }
}
