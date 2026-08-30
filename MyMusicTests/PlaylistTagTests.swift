import XCTest
@testable import MyMusic

final class PlaylistTagModelTests: XCTestCase {
    func testLegacyPlaylistWithoutTagsDecodesWithEmptyTags() throws {
        let playlist = makePlaylist(tags: ["集中"])
        var object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(playlist)) as? [String: Any]
        )
        object.removeValue(forKey: "tags")

        let decoded = try JSONDecoder().decode(
            Playlist.self,
            from: JSONSerialization.data(withJSONObject: object)
        )

        XCTAssertEqual(decoded.tags, [])
        XCTAssertEqual(decoded.trackIDs, playlist.trackIDs)
        XCTAssertEqual(decoded.kind, playlist.kind)
    }

    func testTagsNormalizeWhitespaceAndCaseInsensitiveDuplicates() {
        let tags = PlaylistTagRules.normalizedTags([
            "  夜  ", "集中\n用", "NIGHT", "night", "夜"
        ])

        XCTAssertEqual(tags, ["夜", "集中 用", "NIGHT"])
    }

    func testGlobalTagListIsNotLimitedByPerPlaylistMaximum() {
        let tags = PlaylistTagRules.uniqueSortedTags(
            (0...PlaylistTagRules.maximumTagCount).map { "tag-\($0)" }
        )

        XCTAssertEqual(tags.count, PlaylistTagRules.maximumTagCount + 1)
    }

    private func makePlaylist(tags: [String]) -> Playlist {
        Playlist(
            id: UUID(),
            name: "Test",
            trackIDs: [UUID()],
            createdAt: Date(timeIntervalSince1970: 1_800_000_000),
            updatedAt: Date(timeIntervalSince1970: 1_800_000_100),
            kind: .regular,
            tags: tags
        )
    }
}

@MainActor
final class PlaylistTagStoreTests: XCTestCase {
    func testTagFilteringAndTagChangesDoNotMutateTracks() async {
        let persistence = PlaylistMemoryPersistence()
        let store = PlaylistStore(persistence: persistence)
        let first = makeTrack("First")
        let second = makeTrack("Second")
        let playlistID = store.createPlaylist(named: "Mix")!
        store.addTracks([first, second], to: playlistID)

        store.setTags(["夜", "集中"], for: playlistID)

        XCTAssertEqual(store.playlist(id: playlistID)?.trackIDs, [first.id, second.id])
        XCTAssertEqual(store.playlists(of: .regular, tagged: "夜").map(\.id), [playlistID])
        XCTAssertTrue(store.playlists(of: .regular, tagged: "朝").isEmpty)
        XCTAssertEqual(store.allTags, ["集中", "夜"])
        await store.waitForPendingSave()
    }

    func testRapidUpdatesPersistNewestSnapshotLast() async {
        let persistence = DelayedFirstPlaylistPersistence()
        let store = PlaylistStore(persistence: persistence)
        let playlistID = store.createPlaylist(named: "Mix")!

        store.setTags(["first"], for: playlistID)
        store.setTags(["latest"], for: playlistID)
        await store.waitForPendingSave()

        let saved = await persistence.loadedPlaylists()
        XCTAssertEqual(saved.first?.tags, ["latest"])
    }

    func testEditingPlaylistDuringPlaybackDoesNotMutateActiveQueue() async {
        let playlistStore = PlaylistStore(persistence: PlaylistMemoryPersistence())
        let first = makeTrack("First")
        let second = makeTrack("Second")
        let playlistID = playlistStore.createPlaylist(named: "Playing")!
        playlistStore.addTracks([first, second], to: playlistID)
        let initialTracks = playlistStore.tracks(for: playlistID, in: [first, second])
        let playerStore = PlayerStore(
            audioPlayer: PlaylistTagAudioPlayerSpy(),
            nowPlayingService: PlaylistTagNowPlayingSpy(),
            remoteCommandService: PlaylistTagRemoteCommandSpy()
        )
        playerStore.playQueue(initialTracks, startingAt: 0)

        playlistStore.setTags(["再生中"], for: playlistID)
        playlistStore.removeTrack(second.id, from: playlistID)

        XCTAssertEqual(playerStore.currentTrack?.id, first.id)
        XCTAssertEqual(playerStore.queue.map(\.id), [first.id, second.id])
        XCTAssertEqual(playlistStore.playlist(id: playlistID)?.trackIDs, [first.id])
        await playlistStore.waitForPendingSave()
    }

