import SwiftUI
import UIKit
import XCTest
@testable import MyMusic

final class MoodStationServiceTests: XCTestCase {
    private let service = MoodStationService()

    func testCalmAndEnergeticAnswersFavorDifferentTracks() throws {
        let calm = stationValues(["calm": 0.95, "energy": 0.15, "aggressive": 0.05, "bright": 0.2, "dark": 0.7])
        let energetic = stationValues(["calm": 0.1, "energy": 0.9, "aggressive": 0.9, "bright": 0.8, "dark": 0.4])
        let relax = StationAnswers(mood: .relax, sound: .soft)
        let uplift = StationAnswers(mood: .uplift, sound: .heavy)
        XCTAssertGreaterThan(try XCTUnwrap(service.score(calm, for: relax)), try XCTUnwrap(service.score(energetic, for: relax)))
        XCTAssertGreaterThan(try XCTUnwrap(service.score(energetic, for: uplift)), try XCTUnwrap(service.score(calm, for: uplift)))
    }

    func testMissingAndInvalidValuesAreNotTreatedAsLowScores() {
        let answers = StationAnswers(mood: .relax, sound: .soft)
        XCTAssertNil(service.score(stationValues([:]), for: answers))
        XCTAssertNil(service.score(stationValues(["tempo": 85]), for: answers))
        XCTAssertNil(service.score(stationValues(["calm": .nan, "energy": -.infinity, "aggressive": 2]), for: answers))
        XCTAssertNil(service.score(stationValues(["energy": 0.15]), for: answers))
        XCTAssertFalse(service.hasUsableFeatures(stationValues(["tempo": 85])))
    }

    func testSurpriseAndIndistinguishablePoolsFinishAfterTwoQuestions() {
        let candidates = [candidate(vocal: 0.1), candidate(vocal: 0.9)]
        XCTAssertNil(service.followUp(for: StationAnswers(mood: .surprise, sound: .soft), candidates: candidates))
        XCTAssertNil(service.followUp(for: StationAnswers(mood: .focus, sound: .soft), candidates: [candidates[0]]))
        XCTAssertNil(service.followUp(for: StationAnswers(mood: .focus, sound: .soft), candidates: [candidate(), candidate()]))
    }

    func testFollowUpBranchesByMoodAndAvailableVariation() {
        XCTAssertEqual(service.followUp(
            for: StationAnswers(mood: .focus, sound: .soft),
            candidates: [candidate(vocal: 0.1), candidate(vocal: 0.9)]
        ), .vocals)
        XCTAssertEqual(service.followUp(
            for: StationAnswers(mood: .relax, sound: .soft),
            candidates: [candidate(electronic: 0.1), candidate(electronic: 0.9)]
        ), .texture)
        let energetic = [0.2, 0.9].map { aggression in
            StationCandidate(trackID: UUID(), artist: "A", values: stationValues([
                "energy": 0.85, "aggressive": aggression, "calm": 0.2, "bright": 0.8, "dark": 0.6
            ]))
        }
        XCTAssertEqual(service.followUp(for: StationAnswers(mood: .uplift, sound: .heavy), candidates: energetic), .intensity)
    }

    func testFinalVocalAnswerOverridesFocusDefault() throws {
        let vocal = candidate(vocal: 0.9).values
        let instrumental = candidate(vocal: 0.1).values
        let song = StationAnswers(mood: .focus, sound: .soft, refinement: .vocals, direction: .first)
        let sound = StationAnswers(mood: .focus, sound: .soft, refinement: .vocals, direction: .second)
        XCTAssertGreaterThan(try XCTUnwrap(service.score(vocal, for: song)), try XCTUnwrap(service.score(instrumental, for: song)))
        XCTAssertGreaterThan(try XCTUnwrap(service.score(instrumental, for: sound)), try XCTUnwrap(service.score(vocal, for: sound)))
        let skipped = StationAnswers(mood: .focus, sound: .soft, refinement: .vocals)
        XCTAssertEqual(service.score(vocal, for: skipped), service.score(vocal, for: StationAnswers(mood: .focus, sound: .soft)))
    }

