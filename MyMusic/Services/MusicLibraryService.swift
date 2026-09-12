import Foundation

nonisolated struct MusicLibrary: Codable, Sendable {
    let tracks: [Track]
    let albums: [Album]
    let artists: [Artist]
    let genres: [Genre]
    let composers: [Composer]
}

protocol MusicLibraryServicing: Sendable {
    func loadLibrary(from folderURL: URL, previousTracks: [Track]) async throws -> MusicLibrary
    func loadLibraryReport(from folderURL: URL, previousTracks: [Track]) async throws -> MusicLibraryScanResult
    func loadLibraryReport(
        from folderURL: URL,
        previousTracks: [Track],
        depth: LibraryScanDepth
    ) async throws -> MusicLibraryScanResult
    func loadLibraryReport(
        from folderURL: URL,
        previousTracks: [Track],
        depth: LibraryScanDepth,
        progress: @escaping @Sendable (LibraryScanProgress) async -> Void
    ) async throws -> MusicLibraryScanResult
    func removeCompleteScanCheckpoint(for folderURL: URL) async
}

extension MusicLibraryServicing {
    func loadLibraryReport(from folderURL: URL, previousTracks: [Track]) async throws -> MusicLibraryScanResult {
        MusicLibraryScanResult(
            library: try await loadLibrary(from: folderURL, previousTracks: previousTracks),
            notices: []
        )
    }

    func loadLibraryReport(
        from folderURL: URL,
        previousTracks: [Track],
        depth: LibraryScanDepth
    ) async throws -> MusicLibraryScanResult {
        try await loadLibraryReport(from: folderURL, previousTracks: previousTracks)
    }

    func loadLibraryReport(
        from folderURL: URL,
        previousTracks: [Track],
        depth: LibraryScanDepth,
        progress: @escaping @Sendable (LibraryScanProgress) async -> Void
    ) async throws -> MusicLibraryScanResult {
        try await loadLibraryReport(from: folderURL, previousTracks: previousTracks, depth: depth)
    }

    func removeCompleteScanCheckpoint(for folderURL: URL) async {}
}

nonisolated enum LibraryScanDepth: Sendable, Equatable {
    case quick
    case complete
}

nonisolated struct LibraryScanProgress: Sendable, Equatable {
    let completedCount: Int
    let totalCount: Int

    var remainingCount: Int { max(0, totalCount - completedCount) }
}

nonisolated struct MusicLibraryScanResult: Sendable {
    let library: MusicLibrary
    let notices: [LibraryScanNotice]
}

nonisolated struct LibraryPresentationSnapshot: Sendable {
    let library: MusicLibrary
    let workLibraryCatalog: WorkLibraryCatalog
}

