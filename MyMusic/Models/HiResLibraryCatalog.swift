import Foundation

nonisolated struct HiResLibraryCatalog: Sendable {
    var tracks: [Track]
    var albums: [Album]
    var artists: [Artist]

    static let empty = HiResLibraryCatalog(tracks: [], albums: [], artists: [])

    func tracks(for trackIDs: [Track.ID]) -> [Track] {
        let tracksByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        return trackIDs.compactMap { tracksByID[$0] }
    }
}
