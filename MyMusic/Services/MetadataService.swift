import AVFoundation
import Foundation

protocol MetadataServicing: Sendable {
    func metadata(for fileURL: URL, relativeTo libraryFolder: URL) async throws -> Track
}

final class MetadataService: MetadataServicing, Sendable {
    private let artworkService: ArtworkServicing
    private let identityService: TrackIdentityServicing

    init(
        artworkService: ArtworkServicing = ArtworkService.shared,
        identityService: TrackIdentityServicing = TrackIdentityService.shared
    ) {
        self.artworkService = artworkService
        self.identityService = identityService
    }

    func metadata(for fileURL: URL, relativeTo libraryFolder: URL) async throws -> Track {
        let asset = AVURLAsset(url: fileURL)
        let duration = try await asset.load(.duration).seconds
        let metadata = try await asset.load(.commonMetadata)

        let title = await stringValue(for: .commonIdentifierTitle, in: metadata)
        let artist = await stringValue(for: .commonIdentifierArtist, in: metadata)
        let album = await stringValue(for: .commonIdentifierAlbumName, in: metadata)
        let genre = await stringValue(for: .commonIdentifierType, in: metadata)

        let pathFallback = folderFallback(for: fileURL, relativeTo: libraryFolder)
        let relativePath = StableTrackIdentifier.relativePath(for: fileURL, relativeTo: libraryFolder)
        let trackID = await identityService.resolveID(
            for: fileURL,
            relativePath: relativePath,
            duration: duration.isFinite ? duration : 0
        )
        let artworkIdentifier = await cacheArtwork(in: metadata, trackID: trackID)
        return Track(
            id: trackID,
            title: title ?? fileURL.deletingPathExtension().lastPathComponent,
            artistName: artist ?? pathFallback.artist ?? "Unknown Artist",
            albumTitle: album ?? pathFallback.album ?? "Unknown Album",
            duration: duration.isFinite ? duration : 0,
            fileURL: fileURL,
            relativePath: relativePath,
            artworkIdentifier: artworkIdentifier,
            trackNumber: await integerValue(for: .iTunesMetadataTrackNumber, in: metadata),
            discNumber: await integerValue(for: .iTunesMetadataDiscNumber, in: metadata),
            year: await yearValue(in: metadata),
            genre: genre,
            audioFormat: format(for: fileURL)
        )
    }

    private func cacheArtwork(in items: [AVMetadataItem], trackID: Track.ID) async -> String? {
        guard let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: .commonIdentifierArtwork).first,
              let data = try? await item.load(.dataValue),
              !data.isEmpty else { return nil }
        return try? await artworkService.storeArtwork(data, identifier: trackID.uuidString)
    }

    private func stringValue(for identifier: AVMetadataIdentifier, in items: [AVMetadataItem]) async -> String? {
        guard let item = AVMetadataItem.metadataItems(from: items, filteredByIdentifier: identifier).first else { return nil }
        return try? await item.load(.stringValue)
    }

    private func integerValue(for identifier: AVMetadataIdentifier, in items: [AVMetadataItem]) async -> Int? {
        guard let value = await stringValue(for: identifier, in: items) else { return nil }
        return Int(value.split(separator: "/").first ?? "")
    }

    private func yearValue(in items: [AVMetadataItem]) async -> Int? {
        guard let value = await stringValue(for: .commonIdentifierCreationDate, in: items) else { return nil }
        return Int(value.prefix(4))
    }

    private func folderFallback(for fileURL: URL, relativeTo root: URL) -> (artist: String?, album: String?) {
        let rootParts = root.standardizedFileURL.pathComponents
        let fileParts = fileURL.standardizedFileURL.deletingLastPathComponent().pathComponents
        guard fileParts.starts(with: rootParts) else { return (nil, nil) }
        let relative = Array(fileParts.dropFirst(rootParts.count))
        return (relative.first, relative.count > 1 ? relative.last : nil)
    }

    private func format(for url: URL) -> AudioFormat? {
        let codec: AudioFormat.Codec
        switch url.pathExtension.lowercased() {
        case "flac": codec = .flac
        case "mp3": codec = .mp3
        case "wav": codec = .wav
        case "aiff", "aif": codec = .aiff
        case "aac": codec = .aac
        case "m4a": codec = .aac // The container may contain ALAC; exact stream inspection is future work.
        default: return nil
        }
        return AudioFormat(codec: codec, bitRate: nil, sampleRate: nil, bitDepth: nil, channels: nil)
    }
}
