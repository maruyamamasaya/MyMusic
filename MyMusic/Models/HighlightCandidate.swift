import Foundation

nonisolated struct HighlightCandidate: Codable, Hashable, Identifiable, Sendable {
    let startTime: TimeInterval
    let duration: TimeInterval
    let score: Double

    var endTime: TimeInterval { startTime + duration }
    var id: String { "\(startTime)-\(duration)" }

    nonisolated static func fallbackCandidates(
        trackDuration: TimeInterval,
        highlightDuration: TimeInterval = 30
    ) -> [HighlightCandidate] {
        let safeTrackDuration = trackDuration.isFinite ? max(trackDuration, 0) : 0
        let duration = min(highlightDuration, safeTrackDuration)
        guard duration > 0 else {
            return [HighlightCandidate(startTime: 0, duration: 0, score: 0)]
        }

        let maximumStart = max(safeTrackDuration - duration, 0)
        let preferredPositions = [0.42, 0.64, 0.22, 0.78, 0.52]
        var seenStarts: Set<Int> = []
        return preferredPositions.compactMap { position in
            let centeredStart = (safeTrackDuration * position) - (duration / 2)
            let start = min(max(centeredStart, 0), maximumStart)
            guard seenStarts.insert(Int(start.rounded())).inserted else { return nil }
            return HighlightCandidate(startTime: start, duration: duration, score: 0)
        }
    }
}

nonisolated struct TrackHighlightData: Codable, Hashable, Sendable {
    static let currentAnalysisVersion = 1

    let trackID: Track.ID
    let fileSize: Int64?
    let modificationDate: Date?
    let analysisVersion: Int
    let candidates: [HighlightCandidate]

    nonisolated init(
        trackID: Track.ID,
        fileSize: Int64?,
        modificationDate: Date?,
        analysisVersion: Int = currentAnalysisVersion,
        candidates: [HighlightCandidate]
    ) {
        self.trackID = trackID
        self.fileSize = fileSize
        self.modificationDate = modificationDate
        self.analysisVersion = analysisVersion
        self.candidates = candidates
    }

    nonisolated func matches(_ track: Track) -> Bool {
        trackID == track.id &&
        fileSize == track.fileSize &&
        modificationDate == track.modificationDate &&
        analysisVersion == Self.currentAnalysisVersion &&
        !candidates.isEmpty
    }
}
