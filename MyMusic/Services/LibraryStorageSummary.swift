import Foundation

nonisolated struct LibraryStorageSummary: Equatable, Sendable {
    let trackCount: Int
    let totalBytes: Int64
    let unknownSizeCount: Int

    static let empty = LibraryStorageSummary(fileSizes: [])

    init(fileSizes: [Int64?]) {
        trackCount = fileSizes.count
        var bytes: Int64 = 0
        var unknown = 0
        for size in fileSizes {
            guard let size, size >= 0 else {
                unknown += 1
                continue
            }
            let sum = bytes.addingReportingOverflow(size)
            guard !sum.overflow else {
                unknown += 1
                continue
            }
            bytes = sum.partialValue
        }
        totalBytes = bytes
        unknownSizeCount = unknown
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
}
