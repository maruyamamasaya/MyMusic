import Observation
import SwiftUI
import UIKit
import XCTest
@testable import MyMusic

@MainActor
final class TrackFeatureDisplayIntegrationTests: XCTestCase {
    func testImportReimportAndDeleteNotifyFeatureReaders() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let persistence = TrackFeaturePersistenceService(fileURL: directory.appending(path: "features.json"))
        let store = TrackFeatureStore(persistence: persistence)
        await store.loadIfNeeded()
        let track = makeTrack()

        let imported = expectation(description: "Empty feature reader invalidates after import")
        withObservationTracking {
            XCTAssertNil(store.feature(for: track.id))
        } onChange: {
            imported.fulfill()
        }
        _ = try await store.import(
            data: json(entries: [entry(path: track.relativePath!)], version: 2),
            libraryTracks: [track]
        )
        await fulfillment(of: [imported], timeout: 1)
        let first = try XCTUnwrap(store.feature(for: track.id))
        XCTAssertEqual(TrackFeaturePresentation.badgeItems(for: first.values).map(\.id), ["piano", "calm", "ambient"])

        let updated = expectation(description: "Feature reader invalidates after reimport")
        withObservationTracking {
            _ = store.feature(for: track.id)
        } onChange: {
            updated.fulfill()
        }
        let result = try await store.import(
            data: json(entries: [entry(path: track.relativePath!, piano: 0.2)], version: 3),
            libraryTracks: [track]
        )
        await fulfillment(of: [updated], timeout: 1)
        XCTAssertEqual(result.updatedCount, 1)
        XCTAssertEqual(store.storedFeatureCount, 1)
        XCTAssertEqual(store.analysisVersions, [3])
        let second = try XCTUnwrap(store.feature(for: track.id))
        XCTAssertEqual(TrackFeaturePresentation.badgeItems(for: second.values).map(\.id), ["calm", "ambient"])

        let reloaded = TrackFeatureStore(persistence: persistence)
        await reloaded.loadIfNeeded()
        XCTAssertEqual(reloaded.feature(for: track.id)?.values, second.values)
        XCTAssertEqual(reloaded.lastImportReport?.updatedCount, 1)

