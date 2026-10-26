import Foundation

nonisolated enum LibraryYearService {
    static func groups(tracks: [Track]) -> [LibraryYear] {
        var groups: [Int: [Track.ID]] = [:]
        var unknown: [Track.ID] = []
        for track in tracks {
            if let year = track.year, (1...9999).contains(year) {
                groups[year, default: []].append(track.id)
            } else {
                unknown.append(track.id)
            }
        }
        var result = groups.keys.sorted(by: >).map {
            LibraryYear(year: $0, trackIDs: groups[$0] ?? [])
        }
        if !unknown.isEmpty {
            result.append(LibraryYear(year: nil, trackIDs: unknown))
        }
        return result
    }
}
