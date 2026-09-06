import Foundation
import ImageIO
import UniformTypeIdentifiers

nonisolated protocol WatchArtworkPreparing: Sendable {
    func prepareArtworkFile(identifier: String, trackID: UUID) async -> URL?
}

actor WatchArtworkPreparationService: WatchArtworkPreparing {
    private static let maximumPixelSize = 512
    private static let compressionQuality = 0.82
    private let artworkService: ArtworkServicing
    private let directoryURL: URL

    init(
        artworkService: ArtworkServicing = ArtworkService.shared,
        directoryURL: URL? = nil
    ) {
        self.artworkService = artworkService
        self.directoryURL = directoryURL ?? FileManager.default.temporaryDirectory
            .appending(path: "MyMusic-WatchArtwork", directoryHint: .isDirectory)
        if let staleFiles = try? FileManager.default.contentsOfDirectory(
            at: self.directoryURL,
            includingPropertiesForKeys: nil
        ) {
            for fileURL in staleFiles { try? FileManager.default.removeItem(at: fileURL) }
        }
    }

    func prepareArtworkFile(identifier: String, trackID: UUID) async -> URL? {
        guard !Task.isCancelled,
              let sourceData = await artworkService.artworkData(for: identifier),
              !Task.isCancelled,
              let source = CGImageSourceCreateWithData(sourceData as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let pixelWidth = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let pixelHeight = properties[kCGImagePropertyPixelHeight] as? NSNumber,
              let thumbnail = CGImageSourceCreateThumbnailAtIndex(
                source,
                0,
                [
                    kCGImageSourceCreateThumbnailFromImageAlways: true,
                    kCGImageSourceCreateThumbnailWithTransform: true,
                    kCGImageSourceThumbnailMaxPixelSize: min(
                        Self.maximumPixelSize,
                        max(pixelWidth.intValue, pixelHeight.intValue)
                    )
                ] as CFDictionary
              ) else { return nil }

        do {
            try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
            let fileURL = directoryURL.appending(path: "\(trackID.uuidString)-\(UUID().uuidString).jpg")
            guard let destination = CGImageDestinationCreateWithURL(
                fileURL as CFURL,
                UTType.jpeg.identifier as CFString,
                1,
                nil
            ) else { return nil }
            CGImageDestinationAddImage(
                destination,
                thumbnail,
                [kCGImageDestinationLossyCompressionQuality: Self.compressionQuality] as CFDictionary
            )
            guard CGImageDestinationFinalize(destination) else {
                try? FileManager.default.removeItem(at: fileURL)
                return nil
            }
            return fileURL
        } catch {
            return nil
        }
    }

    nonisolated static func removePreparedFile(_ fileURL: URL) async {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
