import Foundation

protocol MetadataServicing: AnyObject {
    func metadata(for fileURL: URL) async throws -> Track
}

final class MetadataService: MetadataServicing {
    func metadata(for fileURL: URL) async throws -> Track {
        throw MetadataServiceError.notImplemented
    }
}

enum MetadataServiceError: Error { case notImplemented }
