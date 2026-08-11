import Observation

@Observable
final class SettingsStore {
    enum Appearance { case system, light, dark }
    var appearance: Appearance = .system
    var crossfadeEnabled = false
    var volumeNormalizationEnabled = false
    var gaplessPlaybackEnabled = true
}
