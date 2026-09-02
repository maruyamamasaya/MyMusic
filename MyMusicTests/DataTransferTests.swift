import XCTest
@testable import MyMusic

final class AnalysisDataExportTests: XCTestCase {
    func testPlaybackEventsExportMatchesAnalyticsV1Contract() throws {
        let track = makeTrack(title: "Night Drive")
        let startedAt = Date(timeIntervalSince1970: 1_799_999_000)
        let endedAt = startedAt.addingTimeInterval(42)
        let exportedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let playbackEvent = PlaybackEvent(
            id: "event-001",
            trackID: track.id,
            startedAt: startedAt,
            endedAt: endedAt,
            listenedSeconds: 42,
            completionRatio: 42 / track.duration,
            wasSkipped: true,
            wasFullPlayback: false,
            startKind: .manual,
            startSource: .playlist,
            endKind: .userSkipped
        )
        let history = PlaybackHistory(
            trackID: track.id,
            isFavorite: false,
            playCount: 1,
            lastPlayedAt: endedAt,
            playbackEvents: [playbackEvent]
        )

        let file = try MusicDataExportService().playbackEventsJSON(
            [track.id: history],
            tracks: [track],
            exportedAt: exportedAt
        )
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: file.data) as? [String: Any]
        )
        let events = try XCTUnwrap(root["events"] as? [[String: Any]])
        let item = try XCTUnwrap(events.first)

        XCTAssertEqual(file.filename, "MyMusic-Playback-Events.json")
        XCTAssertEqual(root["schemaVersion"] as? Int, 1)
        XCTAssertEqual(root.keys.sorted(), ["events", "exportedAt", "schemaVersion"])
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(item["eventId"] as? String, "event-001")
        XCTAssertEqual(item["trackId"] as? String, track.id.uuidString)
        XCTAssertEqual(item["trackTitle"] as? String, "Night Drive")
        XCTAssertEqual(item["artist"] as? String, "Artist")
        XCTAssertNil(item["album"])
        XCTAssertEqual(item["playDuration"] as? Double, 42)
        XCTAssertEqual(item["trackDuration"] as? Double, track.duration)
        XCTAssertEqual(item["completed"] as? Bool, false)
        XCTAssertEqual(item["skipped"] as? Bool, true)
        XCTAssertEqual(item["playSource"] as? String, "playlist")
        XCTAssertEqual(item["selectionType"] as? String, "manual")
        XCTAssertEqual(item["platform"] as? String, "iOS")
        XCTAssertEqual(item["schemaVersion"] as? Int, 1)
        XCTAssertNotNil(item["playedAt"] as? String)
        XCTAssertEqual(
            item.keys.sorted(),
            ["completed", "eventId", "platform", "playDuration", "playSource", "playedAt",
             "schemaVersion", "selectionType", "skipped", "trackDuration", "trackId", "trackTitle", "artist"].sorted()
        )
    }

    func testPlaybackPreferencesExportContainsOnlyPreferenceContractFields() throws {
        let firstTrackID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let secondTrackID = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        let exportedAt = Date(timeIntervalSince1970: 1_800_000_000)
        let histories = [
            secondTrackID: PlaybackHistory(
                trackID: secondTrackID,
                isFavorite: true,
                playCount: 1,
                lastPlayedAt: exportedAt,
                playbackPreference: -2
            ),
            firstTrackID: PlaybackHistory(
                trackID: firstTrackID,
                isFavorite: false,
                playCount: 0,
                lastPlayedAt: nil,
                playbackPreference: 0
            )
        ]

        let file = try MusicDataExportService().playbackPreferencesJSON(
            histories,
            exportedAt: exportedAt
        )
        let root = try XCTUnwrap(
            JSONSerialization.jsonObject(with: file.data) as? [String: Any]
        )
        let tracks = try XCTUnwrap(root["tracks"] as? [[String: Any]])

        XCTAssertEqual(file.filename, "MyMusic-Playback-Preferences.json")
        XCTAssertEqual(root["schemaVersion"] as? Int, 1)
        XCTAssertEqual(root.keys.sorted(), ["exportedAt", "schemaVersion", "tracks"])
        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(tracks[0]["trackId"] as? String, firstTrackID.uuidString)
        XCTAssertEqual(tracks[0]["playbackPreference"] as? Int, 0)
        XCTAssertEqual(tracks[0].keys.sorted(), ["playbackPreference", "trackId"])
        XCTAssertEqual(tracks[1]["trackId"] as? String, secondTrackID.uuidString)
        XCTAssertEqual(tracks[1]["playbackPreference"] as? Int, -2)
    }

    func testFeatureAndNormalizationExportsContainExpectedTracks() throws {
        let normalizedTrack = makeTrack(title: "Quiet")
        let featureOnlyTrack = makeTrack(title: "Feature")
        let normalizedFeature = makeFeature(
            for: normalizedTrack,
            tempo: 120,
            integratedLUFS: -20,
            truePeakDBTP: -5,
            normalizationGainDB: 4
        )
        let featureOnly = makeFeature(for: featureOnlyTrack, tempo: 98)
        let exporter = MusicDataExportService()
        let exportedAt = Date(timeIntervalSince1970: 1_800_000_000)

        let featuresFile = try exporter.trackFeaturesJSON(
            [featureOnly, normalizedFeature],
            tracks: [normalizedTrack, featureOnlyTrack],
            exportedAt: exportedAt
        )
        let normalizationFile = try exporter.volumeNormalizationJSON(
            [featureOnly, normalizedFeature],
            tracks: [normalizedTrack, featureOnlyTrack],
            isEnabled: true,
            exportedAt: exportedAt
        )

        let featuresRoot = try XCTUnwrap(
            JSONSerialization.jsonObject(with: featuresFile.data) as? [String: Any]
        )
        let featureItems = try XCTUnwrap(featuresRoot["tracks"] as? [[String: Any]])
        XCTAssertEqual(featureItems.count, 2)
        XCTAssertEqual(Set(featureItems.compactMap { $0["title"] as? String }), ["Quiet", "Feature"])

        let normalizationRoot = try XCTUnwrap(
            JSONSerialization.jsonObject(with: normalizationFile.data) as? [String: Any]
        )
        let normalizationItems = try XCTUnwrap(normalizationRoot["tracks"] as? [[String: Any]])
        XCTAssertEqual(normalizationRoot["isEnabled"] as? Bool, true)
        XCTAssertEqual(normalizationItems.count, 1)
        XCTAssertEqual(normalizationItems.first?["trackID"] as? String, normalizedTrack.id.uuidString)
        XCTAssertEqual(normalizationItems.first?["normalizationGainDB"] as? Double, 4)
    }

    private func makeTrack(title: String) -> Track {
        Track(
            id: UUID(),
            title: title,
            artistName: "Artist",
            duration: 180,
            fileURL: URL(fileURLWithPath: "/tmp/\(title).m4a"),
            relativePath: "Album/\(title).m4a",
            fileSize: 1_024
        )
    }

    private func makeFeature(
        for track: Track,
        tempo: Double,
        integratedLUFS: Double? = nil,
        truePeakDBTP: Double? = nil,
        normalizationGainDB: Double? = nil
    ) -> TrackFeature {
        TrackFeature(
            trackID: track.id,
            sourceIdentity: TrackFeatureSourceIdentity(
                relativePath: track.relativePath!,
                fileSize: track.fileSize!,
                duration: track.duration,
                modificationDate: nil,
                contentHash: nil,
                title: track.title,
                artist: track.artistName,
                album: nil
            ),
            analysisVersion: 2,
            analyzedAt: Date(timeIntervalSince1970: 1_799_000_000),
            importedAt: Date(timeIntervalSince1970: 1_799_100_000),
            values: TrackFeatureValues(
                tempo: tempo,
                energy: 0.5,
                piano: nil,
                ambient: nil,
                electronic: nil,
                drumAndBass: nil,
                aggressive: nil,
                calm: nil,
                bright: nil,
                dark: nil,
                vocal: nil,
                instrumental: nil,
                additional: nil,
                integratedLUFS: integratedLUFS,
                truePeakDBTP: truePeakDBTP,
                normalizationGainDB: normalizationGainDB
            )
        )
    }
}

