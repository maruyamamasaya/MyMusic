import Foundation

enum AudioFormatFormatter {
    static func string(from audioFormat: AudioFormat) -> String {
        var parts = [audioFormat.codec.rawValue]
        if let bitDepth = audioFormat.bitDepth { parts.append("\(bitDepth)-bit") }
        if let sampleRate = audioFormat.sampleRate {
            parts.append("\(String(format: "%.1f", sampleRate / 1_000)) kHz")
        }
        if audioFormat.bitDepth == nil, let bitRate = audioFormat.bitRate { parts.append("\(bitRate / 1_000) kbps") }
        return parts.joined(separator: " • ")
    }
}
