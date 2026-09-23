import Foundation
import XCTest
@testable import MyMusic

@MainActor
final class LibraryGenreFilterTests: XCTestCase {
    func testGenreFilterPublishesLatestRequestedLibrary() async throws {
        let ambient = makeTrack(title: "Ambient", genre: "Ambient")
        let rock = makeTrack(title: "Rock", genre: "Rock")
        let folder = URL(fileURLWithPath: "/tmp/genre-filter-library")
        let suiteName = "LibraryGenreFilterTests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = LibraryStore(
            service: GenreFilterLibraryService(tracks: [ambient, rock]),
            fileImportService: GenreFilterFileImport(folders: [folder]),
            persistence: GenreFilterLibraryPersistence(),
            identityService: TrackIdentityService(
                registryURL: URL(fileURLWithPath: "/tmp/unused-genre-filter-identities.json")
            ),
            userDefaults: defaults
        )

        await store.restoreAndLoadIfNeeded()
        await store.waitForPendingGenreFilter()
        XCTAssertEqual(Set(store.tracks.map(\.id)), [ambient.id, rock.id])
        XCTAssertEqual(store.album(containing: ambient.id)?.trackIDs, [ambient.id])
        XCTAssertEqual(store.artist(containing: rock.id)?.trackIDs, [rock.id])

        store.setEnabledGenres(["Ambient"])
        store.setEnabledGenres(["Rock"])

