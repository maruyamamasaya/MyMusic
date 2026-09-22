import Foundation

nonisolated enum FileSizeFormatter {
    static func string(from bytes: Int64) -> String {
        let value = ByteCountFormatter()
        value.countStyle = .file
        return value.string(fromByteCount: bytes)
    }
}
