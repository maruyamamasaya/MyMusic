import Foundation

enum AudioSampleRatePath: Equatable, Sendable {
    case unknown
    case native
    case converted
}

struct AudioInformation: Equatable, Sendable {
    var codec = "Unknown"
    var sampleRate: Double?
    var bitDepth: Int?
    var bitRate: Int?
    var channels: Int?
    var outputName = "Unknown"
    var outputSampleRate: Double?

    static let unknown = AudioInformation()

    var isLosslessSource: Bool {
        ["ALAC", "FLAC", "PCM"].contains(codec.uppercased())
    }

    /// JEITA's examples classify audio above CD-equivalent resolution as Hi-Res
    /// when neither axis drops below CD quality. The official Hi-Res logo itself
    /// is licensed, so the UI uses an unbranded text badge.
    var isHiResolutionSource: Bool {
        guard isLosslessSource, let sampleRate, let bitDepth else { return false }
        let hasCDOrHigherRate = sampleRate >= 44_100
        let hasCDOrHigherDepth = bitDepth >= 16
        let exceedsCDRate = sampleRate > 48_000
        let exceedsCDDepth = bitDepth > 16
        return hasCDOrHigherRate && hasCDOrHigherDepth && (exceedsCDRate || exceedsCDDepth)
    }

    var sampleRatePath: AudioSampleRatePath {
        guard let sampleRate, let outputSampleRate,
              sampleRate.isFinite, outputSampleRate.isFinite,
              sampleRate > 0, outputSampleRate > 0 else { return .unknown }
        return abs(sampleRate - outputSampleRate) < 1 ? .native : .converted
    }
}
