import Foundation

struct MusicLibrary: Codable, Sendable {
    let tracks: [Track]
    let albums: [Album]
    let artists: [Artist]
}

protocol MusicLibraryServicing: Sendable {
    func loadLibrary(from folderURL: URL) async throws -> MusicLibrary
}

final class MusicLibraryService: MusicLibraryServicing, Sendable {
    private let fileImportService: FileImportServicing
    private let metadataService: MetadataServicing

    init(
        fileImportService: FileImportServicing = FileImportService(),
        metadataService: MetadataServicing = MetadataService()
    ) {
        self.fileImportService = fileImportService
        self.metadataService = metadataService
    }

    func loadLibrary(from folderURL: URL) async throws -> MusicLibrary {
        let hasAccess = folderURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { folderURL.stopAccessingSecurityScopedResource() } }
        guard hasAccess || FileManager.default.isReadableFile(atPath: folderURL.path) else {
            throw FileImportServiceError.accessDenied
        }
        let files = try await fileImportService.audioFiles(in: folderURL)
        var tracks: [Track] = []
        tracks.reserveCapacity(files.count)

        // A corrupt, unsupported, or temporarily unavailable iCloud item does not abort the scan.
        for file in files {
            try Task.checkCancellation()
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
