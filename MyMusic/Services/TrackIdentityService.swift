import AVFoundation
import CryptoKit
import Foundation

protocol TrackIdentityServicing: Sendable {
    func prepareForScan(relativePaths: Set<String>) async
    func finishScan() async
    func resolveID(
        for fileURL: URL,
        relativePath: String,
        fileSize: Int64?,
        modificationDate: Date?,
        duration: TimeInterval
    ) async -> Track.ID
    func registerExistingTracks(_ tracks: [Track], in folderURL: URL) async
    func fingerprints(for trackIDs: [Track.ID]) async -> [Track.ID: String]
    func buildFingerprint(
        for track: Track,
        in folderURL: URL,
        allowDownloading: Bool
    ) async -> TrackFingerprintBuildResult
}

enum TrackFingerprintBuildResult: Sendable, Equatable {
    case built(String)
    case alreadyExists(String)
    case requiresDownload
    case unavailable
    case failed
}

actor TrackIdentityService: TrackIdentityServicing {
    @MainActor static let shared = TrackIdentityService()

    private struct Record: Codable, Sendable {
        let id: Track.ID
        var relativePath: String
        var resourceIdentifier: String?
        var audioFingerprint: String?
        var fileSize: Int64?
        var modificationDate: Date?
        var duration: TimeInterval?
    }

    private let registryURL: URL
    private var records: [Record]?
    private var pathIndex: [String: Int] = [:]
    private var idIndex: [Track.ID: Int] = [:]
    private var resourceIndex: [String: Int] = [:]
    private var missingRecordIndices: Set<Int> = []
    private var isScanActive = false
    private var isDirty = false

    init(registryURL: URL? = nil) {
        if let registryURL {
            self.registryURL = registryURL
        } else {
            let applicationSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            self.registryURL = applicationSupport.appending(path: "MyMusic/track-identities.json")
        }
    }

    func prepareForScan(relativePaths: Set<String>) async {
        await loadIfNeeded()
        missingRecordIndices = Set((records ?? []).indices.filter { !relativePaths.contains(records?[$0].relativePath ?? "") })
        isScanActive = true
    }

    func finishScan() async {
        isScanActive = false
        if isDirty { persistNow() }
    }

    func resolveID(
        for fileURL: URL,
        relativePath: String,
        fileSize: Int64?,
        modificationDate: Date?,
        duration: TimeInterval
    ) async -> Track.ID {
        await loadIfNeeded()
        let resourceIdentifier = Self.resourceIdentifier(for: fileURL)

        if let index = pathIndex[relativePath] {
            updateResourceIdentifier(resourceIdentifier, at: index)
            records?[index].fileSize = fileSize
            records?[index].modificationDate = modificationDate
            records?[index].duration = duration
            markDirty()
            return records?[index].id ?? StableTrackIdentifier.id(for: relativePath)
        }

        if let resourceIdentifier,
           let index = resourceIndex[resourceIdentifier] {
            updatePath(relativePath, at: index)
            records?[index].fileSize = fileSize
            records?[index].modificationDate = modificationDate
            records?[index].duration = duration
            missingRecordIndices.remove(index)
            markDirty()
            return records?[index].id ?? StableTrackIdentifier.id(for: relativePath)
        }

        let moveCandidates = missingRecordIndices.filter { index in
            let sizeMatches = fileSize != nil && records?[index].fileSize == fileSize
            let oldDuration = records?[index].duration ?? -1
            return sizeMatches && abs(oldDuration - duration) < 0.25
        }

        if moveCandidates.count == 1, let index = moveCandidates.first {
            updatePath(relativePath, at: index)
            updateResourceIdentifier(resourceIdentifier, at: index)
            records?[index].fileSize = fileSize
            records?[index].modificationDate = modificationDate
            records?[index].duration = duration
            missingRecordIndices.remove(index)
            markDirty()
            return records?[index].id ?? StableTrackIdentifier.id(for: relativePath)
        }

        var fingerprint: String?
        if !moveCandidates.isEmpty {
            fingerprint = await Self.audioFingerprint(for: fileURL, duration: duration)
            if let fingerprint,
               let index = moveCandidates.first(where: { records?[$0].audioFingerprint == fingerprint }) {
                updatePath(relativePath, at: index)
                updateResourceIdentifier(resourceIdentifier, at: index)
                records?[index].fileSize = fileSize
                records?[index].modificationDate = modificationDate
                records?[index].duration = duration
                missingRecordIndices.remove(index)
                markDirty()
                return records?[index].id ?? StableTrackIdentifier.id(for: relativePath)
            }
        }

        // Preserve the former path-derived UUID for a lossless first migration.
        let id = StableTrackIdentifier.id(for: relativePath)
        append(Record(
            id: id,
            relativePath: relativePath,
            resourceIdentifier: resourceIdentifier,
            audioFingerprint: fingerprint,
            fileSize: fileSize,
            modificationDate: modificationDate,
            duration: duration
        ))
        markDirty()
        return id
    }

    func registerExistingTracks(_ tracks: [Track], in folderURL: URL) async {
        let hasAccess = folderURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { folderURL.stopAccessingSecurityScopedResource() } }
        guard hasAccess || FileManager.default.isReadableFile(atPath: folderURL.path) else { return }

        for track in tracks {
            if Task.isCancelled { return }
            guard let relativePath = track.relativePath else { continue }
            let scopedPath = folderURL.standardizedFileURL.path.precomposedStringWithCanonicalMapping + "/" + relativePath
            await loadIfNeeded()
            let values = try? track.fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let fileSize = track.fileSize ?? values?.fileSize.map(Int64.init)
            let modificationDate = track.modificationDate ?? values?.contentModificationDate
            let resourceIdentifier = Self.resourceIdentifier(for: track.fileURL)
            if let index = idIndex[track.id] ?? pathIndex[scopedPath] ?? pathIndex[relativePath] {
                updatePath(scopedPath, at: index)
                updateResourceIdentifier(resourceIdentifier, at: index)
                records?[index].fileSize = fileSize
                records?[index].modificationDate = modificationDate
                records?[index].duration = track.duration
            } else {
                append(Record(
                    id: track.id,
                    relativePath: scopedPath,
                    resourceIdentifier: resourceIdentifier,
                    audioFingerprint: nil,
                    fileSize: fileSize,
                    modificationDate: modificationDate,
                    duration: track.duration
                ))
            }
        }
        isDirty = true
        persistNow()
    }

    func fingerprints(for trackIDs: [Track.ID]) async -> [Track.ID: String] {
        await loadIfNeeded()
        return Dictionary(uniqueKeysWithValues: trackIDs.compactMap { trackID -> (Track.ID, String)? in
            guard let index = idIndex[trackID],
                  let fingerprint = records?[index].audioFingerprint else { return nil }
            return (trackID, fingerprint)
        })
    }

    func buildFingerprint(
        for track: Track,
        in folderURL: URL,
        allowDownloading: Bool
    ) async -> TrackFingerprintBuildResult {
        await loadIfNeeded()
        if let index = idIndex[track.id], let fingerprint = records?[index].audioFingerprint {
            return .alreadyExists(fingerprint)
        }

        let hasAccess = folderURL.startAccessingSecurityScopedResource()
        defer { if hasAccess { folderURL.stopAccessingSecurityScopedResource() } }
        guard hasAccess || FileManager.default.isReadableFile(atPath: folderURL.path) else {
            return .unavailable
        }

        if !allowDownloading,
           let values = try? track.fileURL.resourceValues(forKeys: [
               .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey
           ]),
           values.isUbiquitousItem == true {
            let status = values.ubiquitousItemDownloadingStatus
            guard status == .current || status == .downloaded else {
                return .requiresDownload
            }
        }

        guard FileManager.default.fileExists(atPath: track.fileURL.path) else {
            return .unavailable
        }
        guard let fingerprint = await Self.audioFingerprint(
            for: track.fileURL,
            duration: track.duration
        ) else {
            return .failed
        }
        guard !Task.isCancelled else { return .failed }

        let index: Int
        if let existingIndex = idIndex[track.id] {
            index = existingIndex
        } else {
            let scopedPath = folderURL.standardizedFileURL.path.precomposedStringWithCanonicalMapping
                + "/" + (track.relativePath ?? track.fileURL.lastPathComponent)
            append(Record(
                id: track.id,
                relativePath: scopedPath,
                resourceIdentifier: Self.resourceIdentifier(for: track.fileURL),
                audioFingerprint: nil,
                fileSize: track.fileSize,
                modificationDate: track.modificationDate,
                duration: track.duration
            ))
            guard let appendedIndex = idIndex[track.id] else { return .failed }
            index = appendedIndex
        }
        records?[index].audioFingerprint = fingerprint
        markDirty()
        return .built(fingerprint)
    }

    private func loadIfNeeded() async {
        guard records == nil else { return }
        guard let data = try? Data(contentsOf: registryURL),
              let decoded = try? JSONDecoder().decode([Record].self, from: data) else {
            records = []
            return
        }
        records = decoded
        rebuildIndexes()
    }

    private func markDirty() {
        isDirty = true
        if !isScanActive { persistNow() }
    }

    private func persistNow() {
        guard let records else { return }
        do {
            try FileManager.default.createDirectory(at: registryURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(records).write(to: registryURL, options: .atomic)
            isDirty = false
        } catch {
            // Identity resolution remains usable in memory; persistence retries on the next resolution.
        }
    }

    private func rebuildIndexes() {
        pathIndex.removeAll(keepingCapacity: true)
        idIndex.removeAll(keepingCapacity: true)
        resourceIndex.removeAll(keepingCapacity: true)
        for (index, record) in (records ?? []).enumerated() {
            pathIndex[record.relativePath] = index
            idIndex[record.id] = index
            if let resourceIdentifier = record.resourceIdentifier {
                resourceIndex[resourceIdentifier] = index
            }
        }
    }

    private func updatePath(_ relativePath: String, at index: Int) {
        if let oldPath = records?[index].relativePath { pathIndex.removeValue(forKey: oldPath) }
        records?[index].relativePath = relativePath
        pathIndex[relativePath] = index
    }

    private func updateResourceIdentifier(_ resourceIdentifier: String?, at index: Int) {
        if let oldIdentifier = records?[index].resourceIdentifier {
            resourceIndex.removeValue(forKey: oldIdentifier)
        }
        records?[index].resourceIdentifier = resourceIdentifier
        if let resourceIdentifier {
            resourceIndex[resourceIdentifier] = index
        }
    }

    private func append(_ record: Record) {
        if records == nil { records = [] }
        records?.append(record)
        guard let index = records?.indices.last else { return }
        pathIndex[record.relativePath] = index
        idIndex[record.id] = index
        if let resourceIdentifier = record.resourceIdentifier {
            resourceIndex[resourceIdentifier] = index
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