actor GenreLibraryFilterService {
    func filteredLibrary(
        from tracks: [Track],
        disabledGenreNames: Set<String>,
        unassignedGenreKey: String
    ) throws -> LibraryPresentationSnapshot {
        var visibleTracks: [Track] = []
        visibleTracks.reserveCapacity(tracks.count)

        for (index, track) in tracks.enumerated() {
            if index.isMultiple(of: 64) { try Task.checkCancellation() }
            let genreNames = Self.genreNames(in: track.genre)
            let filterKeys = genreNames.isEmpty ? Set([unassignedGenreKey]) : genreNames
            if disabledGenreNames.isDisjoint(with: filterKeys) {
                visibleTracks.append(track)
            }
        }

        try Task.checkCancellation()
        let library = MusicLibrary.build(from: visibleTracks)
        return LibraryPresentationSnapshot(
            library: library,
            workLibraryCatalog: WorkLibraryCatalogService.build(from: library)
        )
    }

    private static func genreNames(in value: String?) -> Set<String> {
        guard let value else { return [] }
        return Set(value
            .split(whereSeparator: { $0 == ";" || $0 == "\0" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty })
    }
}

nonisolated final class MusicLibraryService: MusicLibraryServicing, Sendable {
    private let fileImportService: FileImportServicing
    private let metadataService: MetadataServicing
    private let identityService: TrackIdentityServicing
    private let checkpointService: LibraryScanCheckpointServicing
    private let now: @Sendable () -> Date
    private static let checkpointLifetime: TimeInterval = 10 * 60

    init(
        fileImportService: FileImportServicing = FileImportService(),
        metadataService: MetadataServicing,
        identityService: TrackIdentityServicing,
        checkpointService: LibraryScanCheckpointServicing = LibraryScanCheckpointService(),
        now: @escaping @Sendable () -> Date = Date.init
    ) {
        self.fileImportService = fileImportService
        self.metadataService = metadataService
        self.identityService = identityService
        self.checkpointService = checkpointService
        self.now = now
    }

    @MainActor convenience init() {
        let identityService = TrackIdentityService.shared
        self.init(
            metadataService: MetadataService(identityService: identityService),
            identityService: identityService
        )
    }

    func loadLibrary(from folderURL: URL, previousTracks: [Track] = []) async throws -> MusicLibrary {
        try await loadLibraryReport(from: folderURL, previousTracks: previousTracks).library
    }

    func loadLibraryReport(from folderURL: URL, previousTracks: [Track] = []) async throws -> MusicLibraryScanResult {
        try await loadLibraryReport(from: folderURL, previousTracks: previousTracks, depth: .quick)
    }

    func loadLibraryReport(
        from folderURL: URL,
        previousTracks: [Track] = [],
        depth: LibraryScanDepth
    ) async throws -> MusicLibraryScanResult {
        try await loadLibraryReport(
            from: folderURL,
            previousTracks: previousTracks,
            depth: depth,
            progress: { _ in }
        )
    }

    func loadLibraryReport(
        from folderURL: URL,
        previousTracks: [Track] = [],
        depth: LibraryScanDepth,
        progress: @escaping @Sendable (LibraryScanProgress) async -> Void
    ) async throws -> MusicLibraryScanResult {
        let hasAccess = folderURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { folderURL.stopAccessingSecurityScopedResource() } }
        guard hasAccess || FileManager.default.isReadableFile(atPath: folderURL.path) else {
            throw FileImportServiceError.accessDenied
        }
        let fileScan = try await fileImportService.audioFileScan(in: folderURL)
        let scanStartedAt = now()
        let filesByPath = fileScan.files.map { fileURL in
            (fileURL, StableTrackIdentifier.relativePath(for: fileURL, relativeTo: folderURL))
        }
        await progress(LibraryScanProgress(completedCount: 0, totalCount: filesByPath.count))
        let checkpointEntries: [String: LibraryScanCheckpointEntry]
        if depth == .complete {
            checkpointEntries = await checkpointService.recentEntries(
                for: folderURL,
                since: now().addingTimeInterval(-Self.checkpointLifetime)
            )
        } else {
            checkpointEntries = [:]
        }
        let identityPrefix = folderURL.standardizedFileURL.path.precomposedStringWithCanonicalMapping
        await identityService.prepareForScan(relativePaths: Set(filesByPath.map { identityPrefix + "/" + $0.1 }))
        do {
            let result = try await scanFiles(
                filesByPath, previousTracks: previousTracks, folderURL: folderURL,
                identityPrefix: identityPrefix, scanStartedAt: scanStartedAt, depth: depth,
                checkpointEntries: checkpointEntries, progress: progress
            )
            await identityService.finishScan()
            return MusicLibraryScanResult(
                library: result.library,
                notices: fileScan.notices + result.notices
            )
        } catch {
            await identityService.abortScan()
            throw error
        }
    }

    func removeCompleteScanCheckpoint(for folderURL: URL) async {
        await checkpointService.remove(for: folderURL)
    }

    private func scanFiles(
        _ filesByPath: [(URL, String)],
        previousTracks: [Track],
        folderURL: URL,
        identityPrefix: String,
        scanStartedAt: Date,
        depth: LibraryScanDepth,
        checkpointEntries: [String: LibraryScanCheckpointEntry],
        progress: @escaping @Sendable (LibraryScanProgress) async -> Void
    ) async throws -> MusicLibraryScanResult {
        let previousByPath = Dictionary(uniqueKeysWithValues: previousTracks.compactMap { track in
            track.relativePath.map { ($0, track) }
        })
        let previousByID = Dictionary(uniqueKeysWithValues: previousTracks.map { ($0.id, $0) })
        var tracks: [Track] = []
        var notices: [LibraryScanNotice] = []
        var updatedCheckpointEntries = checkpointEntries
        var unsavedCheckpointCount = 0
        tracks.reserveCapacity(filesByPath.count)

        // A corrupt, unsupported, or temporarily unavailable iCloud item does not abort the scan.
        for (index, entry) in filesByPath.enumerated() {
            let (file, relativePath) = entry
            try Task.checkCancellation()
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let fileSize = values?.fileSize.map(Int64.init)
            let modificationDate = values?.contentModificationDate
            if depth == .complete,
               let checkpoint = updatedCheckpointEntries[relativePath],
               isSameSource(checkpoint.track, fileSize: fileSize, modificationDate: modificationDate) {
                let identity = await identityService.resolveIdentity(
                    for: file,
                    relativePath: identityPrefix + "/" + relativePath,
                    fileSize: fileSize,
                    modificationDate: modificationDate,
                    duration: checkpoint.track.duration,
                    discoveredAt: checkpoint.track.firstSeenAt ?? scanStartedAt
                )
                if identity.id == checkpoint.track.id {
                    var resumedTrack = checkpoint.track
                    resumedTrack.fileURL = file
                    resumedTrack.fileSize = fileSize
                    resumedTrack.modificationDate = modificationDate
                    tracks.append(resumedTrack)
                    await progress(LibraryScanProgress(
                        completedCount: index + 1,
                        totalCount: filesByPath.count
                    ))
                    continue
                }
            }
            if depth == .quick, var existing = previousByPath[relativePath],
               isUnchanged(existing, fileSize: fileSize, modificationDate: modificationDate) {
                existing.fileURL = file
                existing.fileSize = fileSize
                existing.modificationDate = modificationDate
                tracks.append(existing)
                await progress(LibraryScanProgress(
                    completedCount: index + 1,
                    totalCount: filesByPath.count
                ))
                continue
            }
            do {
                var track = try await metadataService.metadata(
                    for: file, relativeTo: folderURL, discoveredAt: scanStartedAt
                )
                if let previous = previousByID[track.id] {
                    track.firstSeenAt = previous.firstSeenAt
                }
                tracks.append(track)
                if depth == .complete {
                    updatedCheckpointEntries[relativePath] = LibraryScanCheckpointEntry(
                        track: track,
                        refreshedAt: now()
                    )
                    unsavedCheckpointCount += 1
                    if unsavedCheckpointCount >= 10 {
                        await checkpointService.save(updatedCheckpointEntries, for: folderURL)
                        unsavedCheckpointCount = 0
                    }
                }
            } catch {
                let nsError = error as NSError
                notices.append(.metadataReadFailed(
                    relativePath: relativePath,
                    detail: "\(nsError.localizedDescription) [\(nsError.domain):\(nsError.code)]"
                ))
            }
            await progress(LibraryScanProgress(
                completedCount: index + 1,
                totalCount: filesByPath.count
            ))
        }
        if depth == .complete, unsavedCheckpointCount > 0 {
            await checkpointService.save(updatedCheckpointEntries, for: folderURL)
        }
        tracks.sort {
            ($0.artistName.localizedStandardCompare($1.artistName) == .orderedAscending) ||
            ($0.artistName == $1.artistName && $0.title.localizedStandardCompare($1.title) == .orderedAscending)
        }
        return MusicLibraryScanResult(library: MusicLibrary.build(from: tracks), notices: notices)
    }

    private func isUnchanged(_ track: Track, fileSize: Int64?, modificationDate: Date?) -> Bool {
        // Legacy cache entries need one metadata read to acquire Album Artist.
        guard track.metadataRevision == MetadataService.currentMetadataRevision else { return false }
        // Current-revision entries can still lack lightweight fields when resource values are unavailable.
        guard let oldSize = track.fileSize, let oldDate = track.modificationDate else { return true }
        return oldSize == fileSize && abs(oldDate.timeIntervalSince(modificationDate ?? .distantPast)) < 0.001
    }

    private func isSameSource(_ track: Track, fileSize: Int64?, modificationDate: Date?) -> Bool {
        guard let oldSize = track.fileSize,
              let oldDate = track.modificationDate,
              let fileSize,
              let modificationDate else { return false }
        return oldSize == fileSize && abs(oldDate.timeIntervalSince(modificationDate)) < 0.001
    }

}