        let deleted = expectation(description: "Feature reader invalidates after deletion")
        withObservationTracking {
            _ = store.feature(for: track.id)
        } onChange: {
            deleted.fulfill()
        }
        try await store.deleteAll()
        await fulfillment(of: [deleted], timeout: 1)
        XCTAssertNil(store.feature(for: track.id))
        XCTAssertNil(store.lastImportReport)
    }

    func testIssueSamplesAreBoundedAndAmbiguousTracksAreNotSaved() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TrackFeatureStore(persistence: TrackFeaturePersistenceService(
            fileURL: directory.appending(path: "features.json")
        ))
        let first = makeTrack()
        var duplicate = makeTrack()
        duplicate.relativePath = "Other/song.flac"
        let unmatched = (0..<25).map { entry(path: "Missing/\($0).flac", size: 99) }
        let ambiguous = (0..<25).map { entry(path: "Moved/\($0).flac") }
        let result = try await store.import(
            data: json(entries: unmatched + ambiguous),
            libraryTracks: [first, duplicate]
        )
        XCTAssertEqual(result.totalCount, 50)
        XCTAssertEqual(result.unmatchedCount, 25)
        XCTAssertEqual(result.ambiguousCount, 25)
        XCTAssertEqual(result.unmatchedSamplePaths.count, 20)
        XCTAssertEqual(result.ambiguousSamplePaths.count, 20)
        XCTAssertEqual(store.storedFeatureCount, 0)
    }

    func testOlderVersionIsReportedAsSkippedWithoutChangingBadgeScores() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TrackFeatureStore(persistence: TrackFeaturePersistenceService(
            fileURL: directory.appending(path: "features.json")
        ))
        let track = makeTrack()
        _ = try await store.import(data: json(entries: [entry(path: track.relativePath!)], version: 2), libraryTracks: [track])
        let result = try await store.import(
            data: json(entries: [entry(path: track.relativePath!, piano: 0.1)], version: 1),
            libraryTracks: [track]
        )
        XCTAssertEqual(result.skippedOlderAnalysisCount, 1)
        XCTAssertEqual(result.updatedCount, 0)
        XCTAssertEqual(store.feature(for: track.id)?.values.piano, 0.92)
        XCTAssertEqual(store.lastImportReport?.analysisVersion, 1)
        XCTAssertEqual(store.analysisVersions, [2])
    }

    func testLegacyPersistenceWithoutImportReportStillLoads() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appending(path: "features.json")
        try Data(#"{"version":1,"features":[],"lastImportDate":"2026-08-27T00:00:00Z"}"#.utf8).write(to: url)
        let snapshot = try await TrackFeaturePersistenceService(fileURL: url).load()
        XCTAssertTrue(snapshot.features.isEmpty)
        XCTAssertNotNil(snapshot.lastImportDate)
        XCTAssertNil(snapshot.lastImportReport)
    }

    func testBadgeRendersAtCompactWidthAndLargeDynamicType() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TrackFeatureStore(persistence: TrackFeaturePersistenceService(
            fileURL: directory.appending(path: "features.json")
        ))
        let track = makeTrack()
        _ = try await store.import(data: json(entries: [entry(path: track.relativePath!)]), libraryTracks: [track])
        let feature = try XCTUnwrap(store.feature(for: track.id))
        var heights: [CGFloat] = []
        for size in [DynamicTypeSize.large, .accessibility3] {
            let renderer = ImageRenderer(content:
                TrackFeatureBadgeView(track: track, feature: feature)
                    .environment(store)
                    .dynamicTypeSize(size)
                    .environment(\.colorScheme, size == .large ? .light : .dark)
                    .padding(16)
                    .background(size == .large ? Color.white : Color.black)
            )
            renderer.proposedSize = ProposedViewSize(width: 320, height: nil)
            renderer.scale = 2
            let image = try XCTUnwrap(renderer.uiImage)
            XCTAssertLessThanOrEqual(image.size.width, 320.5)
            XCTAssertGreaterThanOrEqual(image.size.height, 44)
            heights.append(image.size.height)
            let attachment = XCTAttachment(image: image)
            attachment.name = size == .large ? "Feature badges - compact light" : "Feature badges - accessibility dark"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        XCTAssertGreaterThan(heights[1], heights[0])
    }

    func testFeaturesRenderInsideArtworkAudioInformation() async throws {
        let directory = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = TrackFeatureStore(persistence: TrackFeaturePersistenceService(
            fileURL: directory.appending(path: "features.json")
        ))
        let track = makeTrack()
        _ = try await store.import(data: json(entries: [entry(path: track.relativePath!)]), libraryTracks: [track])
        let information = AudioInformation(
            codec: "FLAC", sampleRate: 96_000, bitDepth: 24, bitRate: 2_800_000, channels: 2
        )
        // ScrollView is UIKit-backed; use a hosted view rather than ImageRenderer.
        let controller = UIHostingController(rootView:
            AudioInformationView(
                track: track, information: information, spectrumLevels: [0.2, 0.6, 0.9, 0.5],
                onShowArtwork: {}
            )
            .environment(store)
            .environment(\.colorScheme, .light)
            .frame(width: 360, height: 360)
            .background(Color.white)
            .ignoresSafeArea()
        )
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 360, height: 360)
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        controller.view.layoutIfNeeded()
        let image = UIGraphicsImageRenderer(size: CGSize(width: 360, height: 360)).image { _ in
            XCTAssertTrue(controller.view.drawHierarchy(in: CGRect(x: 0, y: 0, width: 360, height: 360), afterScreenUpdates: true))
        }
        XCTAssertEqual(image.size.width, 360)
        XCTAssertEqual(image.size.height, 360)
        let attachment = XCTAttachment(image: image)
        attachment.name = "Artwork back - audio information and features"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func makeTrack() -> Track {
        Track(
            id: UUID(), title: "Song", artistName: "Artist", albumTitle: "Album",
            duration: 243.21, fileURL: URL(fileURLWithPath: "/tmp/no-audio-is-read.flac"),
            relativePath: "Artist/Album/song.flac", fileSize: 123_456
        )
    }

    private func entry(path: String, size: Int = 123_456, piano: Double = 0.92) -> [String: Any] {
        [
            "relativePath": path, "fileSize": size, "duration": 243.21,
            "title": "Song", "artist": "Artist", "album": "Album",
            "features": ["tempo": 86, "energy": 0.28, "piano": piano, "calm": 0.84, "ambient": 0.73, "electronic": 0.31]
        ]
    }

    private func json(entries: [[String: Any]], version: Int = 1) throws -> Data {
        try JSONSerialization.data(withJSONObject: [
            "schemaVersion": 1, "analysisVersion": version,
            "generatedAt": "2026-08-27T00:00:00Z", "tracks": entries
        ])
    }
}
