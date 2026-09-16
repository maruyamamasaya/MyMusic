import SwiftUI

/// The second artwork panel. Advancing preserves the established tap interaction.
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
            VStack(alignment: .leading, spacing: 14) {
                Button(action: onShowArtwork) {
                    audioDetails
                }
                .buttonStyle(.plain)
                .accessibilityHint("ダブルタップして曲別調整を表示")

                if let track, let feature = featureStore.feature(for: track.id) {
                    Rectangle()
                        .fill(.white.opacity(0.14))
                        .frame(height: 1)
                    TrackFeatureBadgeView(track: track, feature: feature)
                }

                Button("Track Adjustmentsへ", action: onShowArtwork)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .padding(18)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.025, green: 0.035, blue: 0.09))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            RadialGradient(
                                colors: [.blue.opacity(0.26), .clear],
                                center: .topTrailing,
                                startRadius: 12,
                                endRadius: 300
                            )
                        )
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var audioDetails: some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("オーディオ情報", systemImage: "waveform")
                .font(.headline)

            WaveformView(levels: spectrumLevels)
                .frame(height: 128)
                .accessibilityHidden(true)

            if hasDetails {
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 9) {
                    if information.codec != "Unknown" { row("形式・コーデック", information.codec) }
                    if let bitRate = information.bitRate { row("ビットレート", "\(bitRate / 1_000) kbps") }
                    if let sampleRate = information.sampleRate { row("サンプルレート", rate(sampleRate)) }
                    if let bitDepth = information.bitDepth { row("ビット深度", "\(bitDepth) bit") }
                    if let channels = information.channels { row("チャンネル", channelDescription(channels)) }
                }
                .font(.subheadline)
                .padding(.top, 2)
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
        Canvas { context, size in
            let centerY = size.height * 0.58
            let count = max(levels.count, 1)
            let step = size.width / CGFloat(count)
            let barWidth = max(step * 0.48, 2)

            var baseline = Path()
            baseline.move(to: CGPoint(x: 0, y: centerY))
            baseline.addLine(to: CGPoint(x: size.width, y: centerY))
            context.stroke(baseline, with: .color(.cyan.opacity(0.28)), lineWidth: 1)

            for index in levels.indices {
                let raw = levels[index].isFinite ? CGFloat(levels[index]) : 0
                let level = min(max(raw, 0), 1)
                let upperHeight = max(3, level * size.height * 0.48)
                let lowerHeight = max(2, level * size.height * 0.19)
                let x = CGFloat(index) * step + (step - barWidth) / 2
                let hue = 0.52 + Double(index) / Double(count) * 0.22
                let color = Color(hue: hue, saturation: 0.82, brightness: 1)
                let upper = Path(roundedRect: CGRect(
                    x: x, y: centerY - upperHeight, width: barWidth, height: upperHeight
                ), cornerRadius: barWidth / 2)
                let lower = Path(roundedRect: CGRect(
                    x: x, y: centerY + 3, width: barWidth, height: lowerHeight
                ), cornerRadius: barWidth / 2)

                var glow = context
                glow.addFilter(.shadow(color: color.opacity(0.8), radius: 7))
                glow.fill(upper, with: .color(color.opacity(0.65)))
                context.fill(upper, with: .linearGradient(
                    Gradient(colors: [.white.opacity(0.95), color]),
                    startPoint: CGPoint(x: x, y: centerY - upperHeight),
                    endPoint: CGPoint(x: x, y: centerY)
                ))
                context.fill(lower, with: .color(color.opacity(0.32)))
            }
        }
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.black.opacity(0.3))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.white.opacity(0.08), lineWidth: 1)
                }
        }
    }
}