    func testLimitUniquenessAndSeededVariation() {
        let candidates = (0..<60).map { _ in candidate() }
        let answers = StationAnswers(mood: .relax, sound: .soft)
        var first = StationSeed(seed: 1)
        var same = StationSeed(seed: 1)
        var other = StationSeed(seed: 2)
        let result = service.makeStation(answers: answers, candidates: candidates + candidates, using: &first)
        XCTAssertEqual(result.trackIDs.count, 25)
        XCTAssertEqual(Set(result.trackIDs).count, 25)
        XCTAssertEqual(result.analyzedTrackCount, 60)
        XCTAssertEqual(result.trackIDs, service.makeStation(answers: answers, candidates: candidates, using: &same).trackIDs)
        XCTAssertNotEqual(result.trackIDs, service.makeStation(answers: answers, candidates: candidates, using: &other).trackIDs)
    }

    func testAvailableDecadesAreDerivedFromValidYearMetadataAndFilterTheStation() throws {
        let nineties = candidate(year: 1994)
        let twoThousands = candidate(year: 2007)
        let unknown = candidate(year: nil)
        let invalid = candidate(year: 0)
        let candidates = [twoThousands, unknown, nineties, invalid]

        XCTAssertEqual(service.availableDecades(in: candidates).map(\.startYear), [2000, 1990])

        var rng = StationSeed(seed: 1)
        let decade = try XCTUnwrap(StationDecade(year: 1994))
        let result = service.makeStation(
            answers: StationAnswers(mood: .relax, sound: .soft, decade: decade),
            candidates: candidates,
            using: &rng
        )

        XCTAssertEqual(result.trackIDs, [nineties.trackID])
        XCTAssertEqual(result.analyzedTrackCount, 1)
        XCTAssertEqual(result.answers.decade, decade)
        XCTAssertTrue(decade.contains(1999))
        XCTAssertFalse(decade.contains(2000))
        XCTAssertFalse(decade.contains(nil))
    }

    func testUnrelatedTracksDoNotFillTheQueue() {
        let close = candidate()
        let unrelated = StationCandidate(trackID: UUID(), artist: "B", values: stationValues([
            "energy": 1, "aggressive": 1, "calm": 0
        ]))
        var rng = StationSeed(seed: 1)
        let result = service.makeStation(answers: StationAnswers(mood: .relax, sound: .soft),
                                         candidates: [close, unrelated], using: &rng)
        XCTAssertEqual(result.trackIDs, [close.trackID])
        XCTAssertEqual(result.matchingTrackCount, 1)
        XCTAssertTrue(service.makeStation(answers: result.answers, candidates: [unrelated], using: &rng).trackIDs.isEmpty)
        XCTAssertTrue(service.makeStation(answers: result.answers, candidates: [], using: &rng).trackIDs.isEmpty)
        XCTAssertTrue(service.makeStation(answers: result.answers, candidates: [close], limit: 0, using: &rng).trackIDs.isEmpty)
    }

    func testArtistDiversityAmongEquivalentMatches() {
        let candidates = (0..<12).map { index in
            StationCandidate(trackID: UUID(), artist: index < 6 ? "A" : "B", values: candidate().values)
        }
        var rng = StationSeed(seed: 2)
        let result = service.makeStation(answers: StationAnswers(mood: .relax, sound: .soft), candidates: candidates, using: &rng)
        let byID = Dictionary(uniqueKeysWithValues: candidates.map { ($0.trackID, $0.artist) })
        for pair in zip(result.trackIDs, result.trackIDs.dropFirst()) {
            XCTAssertNotEqual(byID[pair.0], byID[pair.1])
        }
    }

    func testOverplayChangesRankingButNotPureMoodEligibility() {
        let answers = StationAnswers(mood: .relax, sound: .soft)
        let overplayed = StationCandidate(
            trackID: UUID(), artist: "A", values: candidate().values, overplayFactor: 0.8
        )
        let normal = StationCandidate(
            trackID: UUID(), artist: "B", values: candidate().values, overplayFactor: 1
        )
        let unrelated = StationCandidate(trackID: UUID(), artist: "C", values: stationValues([
            "energy": 1, "aggressive": 1, "calm": 0
        ]), overplayFactor: 1)
        var rng = StationSeed(seed: 8)
        let result = service.makeStation(
            answers: answers, candidates: [overplayed, normal, unrelated], using: &rng
        )

        XCTAssertEqual(result.matchingTrackCount, 2)
        XCTAssertEqual(Set(result.trackIDs), Set([overplayed.trackID, normal.trackID]))
        XCTAssertEqual(result.trackIDs.first, normal.trackID)
        XCTAssertTrue(result.trackIDs.contains(overplayed.trackID))
    }

