import AVFoundation
import SwiftUI

/// Read-only connection type and device name.
struct PlaybackOutputLabel: View {
    let outputName: String
    let portType: String?
    let fallbackTitle: String

    private var connection: (name: String, icon: String) {
        switch portType.map(AVAudioSession.Port.init(rawValue:)) {
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            ("Bluetooth", "antenna.radiowaves.left.and.right")
        case .airPlay:
            ("AirPlay", "airplay.audio")
        case .headphones:
            ("有線ヘッドホン", "headphones")
        case .usbAudio:
            ("USBオーディオ", "cable.connector")
        case .builtInSpeaker:
            ("内蔵スピーカー", "speaker.wave.2.fill")
        case .builtInReceiver:
            ("受話口", "iphone")
        case .carAudio:
            ("車載オーディオ", "car.fill")
        case .lineOut:
            ("ライン出力", "cable.connector")
        case .HDMI, .displayPort:
            ("外部ディスプレイ", "display")
        default:
            ("音声出力先", "speaker.wave.2.fill")
        }
    }

    var body: some View {
        if !outputName.isEmpty && outputName != "Unknown" {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 3) {
                    Image(systemName: connection.icon)
                    Text(connection.name)
                }
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                Text(outputName)
                    .font(.system(size: 10))
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                    .multilineTextAlignment(.leading)
            }
            .frame(width: 200, alignment: .leading)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("音声出力先、\(connection.name)、\(outputName)")
        } else {
            Text(fallbackTitle)
                .font(.headline)
        }
    }
}
