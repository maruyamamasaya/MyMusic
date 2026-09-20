import Foundation
import XCTest
@testable import MyMusic

final class RecentMusicTrendsServiceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_780_000_000)

    private func feature(_ id: Track.ID, energy: Double?) -> TrackFeature {
        TrackFeature(
            trackID: id,
            sourceIdentity: TrackFeatureSourceIdentity(relativePath: "test", fileSize: 1,
                duration: 180, modificationDate: nil, contentHash: nil,
                title: nil, artist: nil, album: nil),
            analysisVersion: 1, analyzedAt: now, importedAt: now,
            values: TrackFeatureValues(tempo: nil, energy: energy, piano: nil, ambient: nil,
                electronic: nil, drumAndBass: nil, aggressive: nil, calm: nil,
                bright: nil, dark: nil, vocal: nil, instrumental: nil, additional: nil)
        )
    }

    private func history(_ id: Track.ID, dates: [Date]) -> PlaybackHistory {
        let events = dates.map { date in
            PlaybackEvent(trackID: id, startedAt: date.addingTimeInterval(-120), endedAt: date,
                listenedSeconds: 120, completionRatio: 0.8, wasSkipped: false,
                wasFullPlayback: false, startKind: .manual, startSource: .library)
        }
        return PlaybackHistory(trackID: id, isFavorite: false, playCount: dates.count,
            lastPlayedAt: dates.max(), playbackEvents: events)
    }

    func testPeriodsHaveExpectedBucketCountAndContext() {
        XCTAssertEqual(TrendPeriod.allCases.map(\.bucketCount), [6, 8, 12, 7, 10, 13, 13, 12])
        XCTAssertEqual(TrendPeriod.allCases.map(\.context), [
            "今日の聴き方・ムード", "今日の聴き方・ムード", "最近の傾向", "最近の傾向",
            "好みの変化", "好みの変化", "好みの変化", "好みの変化"
        ])
        XCTAssertEqual(TrendPeriod.allCases.map(\.showsComparison),
                       [false, false, false, false, true, true, true, true])
    }

    func testPeriodBoundaryIsInclusiveAndEarlierEventExcluded() {
        let id = UUID()
        let start = TrendPeriod.sixHours.start(before: now)
        let dates = [start.addingTimeInterval(-1), start, now, now.addingTimeInterval(1)]
        let events = RecentMusicTrendsService.makeIndex(
            historyEntries: [id: history(id, dates: dates)],
            features: [id: feature(id, energy: 0.5)], now: now)
        XCTAssertEqual(events.count, 3) // The index retains the event before six hours for longer periods.
        let sixHours = RecentMusicTrendsService.summarize(events, period: .sixHours, now: now)
        XCTAssertEqual(sixHours.eligiblePlayCount, 2)
    }

    func testZeroEventsAndMissingFeaturesRemainEmpty() {
        let id = UUID()
        let missing = UUID()
        let empty = RecentMusicTrendsService.summarize([], period: .month, now: now)
        XCTAssertEqual(empty.eligiblePlayCount, 0)
        XCTAssertTrue(empty.points.isEmpty)
        let index = RecentMusicTrendsService.makeIndex(
            historyEntries: [id: history(id, dates: [now]),
                             missing: history(missing, dates: [now])],
            features: [id: feature(id, energy: 0.6)], now: now)
        XCTAssertEqual(index.count, 1)
        XCTAssertEqual(RecentMusicTrendsService.summarize(index, period: .month, now: now).eligiblePlayCount, 1)
    }

    func testSwitchingPeriodChangesIncludedEvents() {
        let ids = (0..<3).map { _ in UUID() }
        let events = (0..<6).map { offset in
            TrendEvent(trackID: ids[offset % 3],
                date: now.addingTimeInterval(-Double(offset + 1) * 3600),
                scores: [.energy: 0.5])
        }
        let short = RecentMusicTrendsService.summarize(events, period: .sixHours, now: now)
        let day = RecentMusicTrendsService.summarize(events, period: .day, now: now)
        XCTAssertEqual(short.eligiblePlayCount, 6)
        XCTAssertEqual(day.eligiblePlayCount, 6)
        let old = TrendEvent(trackID: ids[0], date: now.addingTimeInterval(-20 * 3600), scores: [.energy: 0.5])
        XCTAssertEqual(RecentMusicTrendsService.summarize(events + [old],
            period: .sixHours, now: now).eligiblePlayCount, 6)
        XCTAssertEqual(RecentMusicTrendsService.summarize(events + [old],
            period: .day, now: now).eligiblePlayCount, 7)
    }

    func testBucketAverageAndInsufficientData() {
        let a = UUID(), b = UUID(), c = UUID()
        let base = now.addingTimeInterval(-5 * 3600)
        let events = [
            TrendEvent(trackID: a, date: base, scores: [.energy: 0.2]),
            TrendEvent(trackID: b, date: base.addingTimeInterval(60), scores: [.energy: 0.6]),
            TrendEvent(trackID: c, date: base.addingTimeInterval(120), scores: [.energy: 0.4]),
            TrendEvent(trackID: a, date: now.addingTimeInterval(-3600), scores: [.energy: 0.8]),
            TrendEvent(trackID: b, date: now.addingTimeInterval(-1800), scores: [.energy: 1.0])
        ]
        let result = RecentMusicTrendsService.summarize(events, period: .sixHours, now: now)
        XCTAssertEqual(result.points[.energy]?.count, 2)
        XCTAssertEqual(result.points[.energy]?[0].value ?? -1, 0.4, accuracy: 0.0001)
        XCTAssertEqual(result.points[.energy]?[1].value ?? -1, 0.9, accuracy: 0.0001)
        XCTAssertFalse(RecentMusicTrendsService.summarize(Array(events.prefix(4)),
            period: .sixHours, now: now).hasChart(for: .energy))
    }

    func testComparisonRequiresEnoughPlaysTracksAndDifference() {
        let tracks = (0..<3).map { _ in UUID() }
        let start = TrendPeriod.month.start(before: now)
        let midpoint = start.addingTimeInterval(now.timeIntervalSince(start) / 2)
        let earlier = (0..<6).map { offset in
            TrendEvent(trackID: tracks[offset % 3],
                date: start.addingTimeInterval(Double(offset + 1) * 3600),
                scores: [.energy: 0.3])
        }
        let later = (0..<6).map { offset in
            TrendEvent(trackID: tracks[offset % 3],
                date: midpoint.addingTimeInterval(Double(offset + 1) * 3600),
                scores: [.energy: 0.6])
        }
        let result = RecentMusicTrendsService.summarize(earlier + later, period: .month, now: now)
        XCTAssertEqual(result.changes.count, 1)
        XCTAssertEqual(result.comparisons.count, 1)
        XCTAssertEqual(result.changes[0].difference, 0.3, accuracy: 0.0001)
        XCTAssertTrue(RecentMusicTrendsService.summarize(earlier + Array(later.prefix(4)),
            period: .month, now: now).changes.isEmpty)
        let subtle = later.map { TrendEvent(trackID: $0.trackID, date: $0.date, scores: [.energy: 0.35]) }
        let subtleResult = RecentMusicTrendsService.summarize(earlier + subtle, period: .month, now: now)
        XCTAssertTrue(subtleResult.changes.isEmpty)
        XCTAssertEqual(subtleResult.comparisons[.energy]?.difference ?? -1, 0.05, accuracy: 0.0001)
    }
}
