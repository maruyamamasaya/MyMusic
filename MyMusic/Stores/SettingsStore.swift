import Foundation
import Observation

@MainActor
@Observable
final class SettingsStore {
    enum Appearance { case system, light, dark }
    var appearance: Appearance = .system
    var volumeNormalizationEnabled = false
    var gaplessPlaybackEnabled = true

    private(set) var equalizer: EqualizerSettings
    private(set) var customEqualizerPresets: [EqualizerPreset]
    private(set) var playbackTransition: PlaybackTransitionSettings
    @ObservationIgnored private weak var equalizerController: EqualizerControlling?
    @ObservationIgnored private weak var playbackTransitionController: PlaybackTransitionControlling?
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let equalizerKey = "equalizerSettings"
    @ObservationIgnored private let customPresetsKey = "customEqualizerPresets"
    @ObservationIgnored private let playbackTransitionKey = "playbackTransitionSettings"

    init(
        equalizerController: EqualizerControlling? = nil,
        playbackTransitionController: PlaybackTransitionControlling? = nil,
        defaults: UserDefaults = .standard
    ) {
        self.equalizerController = equalizerController
        self.playbackTransitionController = playbackTransitionController
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
        if let data = defaults.data(forKey: playbackTransitionKey),
           var saved = try? JSONDecoder().decode(PlaybackTransitionSettings.self, from: data) {
            saved.normalize()
            playbackTransition = saved
        } else {
            playbackTransition = .preservingExistingPlayback
        }
        equalizerController?.applyEqualizer(equalizer)
        playbackTransitionController?.applyPlaybackTransition(playbackTransition)
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

    func setFadeInEnabled(_ isEnabled: Bool) {
        playbackTransition.fadeInEnabled = isEnabled
        if isEnabled { playbackTransition.type = .fade }
        applyAndSavePlaybackTransition()
    }

    func setFadeInDuration(_ duration: TimeInterval) {
        playbackTransition.fadeInDuration = duration
        applyAndSavePlaybackTransition()
    }

    func setFadeOutEnabled(_ isEnabled: Bool) {
        playbackTransition.fadeOutEnabled = isEnabled
        if isEnabled { playbackTransition.type = .fade }
        applyAndSavePlaybackTransition()
    }

    func setFadeOutDuration(_ duration: TimeInterval) {
        playbackTransition.fadeOutDuration = duration
        applyAndSavePlaybackTransition()
    }

    func setPlaybackTransitionType(_ type: PlaybackTransitionType) {
        playbackTransition.type = type
        applyAndSavePlaybackTransition()
    }

    func setManualTrackTransitionPolicy(_ policy: ManualTrackTransitionPolicy) {
        playbackTransition.manualTrackTransitionPolicy = policy
        applyAndSavePlaybackTransition()
    }

    private func applyAndSaveEqualizer() {
        equalizerController?.applyEqualizer(equalizer)
        if let data = try? JSONEncoder().encode(equalizer) {
            defaults.set(data, forKey: equalizerKey)
        }
    }

    private func applyAndSavePlaybackTransition() {
        playbackTransition.normalize()
        playbackTransitionController?.applyPlaybackTransition(playbackTransition)
        if let data = try? JSONEncoder().encode(playbackTransition) {
            defaults.set(data, forKey: playbackTransitionKey)
        }
    }


    private func saveCustomPresets() {
        if let data = try? JSONEncoder().encode(customEqualizerPresets) {
            defaults.set(data, forKey: customPresetsKey)
        }
    }
}
