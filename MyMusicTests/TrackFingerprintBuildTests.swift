import Foundation
import XCTest
@testable import MyMusic

@MainActor
final class TrackFingerprintBuildTests: XCTestCase {
    func testBatchBuildStopsAtDailyLimitAndPersistsEachResult() async throws {
        let suite = "TrackFingerprintBuildTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let identity = FingerprintIdentityServiceStub()
        let store = TrackFingerprintBuildStore(
            identityService: identity,
            defaults: defaults,
            maximumPerDay: 2
        )
        let folderURL = URL(fileURLWithPath: "/tmp/music", isDirectory: true)
        let tracks = (0..<3).map { index in
            Track(
                id: UUID(),
                title: "Track \(index)",
                artistName: "Artist",
                duration: 180,
                fileURL: folderURL.appending(path: "track-\(index).m4a"),
                relativePath: "track-\(index).m4a"
            )
        }

        await store.refresh(tracks: tracks)
        store.start(tracks: tracks, folders: [LibraryFolder(url: folderURL)])
        for _ in 0..<100 {
            if !store.isRunning { break }
            try await Task.sleep(for: .milliseconds(10))
        }

        XCTAssertFalse(store.isRunning)
        XCTAssertEqual(store.completedCount, 2)
        XCTAssertEqual(store.processedToday, 2)
        XCTAssertEqual(store.dailyRemaining, 0)
        let buildCount = await identity.buildCount
        XCTAssertEqual(buildCount, 2)

        let reloaded = TrackFingerprintBuildStore(
            identityService: identity,
            defaults: defaults,
            maximumPerDay: 2
        )
        XCTAssertEqual(reloaded.processedToday, 2)
    }
}

private actor FingerprintIdentityServiceStub: TrackIdentityServicing {
    private var stored: [Track.ID: String] = [:]
    private(set) var buildCount = 0

    func prepareForScan(relativePaths: Set<String>) async { }
    func finishScan() async { }
    func resolveID(
        for fileURL: URL,
        relativePath: String,
        fileSize: Int64?,
        modificationDate: Date?,
        duration: TimeInterval
    ) async -> Track.ID {
        UUID()
    }
    func registerExistingTracks(_ tracks: [Track], in folderURL: URL) async { }
    func fingerprints(for trackIDs: [Track.ID]) async -> [Track.ID: String] {
        stored.filter { trackIDs.contains($0.key) }
    }
    func buildFingerprint(
        for track: Track,
        in folderURL: URL,
        allowDownloading: Bool
    ) async -> TrackFingerprintBuildResult {
        buildCount += 1
        let fingerprint = String(repeating: String(format: "%02x", buildCount), count: 32)
        stored[track.id] = fingerprint
        return .built(fingerprint)
    }
}
