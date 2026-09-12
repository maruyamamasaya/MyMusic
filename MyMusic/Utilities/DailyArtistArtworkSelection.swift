import Foundation

nonisolated enum DailyArtistArtworkSelection {
    static func identifier(
        for artistID: Artist.ID,
        from artworkIdentifiers: [String],
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> String? {
        let identifiers = Array(Set(artworkIdentifiers)).sorted()
        guard !identifiers.isEmpty else { return nil }

        var artistSeed: UInt64 = 1_469_598_103_934_665_603
        for byte in artistID.uuidString.utf8 {
            artistSeed ^= UInt64(byte)
            artistSeed &*= 1_099_511_628_211
        }

        let day = max(calendar.ordinality(of: .day, in: .era, for: date) ?? 0, 0)
        let index = Int((artistSeed &+ UInt64(day)) % UInt64(identifiers.count))
        return identifiers[index]
    }
}
