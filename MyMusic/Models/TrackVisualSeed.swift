import Foundation

nonisolated enum TrackVisualSeed {
    static func value(for id: UUID) -> Double {
        // Stable across launches and platforms; Swift Hasher is intentionally randomized.
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in id.uuidString.utf8 {
            hash = (hash ^ UInt64(byte)) &* 1_099_511_628_211
        }
        return Double(hash % 1_000_000) / 1_000
    }
}