@MainActor
final class SettingsDataTransferTests: XCTestCase {
    func testEqualizerRoundTripAppliesSettingsAndMergesCustomPresets() throws {
        let sourceDefaults = try makeDefaults("source")
        let targetDefaults = try makeDefaults("target")
        defer {
            sourceDefaults.removePersistentDomain(forName: sourceDefaultsSuite)
            targetDefaults.removePersistentDomain(forName: targetDefaultsSuite)
        }
        let source = SettingsStore(defaults: sourceDefaults)
        source.setEqualizerEnabled(true)
        source.setPreamp(-3)
        source.setBandGain(4, at: 0)
        XCTAssertTrue(source.saveCustomPreset(named: "Night"))

        let file = try MusicDataExportService().equalizerJSON(
            settings: source.equalizer,
            customPresets: source.customEqualizerPresets
        )
        let payload = try MusicSettingsImportService().parse(data: file.data)
        let target = SettingsStore(defaults: targetDefaults)
        target.setBandGain(-2, at: 0)
        XCTAssertTrue(target.saveCustomPreset(named: "night"))

        guard case let .equalizer(settings, presets) = payload else {
            return XCTFail("Expected equalizer payload")
        }
        let counts = target.importEqualizer(settings, customPresets: presets)

        XCTAssertEqual(counts.added, 0)
        XCTAssertEqual(counts.updated, 1)
        XCTAssertTrue(target.equalizer.isEnabled)
        XCTAssertEqual(target.equalizer.preamp, -3)
        XCTAssertEqual(target.equalizer.bands[0].gain, 4)
        XCTAssertEqual(target.customEqualizerPresets.map(\.name), ["Night"])

        let reloaded = SettingsStore(defaults: targetDefaults)
        XCTAssertEqual(reloaded.equalizer, target.equalizer)
        XCTAssertEqual(reloaded.customEqualizerPresets, target.customEqualizerPresets)
    }

