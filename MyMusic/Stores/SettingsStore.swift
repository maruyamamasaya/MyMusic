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
    private(set) var customEqualizerPresets: [EqualizerPreset]
    @ObservationIgnored private weak var equalizerController: EqualizerControlling?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let equalizerKey = "equalizerSettings"
    @ObservationIgnored private let customPresetsKey = "customEqualizerPresets"

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
        if let data = defaults.data(forKey: customPresetsKey),
           let saved = try? JSONDecoder().decode([EqualizerPreset].self, from: data) {
            customEqualizerPresets = saved
        } else {
            customEqualizerPresets = []
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

    func applyPreset(_ preset: EqualizerPreset) {
        equalizer = preset.settings()
        applyAndSaveEqualizer()
    }

    @discardableResult
    func saveCustomPreset(named rawName: String) -> Bool {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        let preset = EqualizerPreset(
            name: name,
            preamp: equalizer.preamp,
            gains: equalizer.bands.map(\.gain)
        )
        if let index = customEqualizerPresets.firstIndex(where: { $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame }) {
            customEqualizerPresets[index] = preset
        } else {
            customEqualizerPresets.append(preset)
        }
        customEqualizerPresets.sort { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        saveCustomPresets()
        return true
    }

    func deleteCustomPresets(at offsets: IndexSet) {
        for index in offsets.sorted(by: >) where customEqualizerPresets.indices.contains(index) {
            customEqualizerPresets.remove(at: index)
        }
        saveCustomPresets()
    }

    private func applyAndSaveEqualizer() {
        equalizerController?.applyEqualizer(equalizer)
        if let data = try? JSONEncoder().encode(equalizer) {
            defaults.set(data, forKey: equalizerKey)
        }
    }


    private func saveCustomPresets() {
        if let data = try? JSONEncoder().encode(customEqualizerPresets) {
            defaults.set(data, forKey: customPresetsKey)
        }
    }
}
