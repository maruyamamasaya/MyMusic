import SwiftUI

struct EqualizerSettingsView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @State private var isNamingPreset = false
    @State private var presetName = ""

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

            Section("プリセット") {
                presetMenu(title: "組み込み", presets: EqualizerPreset.builtIns)

                if !settingsStore.customEqualizerPresets.isEmpty {
                    presetMenu(title: "オリジナル", presets: settingsStore.customEqualizerPresets)
                }

                Button {
                    presetName = ""
                    isNamingPreset = true
                } label: {
                    Label("現在の調整を保存", systemImage: "plus.square.on.square")
                }
            }

            if !settingsStore.customEqualizerPresets.isEmpty {
                Section("保存したオリジナル") {
                    ForEach(settingsStore.customEqualizerPresets) { preset in
                        Button {
                            settingsStore.applyPreset(preset)
                        } label: {
                            HStack {
                                Text(preset.name)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if matchesCurrentSettings(preset) {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                    .onDelete(perform: settingsStore.deleteCustomPresets)
                }
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
        .alert("プリセットを保存", isPresented: $isNamingPreset) {
            TextField("プリセット名", text: $presetName)
            Button("キャンセル", role: .cancel) {}
            Button("保存") {
                settingsStore.saveCustomPreset(named: presetName)
            }
        } message: {
            Text("同じ名前がある場合は上書きします。")
        }
    }

    private func presetMenu(title: String, presets: [EqualizerPreset]) -> some View {
        Menu {
            ForEach(presets) { preset in
                Button {
                    settingsStore.applyPreset(preset)
                } label: {
                    if matchesCurrentSettings(preset) {
                        Label(preset.name, systemImage: "checkmark")
                    } else {
                        Text(preset.name)
                    }
                }
            }
        } label: {
            LabeledContent(title, value: currentPresetName(in: presets) ?? "選択")
        }
    }

    private func currentPresetName(in presets: [EqualizerPreset]) -> String? {
        presets.first(where: matchesCurrentSettings)?.name
    }

    private func matchesCurrentSettings(_ preset: EqualizerPreset) -> Bool {
        let candidate = preset.settings(isEnabled: settingsStore.equalizer.isEnabled)
        return candidate.preamp == settingsStore.equalizer.preamp && candidate.bands == settingsStore.equalizer.bands
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