    private func candidate(vocal: Double = 0.1, electronic: Double = 0.3, year: Int? = nil) -> StationCandidate {
        StationCandidate(trackID: UUID(), artist: "Artist", year: year, values: stationValues([
            "energy": 0.2, "calm": 0.9, "aggressive": 0.1, "ambient": 0.8,
            "vocal": vocal, "instrumental": 1 - vocal, "electronic": electronic
        ]))
    }
}

@MainActor
final class StationStoreIntegrationTests: XCTestCase {
    func testQuestionFlowGeneratesTemporaryStationAndStartsQueue() async throws {
        let fixture = StationFixture(featureCount: 3)
        await fixture.store.prepare()
        fixture.store.begin()
        fixture.store.chooseMood(.focus)
        XCTAssertEqual(fixture.store.phase, .sound)
        fixture.store.chooseSound(.soft)
        XCTAssertEqual(fixture.store.phase, .refinement)
        fixture.store.chooseDirection(.second)
        XCTAssertEqual(fixture.store.phase, .generating)
        await fixture.store.generate()
        XCTAssertEqual(fixture.store.phase, .result)
        XCTAssertEqual(fixture.store.stationTracks.count, 3)
        XCTAssertNil(fixture.playlists.playlists.first)
        XCTAssertTrue(fixture.store.play())
        XCTAssertEqual(fixture.player.queue.map(\.id), fixture.store.stationTracks.map(\.id))
        XCTAssertFalse(fixture.player.isShuffleEnabled)
    }

    func testHiddenAndRemovedFeaturesAreRevalidatedBeforePlayback() async throws {
        let fixture = StationFixture(featureCount: 1)
        await fixture.store.prepare()
        fixture.store.begin()
        fixture.store.chooseMood(.relax)
        fixture.store.chooseSound(.soft)
        if fixture.store.phase == .refinement { fixture.store.chooseDirection(nil) }
        await fixture.store.generate()
        let trackID = try XCTUnwrap(fixture.store.stationTracks.first?.id)
        fixture.history.permanentlyHideFromShuffle(trackID: trackID)
        XCTAssertTrue(fixture.store.stationTracks.isEmpty)
        XCTAssertFalse(fixture.store.play())
        XCTAssertNotNil(fixture.store.errorMessage)
    }

    func testDecadeQuestionUsesOnlyYearsPresentInEligibleTracks() async throws {
        let fixture = StationFixture(featureCount: 3, years: [1994, 2007, nil])
        await fixture.store.prepare()
        fixture.store.begin()
        fixture.store.chooseMood(.relax)
        fixture.store.chooseSound(.soft)
        if fixture.store.phase == .refinement { fixture.store.chooseDirection(nil) }

        XCTAssertEqual(fixture.store.phase, .decade)
        XCTAssertEqual(fixture.store.availableDecades.map(\.startYear), [2000, 1990])

        let nineties = try XCTUnwrap(fixture.store.availableDecades.last)
        fixture.store.chooseDecade(nineties)
        XCTAssertEqual(fixture.store.phase, .generating)
        await fixture.store.generate()

        XCTAssertEqual(fixture.store.phase, .result)
        XCTAssertEqual(fixture.store.stationTracks.map(\.year), [1994])
        XCTAssertEqual(fixture.store.station?.answers.decade, nineties)
        XCTAssertTrue(fixture.store.station?.answers.summary.contains("1990年代") == true)
    }

    func testNoImportedFeaturesProducesUnavailableState() async {
        let fixture = StationFixture(featureCount: 0)
        await fixture.store.prepare()
        XCTAssertFalse(fixture.store.isLoading)
        XCTAssertTrue(fixture.store.hasLibraryTracks)
        XCTAssertEqual(fixture.store.availableFeatureCount, 0)
    }

