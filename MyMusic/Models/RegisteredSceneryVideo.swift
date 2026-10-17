import Foundation

nonisolated struct RegisteredSceneryVideo: Codable, Sendable, Identifiable, Equatable {
    var id: String { fileName }
    let fileName: String
    let originalName: String
    let byteCount: Int64
}

nonisolated struct SceneryVideoCollection: Codable, Sendable {
    var version = 2
    var videos: [RegisteredSceneryVideo] = []
    var selectedFileName: String?
}
