import Foundation
import Observation

@MainActor
@Observable
final class LibraryStore {
    private(set) var tracks: [Track] = []
    private(set) var albums: [Album] = []
    private(set) var artists: [Artist] = []
    private(set) var genres: [Genre] = []
    private(set) var composers: [Composer] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var selectedFolderName: String?
    private(set) var isInitialLoadComplete = false

    var hasLibraryFolder: Bool { selectedFolderURL != nil }
    var scanProgress: Int { tracks.count }

    private var selectedFolderURL: URL?
    private var hasRestoredFolder = false
    private let service: MusicLibraryServicing
    private let fileImportService: FileImportServicing
    private let persistence: LibraryPersistenceServicing
    private let identityService: TrackIdentityServicing

    init(
        service: MusicLibraryServicing? = nil,
        fileImportService: FileImportServicing? = nil,
        persistence: LibraryPersistenceServicing? = nil,
        identityService: TrackIdentityServicing? = nil
    ) {
        let resolvedFileImportService = fileImportService ?? FileImportService()
        let resolvedIdentityService = identityService ?? TrackIdentityService.shared
        self.fileImportService = resolvedFileImportService
        self.identityService = resolvedIdentityService
        self.service = service ?? MusicLibraryService(
            fileImportService: resolvedFileImportService,
            metadataService: MetadataService(identityService: resolvedIdentityService),
            identityService: resolvedIdentityService
        )
        self.persistence = persistence ?? LibraryPersistenceService()
    }

    func restoreAndLoadIfNeeded() async {
        guard !hasRestoredFolder else { return }
        hasRestoredFolder = true
        defer { isInitialLoadComplete = true }
        do {
            guard let folderURL = try fileImportService.restoreLibraryFolder() else { return }
            selectedFolderURL = folderURL
            selectedFolderName = displayName(for: folderURL)
            if let cachedLibrary = try? await persistence.load(for: folderURL) {
                apply(cachedLibrary)
                Task { [identityService] in
                    await identityService.registerExistingTracks(cachedLibrary.tracks, in: folderURL)
                }
            } else {
                await scan(folderURL)
            }
        } catch {
            fileImportService.removeLibraryFolder()
            errorMessage = error.localizedDescription
        }
    }

    func selectFolder(_ folderURL: URL) async {
        errorMessage = nil
        do {
            try fileImportService.saveLibraryFolder(folderURL)
            selectedFolderURL = folderURL
            selectedFolderName = displayName(for: folderURL)
            await scan(folderURL)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func rescan() async {
        guard let selectedFolderURL else {
            errorMessage = "先に音楽フォルダを選択してください。"
            return
        }
        await scan(selectedFolderURL)
    }

    func dismissError() { errorMessage = nil }

    func tracks(for album: Album) -> [Track] {
        resolvedTracks(for: album.trackIDs).sorted(by: Self.albumTrackOrder)
    }

    func tracks(for artist: Artist) -> [Track] {
        let artistTracks = resolvedTracks(for: artist.trackIDs)
        let albumOrder = Dictionary(uniqueKeysWithValues: artist.albumIDs.enumerated().map { ($0.element, $0.offset) })
        var albumByTrackID: [Track.ID: Album.ID] = [:]
        for album in albums {
            for trackID in album.trackIDs where albumByTrackID[trackID] == nil {
                albumByTrackID[trackID] = album.id
            }
        }
        return artistTracks.sorted { lhs, rhs in
            let lhsAlbum = albumByTrackID[lhs.id].flatMap { albumOrder[$0] } ?? Int.max
            let rhsAlbum = albumByTrackID[rhs.id].flatMap { albumOrder[$0] } ?? Int.max
            if lhsAlbum != rhsAlbum { return lhsAlbum < rhsAlbum }
            return Self.albumTrackOrder(lhs, rhs)
        }
    }

    func albums(for artist: Artist) -> [Album] {
        let albumsByID = Dictionary(uniqueKeysWithValues: albums.map { ($0.id, $0) })
        return artist.albumIDs.compactMap { albumsByID[$0] }
    }

    func reportFolderImportFailure(_ error: Error) {
        let nsError = error as NSError
        guard nsError.code != NSUserCancelledError else { return }
        errorMessage = "フォルダを選択できませんでした: \(error.localizedDescription)"
    }

    private func scan(_ folderURL: URL) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            let library = try await service.loadLibrary(from: folderURL, previousTracks: tracks)
            apply(library)
            do {
                try await persistence.save(library, for: folderURL)
            } catch {
                errorMessage = "ライブラリ情報を保存できませんでした: \(error.localizedDescription)"
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func apply(_ library: MusicLibrary) {
        tracks = library.tracks
        albums = library.albums
        artists = library.artists
        genres = library.genres
        composers = library.composers
    }

    private func resolvedTracks(for trackIDs: [Track.ID]) -> [Track] {
        let tracksByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        var seen: Set<Track.ID> = []
        return trackIDs.compactMap { id in
            guard seen.insert(id).inserted else { return nil }
            return tracksByID[id]
        }
    }

    private static func albumTrackOrder(_ lhs: Track, _ rhs: Track) -> Bool {
        let lhsDisc = lhs.discNumber ?? 1
        let rhsDisc = rhs.discNumber ?? 1
        if lhsDisc != rhsDisc { return lhsDisc < rhsDisc }
        switch (lhs.trackNumber, rhs.trackNumber) {
        case let (lhsNumber?, rhsNumber?) where lhsNumber != rhsNumber:
            return lhsNumber < rhsNumber
        case (_?, nil):
            return true
        case (nil, _?):
            return false
        default:
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private func displayName(for url: URL) -> String {
        let parent = url.deletingLastPathComponent().lastPathComponent
        return parent.isEmpty ? url.lastPathComponent : "\(parent) / \(url.lastPathComponent)"
    }
}
