import Foundation
import XCTest
@testable import MyMusic

@MainActor
final class TrackFingerprintBuildTests: XCTestCase {
    func testBatchBuildProcessesEveryCandidateAndPersistsEachResult() async throws {
        let identity = FingerprintIdentityServiceStub()
        let store = TrackFingerprintBuildStore(identityService: identity)
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
        XCTAssertEqual(store.completedCount, 3)
        let buildCount = await identity.buildCount
        XCTAssertEqual(buildCount, 3)

        let reloaded = TrackFingerprintBuildStore(identityService: identity)
        await reloaded.refresh(tracks: tracks)
        XCTAssertEqual(reloaded.completedCount, 3)
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
