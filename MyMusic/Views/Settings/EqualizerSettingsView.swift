import SwiftUI

struct EqualizerSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore

    var body: some View {
        @Bindable var settingsStore = settingsStore

        List {
            Section {
                Toggle("イコライザ", isOn: Binding(
                    get: { settingsStore.equalizer.isEnabled },
                    set: settingsStore.setEqualizerEnabled
                ))
            } footer: {
                Text("OFF時はAVAudioUnitEQのDSP処理をバイパスします。")
            }

            Section("プリアンプ") {
                gainSlider(
                    value: Binding(
                        get: { settingsStore.equalizer.preamp },
                        set: settingsStore.setPreamp
                    ),
                    range: -12...0
                )
            }

            Section("10バンド") {
                ForEach(Array(settingsStore.equalizer.bands.enumerated()), id: \.element.id) { index, band in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(frequencyLabel(band.frequency))
                            Spacer()
                            Text(gainLabel(band.gain))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                        gainSlider(
                            value: Binding(
                                get: { settingsStore.equalizer.bands[index].gain },
                                set: { settingsStore.setBandGain($0, at: index) }
                            ),
                            range: -12...12
                        )
                    }
                    .disabled(!settingsStore.equalizer.isEnabled)
                }
            }

            Section {
                Button("フラットに戻す", role: .destructive) {
                    settingsStore.resetEqualizer()
                }
            }
        }
        .navigationTitle("イコライザ")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func gainSlider(value: Binding<Float>, range: ClosedRange<Float>) -> some View {
        Slider(value: value, in: range, step: 0.5) {
            Text("ゲイン")
        } minimumValueLabel: {
            Text("\(Int(range.lowerBound))")
        } maximumValueLabel: {
            Text("+\(Int(range.upperBound))")
        }
    }

    private func frequencyLabel(_ frequency: Double) -> String {
        frequency >= 1_000 ? String(format: "%.0f kHz", frequency / 1_000) : "\(Int(frequency)) Hz"
    }

    private func gainLabel(_ gain: Float) -> String {
        String(format: "%+.1f dB", gain)
    }
}
