import Foundation

struct MusicLibrary: Codable, Sendable {
    let tracks: [Track]
    let albums: [Album]
    let artists: [Artist]
}

protocol MusicLibraryServicing: Sendable {
    func loadLibrary(from folderURL: URL, previousTracks: [Track]) async throws -> MusicLibrary
}

final class MusicLibraryService: MusicLibraryServicing, Sendable {
    private let fileImportService: FileImportServicing
    private let metadataService: MetadataServicing
    private let identityService: TrackIdentityServicing

    init(
        fileImportService: FileImportServicing = FileImportService(),
        metadataService: MetadataServicing = MetadataService(),
        identityService: TrackIdentityServicing = TrackIdentityService.shared
    ) {
        self.fileImportService = fileImportService
        self.metadataService = metadataService
        self.identityService = identityService
    }

    func loadLibrary(from folderURL: URL, previousTracks: [Track] = []) async throws -> MusicLibrary {
        let hasAccess = folderURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { folderURL.stopAccessingSecurityScopedResource() } }
        guard hasAccess || FileManager.default.isReadableFile(atPath: folderURL.path) else {
            throw FileImportServiceError.accessDenied
        }
        let files = try await fileImportService.audioFiles(in: folderURL)
        let filesByPath = files.map { fileURL in
            (fileURL, StableTrackIdentifier.relativePath(for: fileURL, relativeTo: folderURL))
        }
        await identityService.prepareForScan(relativePaths: Set(filesByPath.map(\.1)))
        do {
            let library = try await scanFiles(filesByPath, previousTracks: previousTracks, folderURL: folderURL)
            await identityService.finishScan()
            return library
        } catch {
            await identityService.finishScan()
            throw error
        }
    }

    private func scanFiles(
        _ filesByPath: [(URL, String)],
        previousTracks: [Track],
        folderURL: URL
    ) async throws -> MusicLibrary {
        let previousByPath = Dictionary(uniqueKeysWithValues: previousTracks.compactMap { track in
            track.relativePath.map { ($0, track) }
        })
        var tracks: [Track] = []
        tracks.reserveCapacity(filesByPath.count)

        // A corrupt, unsupported, or temporarily unavailable iCloud item does not abort the scan.
        for (file, relativePath) in filesByPath {
            try Task.checkCancellation()
            let values = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let fileSize = values?.fileSize.map(Int64.init)
            let modificationDate = values?.contentModificationDate
            if var existing = previousByPath[relativePath],
               isUnchanged(existing, fileSize: fileSize, modificationDate: modificationDate) {
                existing.fileURL = file
                existing.fileSize = fileSize
                existing.modificationDate = modificationDate
                tracks.append(existing)
                continue
            }
            if let track = try? await metadataService.metadata(for: file, relativeTo: folderURL) {
                tracks.append(track)
            }
        }
        tracks.sort {
            ($0.artistName.localizedStandardCompare($1.artistName) == .orderedAscending) ||
            ($0.artistName == $1.artistName && $0.title.localizedStandardCompare($1.title) == .orderedAscending)
        }
        return buildLibrary(from: tracks)
    }

    private func isUnchanged(_ track: Track, fileSize: Int64?, modificationDate: Date?) -> Bool {
        // Older cached indexes have no lightweight fields. Adopt them without re-reading audio metadata.
        guard let oldSize = track.fileSize, let oldDate = track.modificationDate else { return true }
        return oldSize == fileSize && abs(oldDate.timeIntervalSince(modificationDate ?? .distantPast)) < 0.001
    }

    private func buildLibrary(from tracks: [Track]) -> MusicLibrary {
        struct AlbumKey: Hashable { let title: String; let artist: String }
        let albumGroups = Dictionary(grouping: tracks) {
            AlbumKey(title: $0.albumTitle ?? "Unknown Album", artist: $0.artistName)
        }
        let albums = albumGroups.map { key, tracks in
            Album(
                id: UUID(),
                title: key.title,
                artistName: key.artist,
                artworkIdentifier: tracks.compactMap(\.artworkIdentifier).first,
                year: tracks.compactMap(\.year).first,
                trackIDs: tracks.map(\.id)
            )
        }.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }

        let albumsByArtist = Dictionary(grouping: albums, by: \.artistName)
        let artists = Dictionary(grouping: tracks, by: \.artistName).map { name, tracks in
            Artist(id: UUID(), name: name, albumIDs: albumsByArtist[name, default: []].map(\.id), trackIDs: tracks.map(\.id))
        }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

        return MusicLibrary(tracks: tracks, albums: albums, artists: artists)
    }
}
