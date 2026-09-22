import SwiftUI
import UniformTypeIdentifiers

struct HiResDirectOutputProbeView: View {
    @Environment(PlayerStore.self) private var playerStore
    @State private var store = HiResDirectOutputProbeStore()
    @State private var isImporting = false

    var body: some View {
        List {
            Section {
                Text("既存プレイヤーとは独立したAudio Queue単曲再生です。通常再生を停止し、Tea ProをUSB接続してから192 kHz音源を選んでください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("操作") {
                Button {
                    isImporting = true
                } label: {
                    Label("音源を選んで再生", systemImage: "waveform.badge.plus")
                }
                .disabled(store.hasActiveSession)

                if store.hasActiveSession {
                    Button(role: .destructive) {
                        store.stop()
                    } label: {
                        Label("停止", systemImage: "stop.fill")
                    }
                }
            }

            if store.hasActiveSession {
                Section {
                    Text("別レートの音源へ切り替える場合は、先に停止してください。停止後にAudio Sessionを終了し、次の音源を選んだ時に新しいレートで開始します。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            if let snapshot = store.snapshot {
                Section("診断") {
                    row("ファイル", snapshot.fileName)
                    row("音源レート", rate(snapshot.sourceSampleRate))
                    row("出力先", snapshot.outputName)
                    row("接続種別", snapshot.outputPortType)
                    row("Audio Session", rate(snapshot.sessionSampleRate))
                    row("Audio Queue", rate(snapshot.queueHardwareSampleRate))
                }
            }

            Section("状態") {
                switch store.state {
                case .idle:
                    Label("待機中", systemImage: "pause.circle")
                case .switching:
                    Label("出力レートを切替中", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.orange)
                case .playing:
                    Label("再生中", systemImage: "play.circle.fill")
                        .foregroundStyle(.green)
                case .reachedEnd:
                    Label("読み込み完了", systemImage: "checkmark.circle")
                case let .failed(message):
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                }
            }
        }
        .themeScreen()
        .navigationTitle("Hi-Res直接出力 Beta")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: [.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                if let url = urls.first {
                    // Pause leaves AVAudioEngine active and can pin the USB DAC
                    // to its previous hardware rate. This diagnostic requires a
                    // full stop before it negotiates the selected file's rate.
                    playerStore.stop()
                    store.play(url: url)
                }
            case let .failure(error):
                store.stop()
                store.state = .failed(error.localizedDescription)
            }
        }
        .onDisappear { store.stop() }
    }

    private func row(_ label: String, _ value: String) -> some View {
        LabeledContent(label, value: value)
    }

    private func rate(_ value: Double?) -> String {
        guard let value, value.isFinite, value > 0 else { return "—" }
        return String(format: "%.1f kHz", value / 1_000)
    }
}
