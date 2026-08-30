import Foundation

enum PlaylistTagRules {
    static let maximumTagCount = 20
    static let maximumTagLength = 40

    static func normalizedTag(_ value: String) -> String? {
        let normalized = value
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        guard !normalized.isEmpty, normalized.count <= maximumTagLength else { return nil }
        return normalized
    }

    static func normalizedTags(_ values: [String]) -> [String] {
        var keys: Set<String> = []
        var result: [String] = []
        for value in values {
            guard result.count < maximumTagCount,
                  let tag = normalizedTag(value),
                  keys.insert(comparisonKey(for: tag)).inserted else { continue }
            result.append(tag)
        }
        return result
    }

    static func contains(_ tags: [String], tag: String) -> Bool {
        guard let normalized = normalizedTag(tag) else { return false }
        let key = comparisonKey(for: normalized)
        return tags.contains { comparisonKey(for: $0) == key }
    }

    static func uniqueSortedTags(_ values: [String]) -> [String] {
        var tagsByKey: [String: String] = [:]
        for value in values {
            guard let tag = normalizedTag(value) else { continue }
            let key = comparisonKey(for: tag)
            if tagsByKey[key] == nil { tagsByKey[key] = tag }
        }
        return tagsByKey.values.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }

    static func comparisonKey(for value: String) -> String {
        value.precomposedStringWithCanonicalMapping.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}