    func testGenrePresetRoundTripMergesByNameAndPersists() throws {
        let sourceDefaults = try makeDefaults("genre-source")
        let targetDefaults = try makeDefaults("genre-target")
        defer {
            sourceDefaults.removePersistentDomain(forName: sourceDefaultsSuite)
            targetDefaults.removePersistentDomain(forName: targetDefaultsSuite)
        }
        let source = LibraryStore(userDefaults: sourceDefaults)
        source.saveGenreDisplayPreset(named: "集中", enabledGenreNames: ["Ambient", "Classical"])
        source.saveGenreDisplayPreset(named: "朝", enabledGenreNames: ["Pop"])
        let file = try MusicDataExportService().genreDisplayPresetsJSON(source.genreDisplayPresets)
        let payload = try MusicSettingsImportService().parse(data: file.data)

        let target = LibraryStore(userDefaults: targetDefaults)
        target.saveGenreDisplayPreset(named: "集中", enabledGenreNames: ["Rock"])
        guard case let .genreDisplayPresets(presets) = payload else {
            return XCTFail("Expected genre preset payload")
        }
        let counts = target.importGenreDisplayPresets(presets)

        XCTAssertEqual(counts.added, 1)
        XCTAssertEqual(counts.updated, 1)
        XCTAssertEqual(target.genreDisplayPresets.map(\.name), ["集中", "朝"])
        XCTAssertEqual(target.genreDisplayPresets[0].enabledGenreNames, ["Ambient", "Classical"])

        let reloaded = LibraryStore(userDefaults: targetDefaults)
        XCTAssertEqual(reloaded.genreDisplayPresets, target.genreDisplayPresets)
    }

    func testOutOfRangeEqualizerPresetIsRejected() throws {
        let document = EqualizerTransferDocument(
            kind: .equalizer,
            version: 1,
            equalizer: .flat,
            customPresets: [EqualizerPreset(
                name: "Invalid",
                preamp: 1,
                gains: Array(repeating: 0, count: EqualizerSettings.frequencies.count)
            )]
        )

        XCTAssertThrowsError(try MusicSettingsImportService().parse(data: JSONEncoder().encode(document)))
    }

    private var sourceDefaultsSuite: String { "SettingsDataTransferTests-source" }
    private var targetDefaultsSuite: String { "SettingsDataTransferTests-target" }

    private func makeDefaults(_ suffix: String) throws -> UserDefaults {
        let suiteName: String
        if suffix.contains("source") {
            suiteName = sourceDefaultsSuite
        } else {
            suiteName = targetDefaultsSuite
        }
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
