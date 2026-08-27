import SwiftUI

/// The back of the artwork. Keep the return action separate from the feature detail button.
struct AudioInformationView: View {
    @Environment(TrackFeatureStore.self) private var featureStore
    let track: Track?
    let information: AudioInformation
    let spectrumLevels: [Float]
    let onShowArtwork: () -> Void

    private var hasDetails: Bool {
        information.codec != "Unknown" || information.bitRate != nil || information.sampleRate != nil ||
        information.bitDepth != nil || information.channels != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Button(action: onShowArtwork) {
                    audioDetails
                }
                .buttonStyle(.plain)
                .accessibilityHint("ダブルタップしてアートワークを表示")

                if let track, let feature = featureStore.feature(for: track.id) {
                    Divider()
                    TrackFeatureBadgeView(track: track, feature: feature)
                }

                Button("アートワークに戻る", action: onShowArtwork)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var audioDetails: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("オーディオ情報", systemImage: "waveform")
                .font(.headline)

            WaveformView(levels: spectrumLevels)
                .frame(height: 72)
                .accessibilityHidden(true)

            if hasDetails {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
                    if information.codec != "Unknown" { row("形式・コーデック", information.codec) }
                    if let bitRate = information.bitRate { row("ビットレート", "\(bitRate / 1_000) kbps") }
                    if let sampleRate = information.sampleRate { row("サンプルレート", rate(sampleRate)) }
                    if let bitDepth = information.bitDepth { row("ビット深度", "\(bitDepth) bit") }
                    if let channels = information.channels { row("チャンネル", channelDescription(channels)) }
                }
                .font(.subheadline)
            } else {
                Label("オーディオ情報がありません", systemImage: "waveform.slash")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func row(_ label: String, _ value: String) -> some View {
        GridRow {
            Text(label).foregroundStyle(.secondary)
            Text(value)
        }
    }

    private func rate(_ value: Double) -> String {
        String(format: "%.1f kHz", value / 1_000)
    }

    private func channelDescription(_ channels: Int) -> String {
        switch channels {
        case 1: "モノラル"
        case 2: "ステレオ"
        default: "\(channels) ch"
        }
    }
}

private struct WaveformView: View {
    let levels: [Float]

    var body: some View {
        GeometryReader { proxy in
            let count = max(levels.count, 1)
            let spacing: CGFloat = 3
            let width = max((proxy.size.width - spacing * CGFloat(count - 1)) / CGFloat(count), 1)

            HStack(alignment: .center, spacing: spacing) {
                ForEach(levels.indices, id: \.self) { index in
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [.cyan, .blue, .purple],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(
                            width: width,
                            height: max(3, proxy.size.height * CGFloat(levels[index]))
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .animation(.linear(duration: 0.08), value: levels)
        }
    }
}
