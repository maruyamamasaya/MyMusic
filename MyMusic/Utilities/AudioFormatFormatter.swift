import Foundation

enum AudioFormatFormatter {
    static func string(from format: AudioFormat) -> String {
        var parts = [format.codec.rawValue]
        if let bitDepth = format.bitDepth { parts.append("\(bitDepth)-bit") }
        if let sampleRate = format.sampleRate { parts.append("\(sampleRate / 1_000, format: .number.precision(.fractionLength(0...1))) kHz") }
        if format.bitDepth == nil, let bitRate = format.bitRate { parts.append("\(bitRate / 1_000) kbps") }
        return parts.joined(separator: " • ")
    }
}