        try await waitUntil { store.tracks.map(\.id) == [rock.id] }
        XCTAssertEqual(store.albums.flatMap(\.trackIDs), [rock.id])
        XCTAssertEqual(store.artists.flatMap(\.trackIDs), [rock.id])
        XCTAssertEqual(store.genres.flatMap(\.trackIDs), [rock.id])
        XCTAssertNil(store.album(containing: ambient.id))
        XCTAssertNil(store.artist(containing: ambient.id))
        XCTAssertEqual(store.album(containing: rock.id)?.trackIDs, [rock.id])
        XCTAssertEqual(store.artist(containing: rock.id)?.trackIDs, [rock.id])
    }

    func testDedicatedPlaybackGenresAreFixedOutsideRegularGenreFilter() async throws {
        let ambient = makeTrack(title: "Ambient", genre: "Ambient")
        let work = makeTrack(title: "Work", genre: "Focus; \(Track.workPlaybackGenre)")
        let hiRes = makeTrack(
            title: "Hi-Res",
            genre: "Classical",
            audioFormat: AudioFormat(
                codec: .flac,
                bitRate: nil,
                sampleRate: 96_000,
                bitDepth: 24,
                channels: 2
            )
        )
        let folder = URL(fileURLWithPath: "/tmp/work-genre-filter-library")
        let suiteName = "LibraryGenreFilterTests-\(UUID())"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.set(
            [Track.workPlaybackGenre, Track.hiResPlaybackGenre],
            forKey: "library.disabledGenreNames"
        )
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = LibraryStore(
            service: GenreFilterLibraryService(tracks: [ambient, work, hiRes]),
            fileImportService: GenreFilterFileImport(folders: [folder]),
            persistence: GenreFilterLibraryPersistence(),
            identityService: TrackIdentityService(
                registryURL: URL(fileURLWithPath: "/tmp/unused-work-genre-filter-identities.json")
            ),
            userDefaults: defaults
        )

        await store.restoreAndLoadIfNeeded()
        await store.waitForPendingGenreFilter()

        XCTAssertEqual(store.tracks.map(\.id), [ambient.id])
        XCTAssertEqual(store.albums.flatMap(\.trackIDs), [ambient.id])
        XCTAssertEqual(store.artists.flatMap(\.trackIDs), [ambient.id])
        XCTAssertEqual(
            store.fixedGenreOptions.map(\.id),
            [Track.workPlaybackGenre, Track.hiResPlaybackGenre]
        )
        XCTAssertTrue(store.isGenreAlwaysEnabled(Track.workPlaybackGenre))
        XCTAssertTrue(store.isGenreAlwaysEnabled(Track.hiResPlaybackGenre))
        XCTAssertTrue(store.isGenreEnabled(Track.workPlaybackGenre))
        XCTAssertTrue(store.isGenreEnabled(Track.hiResPlaybackGenre))
        XCTAssertEqual(store.selectableGenreOptions.map(\.id), ["Ambient"])
        XCTAssertFalse(store.availableGenreOptions.contains { $0.id == "Focus" })
        XCTAssertEqual(store.workLibraryCatalog.tracks.map(\.id), [work.id])
        XCTAssertEqual(store.hiResLibraryCatalog.tracks.map(\.id), [hiRes.id])
        XCTAssertEqual(store.tracks(for: .work).map(\.id), [work.id])
        XCTAssertEqual(store.tracks(for: .regular).map(\.id), [ambient.id])
        XCTAssertEqual(store.tracks(for: [UUID(), ambient.id]).map(\.id), [ambient.id])
        XCTAssertEqual(store.workLibraryCatalog.tracks(for: [UUID(), work.id]).map(\.id), [work.id])

        store.setEnabledGenres([])
        try await waitUntil { store.tracks.isEmpty }
        XCTAssertFalse(store.isGenreEnabled("Ambient"))
        XCTAssertTrue(store.isGenreEnabled(Track.workPlaybackGenre))
        XCTAssertTrue(store.isGenreEnabled(Track.hiResPlaybackGenre))
        XCTAssertEqual(store.workLibraryCatalog.tracks.map(\.id), [work.id])
        XCTAssertEqual(store.hiResLibraryCatalog.tracks.map(\.id), [hiRes.id])

        let preset = GenreDisplayPreset(
            id: UUID(),
            name: "空の旧プリセット",
            enabledGenreNames: [],
            includesUnassignedGenreSetting: true
        )
        store.applyGenreDisplayPreset(preset)
        try await waitUntil { store.tracks.isEmpty }
        XCTAssertTrue(store.isGenreDisplayPresetActive(preset))
        XCTAssertEqual(store.enabledGenreCount(for: preset), 0)
        XCTAssertEqual(store.workLibraryCatalog.tracks.map(\.id), [work.id])
    }

    private func waitUntil(
        timeout: Duration = .seconds(1),
        condition: @MainActor () -> Bool
    ) async throws {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while !condition() {
            guard clock.now < deadline else {
                XCTFail("Timed out waiting for the genre-filter result")
                return
            }
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    private func makeTrack(title: String, genre: String, audioFormat: AudioFormat? = nil) -> Track {
        Track(
            id: UUID(),
            title: title,
            artistName: "Artist \(title)",
            albumTitle: "Album \(title)",
            duration: 180,
            fileURL: URL(fileURLWithPath: "/tmp/\(title).m4a"),
            genre: genre,
            audioFormat: audioFormat
        )
    }

}

private struct GenreFilterLibraryService: MusicLibraryServicing {
    let tracks: [Track]

    func loadLibrary(from folderURL: URL, previousTracks: [Track]) async throws -> MusicLibrary {
        MusicLibrary.build(from: tracks)
    }
}

private final class GenreFilterFileImport: FileImportServicing, @unchecked Sendable {
    private var folders: [URL]

    init(folders: [URL]) {
        self.folders = folders
    }

    nonisolated func audioFiles(in folderURL: URL) async throws -> [URL] { [] }
    func saveLibraryFolders(_ urls: [URL]) throws { folders = urls }
    func restoreLibraryFolders() throws -> [URL] { folders }
}

private actor GenreFilterLibraryPersistence: LibraryPersistenceServicing {
    func load(for folderURL: URL) async throws -> MusicLibrary? { nil }
    func save(_ library: MusicLibrary, for folderURL: URL) async throws {}
}
