import AVFoundation
import Foundation

nonisolated protocol HighlightAnalysisServicing: Sendable {
    func cachedHighlights(for track: Track) async -> TrackHighlightData?
    func highlights(for track: Track) async -> TrackHighlightData
}

actor HighlightAnalysisService: HighlightAnalysisServicing {
    nonisolated static let highlightDuration: TimeInterval = 30

    private let repository: HighlightRepositoryServicing
    private let fileImportService: FileImportServicing
    private var inFlightTasks: [Track.ID: Task<TrackHighlightData, Never>] = [:]

    init(
        repository: HighlightRepositoryServicing = HighlightRepository(),
        fileImportService: FileImportServicing = FileImportService()
    ) {
        self.repository = repository
        self.fileImportService = fileImportService
    }

    func cachedHighlights(for track: Track) async -> TrackHighlightData? {
        guard let cached = await repository.data(for: track.id), cached.matches(track) else { return nil }
        return cached
    }

    func highlights(for track: Track) async -> TrackHighlightData {
        if let cached = await cachedHighlights(for: track) {
            return cached
        }
        if let inFlight = inFlightTasks[track.id] { return await inFlight.value }

        let libraryFolders = (try? fileImportService.restoreLibraryFolders()) ?? []
        let task = Task.detached(priority: .utility) {
            await Self.analyzeOrFallback(track: track, libraryFolders: libraryFolders)
        }
        inFlightTasks[track.id] = task
        let result = await task.value
        inFlightTasks[track.id] = nil
        if result.candidates.contains(where: { $0.score > 0 }) {
            await repository.save(result)
        }
        return result
    }

    private nonisolated static func analyzeOrFallback(
        track: Track,
        libraryFolders: [URL]
    ) async -> TrackHighlightData {
        do {
            let candidates = try await analyze(track: track, libraryFolders: libraryFolders)
            return TrackHighlightData(
                trackID: track.id,
                fileSize: track.fileSize,
                modificationDate: track.modificationDate,
                candidates: candidates
            )
        } catch {
            return fallbackData(for: track)
        }
    }

    private nonisolated static func analyze(
        track: Track,
        libraryFolders: [URL]
    ) async throws -> [HighlightCandidate] {
        try Task.checkCancellation()
        let accessURL = libraryFolders.first {
            track.fileURL.standardizedFileURL.pathComponents.starts(with: $0.standardizedFileURL.pathComponents)
        } ?? track.fileURL
        let hasSecurityAccess = accessURL.startAccessingSecurityScopedResource()
        defer { if hasSecurityAccess { accessURL.stopAccessingSecurityScopedResource() } }

        guard hasSecurityAccess || FileManager.default.isReadableFile(atPath: track.fileURL.path) else {
            throw HighlightAnalysisError.fileUnavailable
        }

        let asset = AVURLAsset(url: track.fileURL)
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw HighlightAnalysisError.noAudioTrack
        }
        let assetDuration = try await asset.load(.duration).seconds
        let duration = assetDuration.isFinite && assetDuration > 0 ? assetDuration : track.duration
        guard duration > 0 else { throw HighlightAnalysisError.invalidDuration }

        let reader = try AVAssetReader(asset: asset)
        let sampleRate = 12_000.0
        let output = AVAssetReaderTrackOutput(
            track: audioTrack,
            outputSettings: [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVLinearPCMIsFloatKey: true,
                AVLinearPCMBitDepthKey: 32,
                AVLinearPCMIsNonInterleaved: false,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1
            ]
        )
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw HighlightAnalysisError.readerConfigurationFailed }
        reader.add(output)
        guard reader.startReading() else {
            throw reader.error ?? HighlightAnalysisError.readerConfigurationFailed
        }

        var analyzer = AudioFeatureAnalyzer(sampleRate: sampleRate, windowDuration: 1)
        while reader.status == .reading {
            try Task.checkCancellation()
            guard let sampleBuffer = output.copyNextSampleBuffer() else { break }
            analyzer.consume(sampleBuffer)
        }
        if reader.status == .failed {
            throw reader.error ?? HighlightAnalysisError.readingFailed
        }

        let frames = analyzer.finish()
        guard !frames.isEmpty else { throw HighlightAnalysisError.noSamples }
        return rankedCandidates(from: frames, trackDuration: duration)
    }

    private nonisolated static func rankedCandidates(
        from frames: [AudioFeatureFrame],
        trackDuration: TimeInterval
    ) -> [HighlightCandidate] {
        let duration = min(highlightDuration, trackDuration)
        guard duration > 0 else {
            return HighlightCandidate.fallbackCandidates(
                trackDuration: trackDuration,
                highlightDuration: highlightDuration
            )
        }

        let rms = normalized(frames.map(\.rms))
        let pressure = normalized(frames.map(\.peak))
        let spread = normalized(frames.map(\.spectralSpread))
        let bass = normalized(frames.map(\.bassStrength))
        let density = normalized(frames.map(\.density))
        let changes = normalized(frames.indices.map { index in
            guard index > 0 else { return 0 }
            return abs(frames[index].rms - frames[index - 1].rms)
        })

        let frameScores = frames.indices.map { index -> Double in
            let position = (frames[index].startTime + 0.5) / max(trackDuration, 1)
            let positionWeight: Double
            switch position {
            case ..<0.15, 0.9...: positionWeight = 0.35
            case 0.35...0.75: positionWeight = 1
            default: positionWeight = 0.75
            }
            let featureScore =
                (rms[index] * 0.30) +
                (pressure[index] * 0.13) +
                (spread[index] * 0.15) +
                (bass[index] * 0.12) +
                (density[index] * 0.15) +
                (changes[index] * 0.15)
            return featureScore * positionWeight
        }

        let windowCount = max(Int(duration.rounded()), 1)
        let lastStart = max(frames.count - windowCount, 0)
        var scored: [(start: TimeInterval, score: Double)] = []
        for startIndex in 0...lastStart {
            let endIndex = min(startIndex + windowCount, frameScores.count)
            let slice = frameScores[startIndex..<endIndex]
            guard !slice.isEmpty else { continue }
            let average = slice.reduce(0, +) / Double(slice.count)
            let changePeak = changes[startIndex..<endIndex].max() ?? 0
            let maximumStart = max(trackDuration - duration, 0)
            scored.append((min(frames[startIndex].startTime, maximumStart), average + (changePeak * 0.08)))
        }

        var selected: [HighlightCandidate] = []
        let minimumSeparation = max(duration * 0.5, 8)
        for item in scored.sorted(by: { $0.score > $1.score }) {
            guard selected.allSatisfy({ abs($0.startTime - item.start) >= minimumSeparation }) else { continue }
            selected.append(HighlightCandidate(startTime: item.start, duration: duration, score: item.score))
            if selected.count == 5 { break }
        }

        if selected.count < 3 {
            let fallbacks = HighlightCandidate.fallbackCandidates(
                trackDuration: trackDuration,
                highlightDuration: highlightDuration
            )
            for candidate in fallbacks where selected.allSatisfy({ abs($0.startTime - candidate.startTime) >= 3 }) {
                selected.append(candidate)
                if selected.count == 5 { break }
            }
        }
        return selected.sorted { $0.score > $1.score }
    }

    private nonisolated static func normalized(_ values: [Double]) -> [Double] {
        guard let minimum = values.min(), let maximum = values.max(), maximum > minimum else {
            return Array(repeating: 0.5, count: values.count)
        }
        return values.map { ($0 - minimum) / (maximum - minimum) }
    }

    private nonisolated static func fallbackData(for track: Track) -> TrackHighlightData {
        TrackHighlightData(
            trackID: track.id,
            fileSize: track.fileSize,
            modificationDate: track.modificationDate,
            candidates: HighlightCandidate.fallbackCandidates(
                trackDuration: track.duration,
                highlightDuration: highlightDuration
            )
        )
    }

}