    func testQuestionAndResultRenderForAccessibilityAndDarkMode() async throws {
        let fixture = StationFixture(featureCount: 3, years: [1994, 2007, 2013])
        await fixture.store.prepare()
        fixture.store.begin()
        fixture.store.chooseMood(.focus)
        let question = try await snapshot(
            StationQuestionView().environment(fixture.store).dynamicTypeSize(.accessibility2),
            colorScheme: .light
        )
        XCTAssertEqual(question.size, CGSize(width: 390, height: 844))
        attach(question, name: "Station question 2 - Accessibility Light")

        fixture.store.chooseSound(.soft)
        if fixture.store.phase == .refinement { fixture.store.chooseDirection(.second) }
        XCTAssertEqual(fixture.store.phase, .decade)
        let decadeQuestion = try await snapshot(
            StationQuestionView().environment(fixture.store).dynamicTypeSize(.accessibility2),
            colorScheme: .dark
        )
        XCTAssertEqual(decadeQuestion.size, CGSize(width: 390, height: 844))
        attach(decadeQuestion, name: "Station decade question - Accessibility Dark")

        fixture.store.chooseDecade(nil)
        await fixture.store.generate()
        let result = try await snapshot(
            NavigationStack { StationResultView() }
                .environment(fixture.store)
                .environment(fixture.history),
            colorScheme: .dark
        )
        XCTAssertEqual(result.size, CGSize(width: 390, height: 844))
        attach(result, name: "Station result - Dark")
    }

    private func snapshot<V: View>(_ view: V, colorScheme: ColorScheme) async throws -> UIImage {
        let controller = UIHostingController(rootView: view.environment(\.colorScheme, colorScheme))
        let scene = try XCTUnwrap(UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first)
        let previousWindow = scene.windows.first(where: \.isKeyWindow)
        let window = UIWindow(windowScene: scene)
        window.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        controller.view.frame = window.bounds
        window.rootViewController = controller
        window.makeKeyAndVisible()
        defer {
            window.isHidden = true
            previousWindow?.makeKeyAndVisible()
        }
        controller.view.layoutIfNeeded()
        try await Task.sleep(for: .milliseconds(80))
        controller.view.layoutIfNeeded()
        return UIGraphicsImageRenderer(size: window.bounds.size).image { _ in
            XCTAssertTrue(controller.view.drawHierarchy(in: window.bounds, afterScreenUpdates: true))
        }
    }

    private func attach(_ image: UIImage, name: String) {
        let attachment = XCTAttachment(image: image)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}

@MainActor
private final class StationFixture {
    let tracks: [Track]
    let library: LibraryStore
    let features: TrackFeatureStore
    let history: PlaybackHistoryStore
    let player: PlayerStore
    let playlists = PlaylistStore(persistence: StationPlaylistPersistence())
    let store: StationStore

