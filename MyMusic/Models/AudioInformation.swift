import Foundation

struct AudioInformation: Equatable, Sendable {
    var codec = "Unknown"
    var sampleRate: Double?
    var bitDepth: Int?
    var bitRate: Int?
    var channels: Int?
    var outputName = "Unknown"
    var outputSampleRate: Double?

    static let unknown = AudioInformation()
}
