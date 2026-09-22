import Foundation

nonisolated struct AudioFormat: Codable, Hashable, Sendable {
    nonisolated enum Codec: String, Codable, CaseIterable, Sendable {
        case flac = "FLAC"
        case alac = "ALAC"
        case aac = "AAC"
        case mp3 = "MP3"
        case wav = "WAV"
        case aiff = "AIFF"
    }

    let codec: Codec
    let bitRate: Int?
    let sampleRate: Double?
    let bitDepth: Int?
    let channels: Int?

    var isLossless: Bool {
        switch codec {
        case .flac, .alac, .wav, .aiff: true
        case .aac, .mp3: false
        }
    }

    var isHiResolution: Bool {
        guard isLossless, let sampleRate, let bitDepth else { return false }
        return sampleRate >= 44_100
            && bitDepth >= 16
            && (sampleRate > 48_000 || bitDepth > 16)
    }
}
