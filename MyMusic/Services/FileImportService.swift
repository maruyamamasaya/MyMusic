import Foundation

protocol FileImportServicing: AnyObject {
    func importFiles(at urls: [URL]) async throws -> [URL]
}

final class FileImportService: FileImportServicing {
    func importFiles(at urls: [URL]) async throws -> [URL] { [] }
}