extension MusicLibrary {
    nonisolated static func build(from tracks: [Track]) -> MusicLibrary {
        struct AlbumKey: Hashable { let title: String; let artist: String }
        let albumGroups = Dictionary(grouping: tracks) {
            AlbumKey(
                title: $0.albumTitle ?? "Unknown Album",
                artist: $0.albumArtistName ?? $0.artistName
            )
        }
        let albums = albumGroups.map { key, tracks in
            Album(
                id: StableLibraryIdentifier.albumID(title: key.title, artistName: key.artist),
                title: key.title,
                artistName: key.artist,
                artworkIdentifier: tracks.compactMap(\.artworkIdentifier).first,
                year: tracks.compactMap(\.year).first,
                trackIDs: tracks.map(\.id),
                legacyAlbumIDs: Set(tracks.map {
                    StableLibraryIdentifier.albumID(title: key.title, artistName: $0.artistName)
                })
            )
        }.sorted {
            let titleOrder = $0.title.localizedStandardCompare($1.title)
            if titleOrder != .orderedSame { return titleOrder == .orderedAscending }
            return $0.artistName.localizedStandardCompare($1.artistName) == .orderedAscending
        }

        let albumByTrackID = Dictionary(
            albums.flatMap { album in album.trackIDs.map { ($0, album) } },
            uniquingKeysWith: { first, _ in first }
        )
        var artists: [Artist] = Dictionary(grouping: tracks, by: \.artistName).map { name, tracks in
            var seenAlbumIDs: Set<Album.ID> = []
            var artistAlbums: [Album] = []
            for track in tracks {
                guard let album = albumByTrackID[track.id],
                      seenAlbumIDs.insert(album.id).inserted else { continue }
                artistAlbums.append(album)
            }
            artistAlbums.sort {
                $0.title.localizedStandardCompare($1.title) == .orderedAscending
            }
            return Artist(
                id: StableLibraryIdentifier.artistID(name: name),
                name: name,
                albumIDs: artistAlbums.map(\.id),
                trackIDs: tracks.map(\.id)
            )
        }
        artists.sort { lhs, rhs in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        let genres = groupedTracks(tracks, value: \.genre).map { name, tracks in
            Genre(id: UUID(), name: name, trackIDs: tracks.map(\.id))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        let composers = groupedTracks(tracks, value: \.composer).map { name, tracks in
            Composer(id: UUID(), name: name, trackIDs: tracks.map(\.id))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        return MusicLibrary(
            tracks: tracks,
            albums: albums,
            artists: artists,
            genres: genres,
            composers: composers
        )
    }

    private nonisolated static func groupedTracks(
        _ tracks: [Track],
        value: KeyPath<Track, String?>
    ) -> [String: [Track]] {
        var groups: [String: [Track]] = [:]

        for track in tracks {
            // A file can expose the same value through multiple metadata items.
            // Count a track only once per exact, trimmed Genre/Composer spelling.
            for name in Set(metadataComponents(from: track[keyPath: value])) {
                groups[name, default: []].append(track)
            }
        }

        return groups
    }

    private nonisolated static func metadataComponents(from value: String?) -> [String] {
        guard let value else { return [] }
        return value
            .split(whereSeparator: { $0 == ";" || $0 == "\0" })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
