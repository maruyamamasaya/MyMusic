import Foundation

struct OverplayScore: Hashable, Sendable {
    let recentPlayCount: Int
    let baselinePlayCount: Int
    let weeklyBaseline: Double
    let relativeScore: Double
    let volumeScore: Double
    let score: Double
}

enum OverplayScoring {
    static let recentDays = 7
    static let baselineDays = 56
    static let baselineWeeks = 8.0
    static let minimumCandidateRecentPlayCount = 5
    static let minimumCandidateScore = 0.5

    static func score(recentPlayCount: Int, baselinePlayCount: Int) -> OverplayScore {
        let recent = max(0, recentPlayCount)
        let baseline = max(0, baselinePlayCount)
        let weeklyBaseline = Double(baseline) / baselineWeeks
        let burstRatio = (Double(recent) + 1) / (weeklyBaseline + 1)
        let relativeScore = clamp(log2(burstRatio) / 2)
        let volumeScore = clamp((Double(recent) - 4) / 8)
        let score = clamp(0.6 * relativeScore + 0.4 * volumeScore)
        return OverplayScore(
            recentPlayCount: recent,
            baselinePlayCount: baseline,
            weeklyBaseline: weeklyBaseline,
            relativeScore: relativeScore,
            volumeScore: volumeScore,
            score: score
        )
    }

    static func isCandidate(_ score: OverplayScore) -> Bool {
        score.recentPlayCount >= minimumCandidateRecentPlayCount
            && score.score >= minimumCandidateScore
    }

    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
}

struct PreferenceDriftScore: Hashable, Sendable {
    let recentFullPlaybackCount: Int
    let recentSkipCount: Int
    let historicalFullPlaybackCount: Int
    let historicalSkipCount: Int
    let recentCompletionRate: Double
    let historicalCompletionRate: Double?
    let rawScore: Double
    let stableScore: Double

    var recentSampleCount: Int { recentFullPlaybackCount + recentSkipCount }
    var historicalSampleCount: Int { historicalFullPlaybackCount + historicalSkipCount }
}

enum PreferenceDriftScoring {
    static let recentDays = 30
    static let minimumRecentSampleCount = 5
    static let minimumHistoricalSampleCount = 8
    static let candidateThreshold = 0.5
    static let overplayAdjustment = 0.70

    static func score(
        playbackPreference: Int,
        recentFullPlaybackCount: Int,
        recentSkipCount: Int,
        historicalFullPlaybackCount: Int,
        historicalSkipCount: Int,
        overplayScore: Double
    ) -> PreferenceDriftScore {
        let recentFull = max(0, recentFullPlaybackCount)
        let recentSkip = max(0, recentSkipCount)
        let historicalFull = max(0, historicalFullPlaybackCount)
        let historicalSkip = max(0, historicalSkipCount)
        let recentCount = recentFull + recentSkip
        let historicalCount = historicalFull + historicalSkip
        let recentRate = (Double(recentFull) + 2) / (Double(recentCount) + 4)
        let historicalRate = historicalCount > 0 ? Double(historicalFull) / Double(historicalCount) : nil

        let rawScore: Double
        if historicalCount >= minimumHistoricalSampleCount, let historicalRate {
            let completionDrop = historicalRate - recentRate
            let dropScore = clamp((completionDrop - 0.15) / 0.35)
            let goodStrength = clamp(Double(playbackPreference) / 3)
            let evidence = clamp(Double(recentCount) / 8)
            rawScore = clamp(goodStrength * dropScore * evidence)
        } else {
            rawScore = 0
        }
        let stableScore = clamp(rawScore * (1 - overplayAdjustment * clamp(overplayScore)))
        return PreferenceDriftScore(
            recentFullPlaybackCount: recentFull,
            recentSkipCount: recentSkip,
            historicalFullPlaybackCount: historicalFull,
            historicalSkipCount: historicalSkip,
            recentCompletionRate: recentRate,
            historicalCompletionRate: historicalRate,
            rawScore: rawScore,
            stableScore: stableScore
        )
    }

    static func isCandidate(playbackPreference: Int, score: PreferenceDriftScore) -> Bool {
        playbackPreference > 0
            && score.recentSampleCount >= minimumRecentSampleCount
            && score.historicalSampleCount >= minimumHistoricalSampleCount
            && score.stableScore >= candidateThreshold
    }

    private static func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
}