private nonisolated enum HighlightAnalysisError: Error {
    case fileUnavailable
    case noAudioTrack
    case invalidDuration
    case readerConfigurationFailed
    case readingFailed
    case noSamples
}

private nonisolated struct AudioFeatureFrame: Sendable {
    let startTime: TimeInterval
    let rms: Double
    let peak: Double
    let spectralSpread: Double
    let bassStrength: Double
    let density: Double
}

private nonisolated struct AudioFeatureAnalyzer {
    private let sampleRate: Double
    private let samplesPerWindow: Int
    private let lowPassAlpha: Double

    private var frames: [AudioFeatureFrame] = []
    private var sampleCount = 0
    private var totalSampleCount = 0
    private var sumSquares = 0.0
    private var lowPassSquares = 0.0
    private var differenceSquares = 0.0
    private var peak = 0.0
    private var denseSampleCount = 0
    private var previousSample = 0.0
    private var lowPassSample = 0.0

    nonisolated init(sampleRate: Double, windowDuration: TimeInterval) {
        self.sampleRate = sampleRate
        self.samplesPerWindow = max(Int(sampleRate * windowDuration), 1)
        self.lowPassAlpha = 1 - exp((-2 * Double.pi * 250) / sampleRate)
    }

    nonisolated mutating func consume(_ sampleBuffer: CMSampleBuffer) {
        guard let blockBuffer = CMSampleBufferGetDataBuffer(sampleBuffer) else { return }
        var lengthAtOffset = 0
        var totalLength = 0
        var rawPointer: UnsafeMutablePointer<Int8>?
        let status = CMBlockBufferGetDataPointer(
            blockBuffer,
            atOffset: 0,
            lengthAtOffsetOut: &lengthAtOffset,
            totalLengthOut: &totalLength,
            dataPointerOut: &rawPointer
        )
        guard status == kCMBlockBufferNoErr, let rawPointer else { return }

        let values = UnsafeRawPointer(rawPointer).assumingMemoryBound(to: Float.self)
        let valueCount = totalLength / MemoryLayout<Float>.size
        for index in 0..<valueCount { consume(Double(values[index])) }
    }

    nonisolated mutating func finish() -> [AudioFeatureFrame] {
        if sampleCount >= samplesPerWindow / 4 { appendFrame() }
        return frames
    }

    private nonisolated mutating func consume(_ sample: Double) {
        let finiteSample = sample.isFinite ? sample : 0
        let magnitude = abs(finiteSample)
        sumSquares += finiteSample * finiteSample
        peak = max(peak, magnitude)
        if magnitude >= 0.05 { denseSampleCount += 1 }

        lowPassSample += lowPassAlpha * (finiteSample - lowPassSample)
        lowPassSquares += lowPassSample * lowPassSample
        let difference = finiteSample - previousSample
        differenceSquares += difference * difference
        previousSample = finiteSample

        sampleCount += 1
        totalSampleCount += 1
        if sampleCount >= samplesPerWindow { appendFrame() }
    }

    private nonisolated mutating func appendFrame() {
        guard sampleCount > 0 else { return }
        let count = Double(sampleCount)
        let meanSquares = sumSquares / count
        let safeMeanSquares = max(meanSquares, .leastNonzeroMagnitude)
        frames.append(AudioFeatureFrame(
            startTime: Double(totalSampleCount - sampleCount) / sampleRate,
            rms: sqrt(meanSquares),
            peak: peak,
            spectralSpread: min(sqrt((differenceSquares / count) / safeMeanSquares), 4),
            bassStrength: min(sqrt((lowPassSquares / count) / safeMeanSquares), 1),
            density: Double(denseSampleCount) / count
        ))
        sampleCount = 0
        sumSquares = 0
        lowPassSquares = 0
        differenceSquares = 0
        peak = 0
        denseSampleCount = 0
    }
}