    private func makeTrack(_ title: String) -> Track {
        Track(
            id: UUID(),
            title: title,
            artistName: "Artist",
            duration: 120,
            fileURL: URL(fileURLWithPath: "/tmp/\(title).wav"),
            relativePath: "\(title).wav"
        )
    }
}

final class PlaylistTagTransferTests: XCTestCase {
    func testJSONAndMarkdownRoundTripsPreserveTags() throws {
        let track = Track(
            id: UUID(),
            title: "Track",
            artistName: "Artist",
            duration: 120,
            fileURL: URL(fileURLWithPath: "/tmp/Track.wav")
        )
        let playlist = Playlist(
            id: UUID(),
            name: "Tagged",
            trackIDs: [track.id],
            createdAt: Date(),
            updatedAt: Date(),
            tags: ["夜", "集中"]
        )
        let exporter = MusicDataExportService()
        let importer = MusicDataImportService()

        let json = try exporter.playlistJSON(playlist, tracks: [track])
        let jsonResult = try importer.parse(data: json.data, fileExtension: "json", libraryTracks: [track])
        XCTAssertEqual(jsonResult.playlists.first?.tags, ["夜", "集中"])

        let markdown = exporter.playlistMarkdown(playlist, tracks: [track])
        let markdownResult = try importer.parse(data: markdown.data, fileExtension: "md", libraryTracks: [track])
        XCTAssertEqual(markdownResult.playlists.first?.tags, ["夜", "集中"])
    }
}

private actor PlaylistMemoryPersistence: PlaylistPersistenceServicing {
    private var playlists: [Playlist] = []
    func load() async throws -> [Playlist] { playlists }
    func save(_ playlists: [Playlist]) async throws { self.playlists = playlists }
}

private actor DelayedFirstPlaylistPersistence: PlaylistPersistenceServicing {
    private var playlists: [Playlist] = []
    private var saveCount = 0

    func load() async throws -> [Playlist] { playlists }

    func save(_ playlists: [Playlist]) async throws {
        saveCount += 1
        if saveCount == 1 {
            try await Task.sleep(for: .milliseconds(75))
        }
        self.playlists = playlists
    }

    func loadedPlaylists() -> [Playlist] { playlists }
}

@MainActor
private final class PlaylistTagAudioPlayerSpy: AudioPlayerServicing {
    var eventHandler: ((AudioPlaybackEvent) -> Void)?
    func play(_ track: Track) async throws {}
    func pause() {}
    func resume() async throws {}
    func seek(to time: TimeInterval) {}
    func stop() {}
}

@MainActor
private final class PlaylistTagNowPlayingSpy: NowPlayingServicing {
    func setTrack(_ track: Track, duration: TimeInterval, elapsedTime: TimeInterval, isPlaying: Bool) {}
    func updateDuration(_ duration: TimeInterval, elapsedTime: TimeInterval, isPlaying: Bool) {}
    func updatePlayback(elapsedTime: TimeInterval, isPlaying: Bool) {}
    func clear() {}
}

@MainActor
private final class PlaylistTagRemoteCommandSpy: RemoteCommandServicing {
    func configure(actions: RemoteCommandActions) {}
    func updateAvailability(hasTrack: Bool, canGoNext: Bool, canGoPrevious: Bool) {}
}