    init(featureCount: Int, years: [Int?]? = nil) {
        let trackYears = years ?? Array(repeating: nil, count: 3)
        tracks = (0..<3).map { index in
            Track(id: UUID(), title: "Song \(index)", artistName: "Artist \(index)", duration: 180,
                  fileURL: URL(fileURLWithPath: "/tmp/station-\(index).flac"),
                  relativePath: "station-\(index).flac", fileSize: Int64(100 + index),
                  year: index < trackYears.count ? trackYears[index] : nil)
        }
        let folder = URL(fileURLWithPath: "/tmp/station-library")
        let importService = StationFileImport(folders: [folder])
        library = LibraryStore(
            service: StationLibraryService(tracks: tracks), fileImportService: importService,
            persistence: StationLibraryPersistence(),
            identityService: TrackIdentityService(registryURL: URL(fileURLWithPath: "/tmp/unused-station-identities.json")),
            userDefaults: UserDefaults(suiteName: "StationFixture-\(UUID())")!
        )
        let imported = Array(tracks.prefix(featureCount)).enumerated().map { index, track in
            TrackFeature(
                trackID: track.id,
                sourceIdentity: TrackFeatureSourceIdentity(
                    relativePath: track.relativePath!, fileSize: track.fileSize!, duration: track.duration,
                    modificationDate: nil, contentHash: nil, title: track.title, artist: track.artistName, album: nil
                ),
                analysisVersion: 1, analyzedAt: .now, importedAt: .now,
                values: stationValues([
                    "energy": 0.2, "calm": 0.9, "aggressive": 0.1, "ambient": 0.8,
                    "electronic": Double(index) / 3, "vocal": index == 0 ? 0.1 : 0.9,
                    "instrumental": index == 0 ? 0.9 : 0.1
                ])
            )
        }
        features = TrackFeatureStore(persistence: StationFeaturePersistence(features: imported))
        history = PlaybackHistoryStore(persistence: StationHistoryPersistence())
        player = PlayerStore(audioPlayer: StationAudioPlayer(), playbackHistoryStore: history,
                             nowPlayingService: StationNowPlaying(), remoteCommandService: StationRemoteCommands())
        store = StationStore(libraryStore: library, featureStore: features, historyStore: history, playerStore: player)

    }
}

private struct StationLibraryService: MusicLibraryServicing {
    let tracks: [Track]
    func loadLibrary(from folderURL: URL, previousTracks: [Track]) async throws -> MusicLibrary { MusicLibrary.build(from: tracks) }
}

private final class StationFileImport: FileImportServicing, @unchecked Sendable {
    private var folders: [URL]
    init(folders: [URL]) { self.folders = folders }
    nonisolated func audioFiles(in folderURL: URL) async throws -> [URL] { [] }
    func saveLibraryFolders(_ urls: [URL]) throws { folders = urls }
    func restoreLibraryFolders() throws -> [URL] { folders }
}

private actor StationLibraryPersistence: LibraryPersistenceServicing {
    func load(for folderURL: URL) async throws -> MusicLibrary? { nil }
    func save(_ library: MusicLibrary, for folderURL: URL) async throws {}
}

private actor StationFeaturePersistence: TrackFeaturePersistenceServicing {
    var snapshot: TrackFeaturePersistenceSnapshot
    init(features: [TrackFeature]) { snapshot = TrackFeaturePersistenceSnapshot(features: features, lastImportDate: .now) }
    func load() async throws -> TrackFeaturePersistenceSnapshot { snapshot }
    func save(_ snapshot: TrackFeaturePersistenceSnapshot) async throws { self.snapshot = snapshot }
    func deleteAll() async throws { snapshot = TrackFeaturePersistenceSnapshot(features: [], lastImportDate: nil) }
}

private actor StationHistoryPersistence: PlaybackHistoryPersistenceServicing {
    func load() async throws -> [PlaybackHistory] { [] }
    func save(_ history: [PlaybackHistory]) async throws {}
}

private actor StationPlaylistPersistence: PlaylistPersistenceServicing {
    func load() async throws -> [Playlist] { [] }
    func save(_ playlists: [Playlist]) async throws {}
}

@MainActor private final class StationAudioPlayer: AudioPlayerServicing {
    var eventHandler: ((AudioPlaybackEvent) -> Void)?
    func play(_ track: Track) async throws { eventHandler?(.ready(duration: track.duration)) }
    func pause() {}
    func resume() async throws {}
    func seek(to time: TimeInterval) {}
    func stop() {}
}

@MainActor private final class StationNowPlaying: NowPlayingServicing {
    func setTrack(_ track: Track, duration: TimeInterval, elapsedTime: TimeInterval, isPlaying: Bool) {}
    func updateDuration(_ duration: TimeInterval, elapsedTime: TimeInterval, isPlaying: Bool) {}
    func updatePlayback(elapsedTime: TimeInterval, isPlaying: Bool) {}
    func clear() {}
}

@MainActor private final class StationRemoteCommands: RemoteCommandServicing {
    func configure(actions: RemoteCommandActions) {}
    func updateAvailability(hasTrack: Bool, canGoNext: Bool, canGoPrevious: Bool) {}
}

nonisolated func stationValues(_ values: [String: Double]) -> TrackFeatureValues {
    TrackFeatureValues(
        tempo: values["tempo"], energy: values["energy"], piano: values["piano"], ambient: values["ambient"],
        electronic: values["electronic"], drumAndBass: values["drumAndBass"], aggressive: values["aggressive"],
        calm: values["calm"], bright: values["bright"], dark: values["dark"], vocal: values["vocal"],
        instrumental: values["instrumental"], additional: nil
    )
}

private struct StationSeed: RandomNumberGenerator {
    var seed: UInt64
    mutating func next() -> UInt64 {
        seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return seed
    }
}
