import Foundation

enum FileSizeFormatter {
    private static let formatter: ByteCountFormatter = {
        let value = ByteCountFormatter()
        value.countStyle = .file
        return value
    }()
    static func string(from bytes: Int64) -> String { formatter.string(fromByteCount: bytes) }
}
