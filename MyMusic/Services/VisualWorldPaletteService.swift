import CoreGraphics
import Foundation
import ImageIO

nonisolated struct VisualWorldRGB: Sendable {
    let red: Double
    let green: Double
    let blue: Double
}

nonisolated struct VisualWorldArtworkColors: Sendable {
    let primary: VisualWorldRGB
    let secondary: VisualWorldRGB
    let accent: VisualWorldRGB
    let dominantShare: Double
}

/// Small, bounded, display-only extraction. Decoding and pixel work stay off MainActor.
actor VisualWorldPaletteService {
    static let shared = VisualWorldPaletteService()
    private var cache: [String: VisualWorldArtworkColors] = [:]

    func colors(for identifier: String) async -> VisualWorldArtworkColors? {
        if let cached = cache[identifier] { return cached }
        guard let data = await ArtworkService.shared.artworkData(for: identifier),
              let colors = Self.extract(data: data) else { return nil }
        if cache.count >= 32 { cache.removeAll(keepingCapacity: true) }
        cache[identifier] = colors
        return colors
    }

    private nonisolated static func extract(data: Data) -> VisualWorldArtworkColors? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: 32
              ] as CFDictionary) else { return nil }
        let size = 24
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        let didDraw = pixels.withUnsafeMutableBytes { bytes -> Bool in
            guard let context = CGContext(data: bytes.baseAddress, width: size, height: size,
                bitsPerComponent: 8, bytesPerRow: size * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))
            return true
        }
        guard didDraw else { return nil }
        var neutralSum = 0.0
        var neutralCount = 0
        var counts = [Int](repeating: 0, count: 12)
        var weights = [Double](repeating: 0, count: 12)
        var sums = Array(repeating: [Double](repeating: 0, count: 3), count: 12)
        for offset in stride(from: 0, to: pixels.count, by: 4) {
            guard pixels[offset + 3] > 200 else { continue }
            let r = Double(pixels[offset]) / 255
            let g = Double(pixels[offset + 1]) / 255
            let b = Double(pixels[offset + 2]) / 255
            let high = max(r, g, b), low = min(r, g, b), delta = high - low
            neutralSum += (r + g + b) / 3
            neutralCount += 1
            guard high > 0.1, delta > 0.07 else { continue }
            var hue: Double
            if high == r { hue = (g - b) / delta }
            else if high == g { hue = 2 + (b - r) / delta }
            else { hue = 4 + (r - g) / delta }
            hue = (hue / 6 + 1).truncatingRemainder(dividingBy: 1)
            let bucket = min(Int(hue * 12), 11)
            let weight = (delta / high) * sqrt(high)
            counts[bucket] += 1
            weights[bucket] += weight
            sums[bucket][0] += r * weight
            sums[bucket][1] += g * weight
            sums[bucket][2] += b * weight
        }
        guard let first = weights.indices.max(by: { weights[$0] < weights[$1] }), weights[first] > 0 else {
            guard neutralCount > 0 else { return nil }
            let value = max(0.3, min(0.85, neutralSum / Double(neutralCount)))
            let primary = VisualWorldRGB(red: value, green: value, blue: value)
            let secondary = VisualWorldRGB(red: value * 0.65, green: value * 0.65, blue: value * 0.65)
            return VisualWorldArtworkColors(primary: primary, secondary: secondary,
                                            accent: VisualWorldRGB(red: 0.95, green: 0.95, blue: 0.95), dominantShare: 0.8)
        }
        let candidates = weights.indices.filter {
            let distance = abs($0 - first)
            return min(distance, 12 - distance) >= 2 && weights[$0] > weights[first] * 0.08
        }
        let second = candidates.max(by: { weights[$0] < weights[$1] }) ?? first
        func color(_ index: Int) -> VisualWorldRGB {
            let values = sums[index].map { $0 / weights[index] }
            let gain = min(1.8, 0.95 / max(values.max() ?? 1, 0.1))
            return VisualWorldRGB(red: min(values[0] * gain, 1), green: min(values[1] * gain, 1), blue: min(values[2] * gain, 1))
        }
        let third = candidates.filter { $0 != second }.min(by: { weights[$0] < weights[$1] }) ?? second
        return VisualWorldArtworkColors(primary: color(first), secondary: color(second), accent: color(third),
                                        dominantShare: Double(counts[first]) / Double(max(counts.reduce(0, +), 1)))
    }
}
