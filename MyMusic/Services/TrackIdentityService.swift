import AVFoundation
import CryptoKit
import Foundation

protocol TrackIdentityServicing: Sendable {
    func resolveID(for fileURL: URL, relativePath: String, duration: TimeInterval) async -> Track.ID
    func registerExistingTracks(_ tracks: [Track], in folderURL: URL) async
}

actor TrackIdentityService: TrackIdentityServicing {
    @MainActor static let shared = TrackIdentityService()

    private struct Record: Codable, Sendable {
        let id: Track.ID
        var relativePath: String
        var resourceIdentifier: String?
        var audioFingerprint: String?
    }

    private let registryURL: URL
    private var records: [Record]?

    init(registryURL: URL? = nil) {
        if let registryURL {
            self.registryURL = registryURL
        } else {
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.registryURL = applicationSupport.appending(path: "MyMusic/track-identities.json")
        }
    }

    func resolveID(for fileURL: URL, relativePath: String, duration: TimeInterval) async -> Track.ID {
        await loadIfNeeded()
        let resourceIdentifier = Self.resourceIdentifier(for: fileURL)

        if let index = records?.firstIndex(where: { $0.relativePath == relativePath }) {
            if records?[index].resourceIdentifier == nil { records?[index].resourceIdentifier = resourceIdentifier }
            if records?[index].audioFingerprint == nil {
                records?[index].audioFingerprint = await Self.audioFingerprint(for: fileURL, duration: duration)
            }
            persist()
            return records?[index].id ?? StableTrackIdentifier.id(for: relativePath)
        }

        if let resourceIdentifier,
           let index = records?.firstIndex(where: { $0.resourceIdentifier == resourceIdentifier }) {
            records?[index].relativePath = relativePath
            persist()
            return records?[index].id ?? StableTrackIdentifier.id(for: relativePath)
        }

        let fingerprint = await Self.audioFingerprint(for: fileURL, duration: duration)
        if let fingerprint,
           let index = records?.firstIndex(where: { $0.audioFingerprint == fingerprint }) {
            records?[index].relativePath = relativePath
            records?[index].resourceIdentifier = resourceIdentifier
            persist()
            return records?[index].id ?? StableTrackIdentifier.id(for: relativePath)
        }

        // Preserve the former path-derived UUID for a lossless first migration.
        let id = StableTrackIdentifier.id(for: relativePath)
        records?.append(Record(
            id: id,
            relativePath: relativePath,
            resourceIdentifier: resourceIdentifier,
            audioFingerprint: fingerprint
        ))
        persist()
        return id
    }

    func registerExistingTracks(_ tracks: [Track], in folderURL: URL) async {
        let hasAccess = folderURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { folderURL.stopAccessingSecurityScopedResource() } }
        guard hasAccess || FileManager.default.isReadableFile(atPath: folderURL.path) else { return }

        for track in tracks {
            if Task.isCancelled { return }
            guard let relativePath = track.relativePath else { continue }
            _ = await resolveID(for: track.fileURL, relativePath: relativePath, duration: track.duration)
        }
    }

    private func loadIfNeeded() async {
        guard records == nil else { return }
        guard let data = try? Data(contentsOf: registryURL),
              let decoded = try? JSONDecoder().decode([Record].self, from: data) else {
            records = []
            return
        }
        records = decoded
    }

    private func persist() {
        guard let records else { return }
        do {
            try FileManager.default.createDirectory(at: registryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(records).write(to: registryURL, options: .atomic)
        } catch {
            // Identity resolution remains usable in memory; persistence retries on the next resolution.
        }
    }

    private nonisolated static func resourceIdentifier(for url: URL) -> String? {
        guard let identifier = try? url.resourceValues(forKeys: [.fileResourceIdentifierKey]).fileResourceIdentifier else { return nil }
        if let data = identifier as? Data { return data.base64EncodedString() }
        return String(reflecting: identifier)
    }

    private static func audioFingerprint(for fileURL: URL, duration: TimeInterval) async -> String? {
        do {
            let asset = AVURLAsset(url: fileURL)
            guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return nil }
            let reader = try AVAssetReader(asset: asset)
            let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: 8_000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
                AVLinearPCMIsNonInterleaved: false
            ])
            guard reader.canAdd(output) else { return nil }
            reader.add(output)
            guard reader.startReading() else { return nil }

            var hasher = SHA256()
            var durationMilliseconds = Int64((duration.isFinite ? duration : 0) * 1_000).littleEndian
            withUnsafeBytes(of: &durationMilliseconds) { hasher.update(bufferPointer: $0) }

            let byteLimit = 2_000_000
            var byteCount = 0
            while byteCount < byteLimit, let sampleBuffer = output.copyNextSampleBuffer() {
                if Task.isCancelled { reader.cancelReading(); return nil }
                guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { continue }
                let available = min(CMBlockBufferGetDataLength(blockBuffer), byteLimit - byteCount)
                var data = Data(count: available)
                let status = data.withUnsafeMutableBytes { bytes in
                    CMBlockBufferCopyDataBytes(blockBuffer, atOffset: 0, dataLength: available, destination: bytes.baseAddress!)
                }
                guard status == kCMBlockBufferNoErr else { return nil }
                hasher.update(data: data)
                byteCount += available
            }
            guard byteCount > 0 else { return nil }
            return hasher.finalize().map { String(format: "%02x", $0) }.joined()
        } catch {
            return nil
        }
    }
}
