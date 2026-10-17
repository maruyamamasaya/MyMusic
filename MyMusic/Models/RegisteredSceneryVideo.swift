import Foundation

nonisolated struct RegisteredSceneryVideo: Codable, Sendable {
    let fileName: String
    let originalName: String
    let byteCount: Int64
}
