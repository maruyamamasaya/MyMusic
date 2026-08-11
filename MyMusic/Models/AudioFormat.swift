import Foundation

struct AudioFormat: Codable, Hashable, Sendable {
    enum Codec: String, Codable, CaseIterable, Sendable {
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
}
