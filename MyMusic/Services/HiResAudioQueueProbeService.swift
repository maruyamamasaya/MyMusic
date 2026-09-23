import AVFoundation
import AudioToolbox
import Foundation
import Synchronization

struct HiResAudioQueueProbeSnapshot: Equatable, Sendable {
    var fileName: String
    var sourceSampleRate: Double
    var sessionSampleRate: Double?
    var queueHardwareSampleRate: Double?
    var outputName: String
    var outputPortType: String
}

enum HiResAudioQueueProbeEvent: Sendable {
    case started(HiResAudioQueueProbeSnapshot)
    case updated(HiResAudioQueueProbeSnapshot)
    case prepared(HiResAudioQueueProbeSnapshot)
    case progress(TimeInterval)
    case reachedEnd
    case failed(String)
}

enum HiResAudioQueueProbeError: LocalizedError {
    case audioFile(OSStatus)
    case audioQueue(OSStatus)
    case invalidFormat
    case emptyFile

    var errorDescription: String? {
        switch self {
        case let .audioFile(status):
            "Audio file error (\(status))."
        case let .audioQueue(status):
            "Audio Queue error (\(status))."
        case .invalidFormat:
            "This file does not contain a playable audio format."
        case .emptyFile:
            "This audio file contains no playable packets."
        }
    }
}

@MainActor
protocol HiResAudioQueueProbeServicing: AnyObject {
    var eventHandler: ((HiResAudioQueueProbeEvent) -> Void)? { get set }
    func play(url: URL) async throws
    func prepare(sampleRate: Double) async throws
    func pause() throws
    func resume() throws
    func seek(to time: TimeInterval) throws
    func stop()
}

@MainActor
final class HiResAudioQueueProbeService: HiResAudioQueueProbeServicing {
    var eventHandler: ((HiResAudioQueueProbeEvent) -> Void)?

    private let fileImportService: FileImportServicing
    private var context: HiResAudioQueueProbeContext?
    private var accessedURL: URL?
    private var isAccessingSecurityScope = false
    private var refreshTask: Task<Void, Never>?

    init(fileImportService: FileImportServicing? = nil) {
        self.fileImportService = fileImportService ?? FileImportService()
    }

    isolated deinit {
        refreshTask?.cancel()
        disposePlayback()
        endFileAccess()
    }

    func play(url: URL) async throws {
        stop()
        try beginFileAccess(url)

        do {
            var audioFile: AudioFileID?
            try checkAudioFile(AudioFileOpenURL(url as CFURL, .readPermission, 0, &audioFile))
            guard let audioFile else { throw HiResAudioQueueProbeError.invalidFormat }

            var format = AudioStreamBasicDescription()
            var formatSize = UInt32(MemoryLayout<AudioStreamBasicDescription>.size)
            do {
                try checkAudioFile(AudioFileGetProperty(
                    audioFile,
                    kAudioFilePropertyDataFormat,
                    &formatSize,
                    &format
                ))
            } catch {
                AudioFileClose(audioFile)
                throw error
            }
            guard format.mSampleRate.isFinite, format.mSampleRate > 0 else {
                AudioFileClose(audioFile)
                throw HiResAudioQueueProbeError.invalidFormat
            }

            do {
                try await configureAudioSession(sourceSampleRate: format.mSampleRate)
            } catch {
                AudioFileClose(audioFile)
                throw error
            }
            try Task.checkCancellation()

            let playbackContext = HiResAudioQueueProbeContext(
                audioFile: audioFile,
                format: format,
                eventHandler: { [weak self] event in
                    Task { @MainActor [weak self] in self?.eventHandler?(event) }
                }
            )
            var queue: AudioQueueRef?
            let queueStatus = AudioQueueNewOutput(
                &format,
                hiResAudioQueueOutputCallback,
                Unmanaged.passUnretained(playbackContext).toOpaque(),
                nil,
                nil,
                0,
                &queue
            )
            guard queueStatus == noErr, let queue else {
                AudioFileClose(audioFile)
                throw HiResAudioQueueProbeError.audioQueue(queueStatus)
            }
            playbackContext.queue = queue

            do {
                try checkAudioQueue(AudioQueueAddPropertyListener(
                    queue,
                    kAudioQueueProperty_IsRunning,
                    hiResAudioQueueRunningPropertyCallback,
                    Unmanaged.passUnretained(playbackContext).toOpaque()
                ))
                try copyMagicCookie(from: audioFile, to: queue)
                let packetSize = try maximumPacketSize(for: audioFile)
                let packetsPerBuffer = Self.packetsPerBuffer(
                    format: format,
                    maximumPacketSize: packetSize
                )
                playbackContext.packetsPerBuffer = packetsPerBuffer
                let requestedBufferByteSize = UInt64(packetSize) * UInt64(packetsPerBuffer)
                let bufferByteSize = UInt32(min(
                    max(requestedBufferByteSize, 32_768),
                    UInt64(UInt32.max)
                ))

                var enqueuedBufferCount = 0
                for _ in 0..<3 {
                    var buffer: AudioQueueBufferRef?
                    try checkAudioQueue(AudioQueueAllocateBufferWithPacketDescriptions(
                        queue,
                        bufferByteSize,
                        packetsPerBuffer,
                        &buffer
                    ))
                    guard let buffer else { continue }
                    playbackContext.buffers.append(buffer)
                    if playbackContext.fill(buffer) { enqueuedBufferCount += 1 }
                }
                guard enqueuedBufferCount > 0 else {
                    throw HiResAudioQueueProbeError.emptyFile
                }

                var preparedFrames: UInt32 = 0
                try checkAudioQueue(AudioQueuePrime(queue, 0, &preparedFrames))
                try checkAudioQueue(AudioQueueStart(queue, nil))
                playbackContext.hasStarted.store(true, ordering: .releasing)
                if playbackContext.reachedEOF.load(ordering: .acquiring) {
                    AudioQueueStop(queue, false)
                }
                context = playbackContext
                publishSnapshot(fileName: url.lastPathComponent, sourceSampleRate: format.mSampleRate, started: true)
                schedulePlaybackUpdates(fileName: url.lastPathComponent, sourceSampleRate: format.mSampleRate)
            } catch {
                AudioQueueDispose(queue, true)
                AudioFileClose(audioFile)
                throw error
            }
        } catch {
            endFileAccess()
            throw error
        }
    }

    func prepare(sampleRate: Double) async throws {
        stop()
        let hardwareRate = try await configureAudioSession(sourceSampleRate: sampleRate)
        let session = AVAudioSession.sharedInstance()
        let output = session.currentRoute.outputs.first
        eventHandler?(.prepared(HiResAudioQueueProbeSnapshot(
            fileName: "内蔵無音PCM",
            sourceSampleRate: sampleRate,
            sessionSampleRate: session.sampleRate > 0 ? session.sampleRate : nil,
            queueHardwareSampleRate: hardwareRate,
            outputName: output?.portName ?? "Unknown",
            outputPortType: output?.portType.rawValue ?? "Unknown"
        )))
    }

    func pause() throws {
        guard let queue = context?.queue else { return }
        try checkAudioQueue(AudioQueuePause(queue))
    }

    func resume() throws {
        guard let queue = context?.queue else { return }
        try checkAudioQueue(AudioQueueStart(queue, nil))
    }

    func seek(to time: TimeInterval) throws {
        guard let context, let queue = context.queue else { return }
        let target = max(time.isFinite ? time : 0, 0)
        context.reachedEOF.store(false, ordering: .releasing)
        context.didReportEnd.store(false, ordering: .releasing)
        context.hasStarted.store(false, ordering: .releasing)
        try checkAudioQueue(AudioQueueStop(queue, true))
        try checkAudioQueue(AudioQueueReset(queue))
        context.currentPacket = context.packetOffset(for: target)
        context.playbackOffset = target

        var enqueuedBufferCount = 0
        for buffer in context.buffers where context.fill(buffer) {
            enqueuedBufferCount += 1
        }
        guard enqueuedBufferCount > 0 else {
            eventHandler?(.reachedEnd)
            return
        }
        var preparedFrames: UInt32 = 0
        try checkAudioQueue(AudioQueuePrime(queue, 0, &preparedFrames))
        try checkAudioQueue(AudioQueueStart(queue, nil))
        context.hasStarted.store(true, ordering: .releasing)
        if context.reachedEOF.load(ordering: .acquiring) {
            AudioQueueStop(queue, false)
        }
        eventHandler?(.progress(target))
    }

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        disposePlayback()
        endFileAccess()
        // Manual mode intentionally leaves the shared session inactive until
        // the user selects the next file, giving the USB stream time to close.
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    @discardableResult
    private func configureAudioSession(sourceSampleRate: Double) async throws -> Double? {
        guard sourceSampleRate.isFinite,
              (8_000...768_000).contains(sourceSampleRate) else {
            throw HiResAudioQueueProbeError.invalidFormat
        }
        let session = AVAudioSession.sharedInstance()
        // A paused AVAudioEngine can keep the previous hardware rate alive. The
        // diagnostic stops normal playback before reaching here, so failure to
        // deactivate is actionable and must not be hidden.
        try session.setCategory(.playback, mode: .default)
        var hardwareRate: Double?
        for attempt in 0..<2 {
            try session.setActive(false)
            // The first USB stream after a route opens is unreliable on the
            // tested DAC. Always open two generated silent streams before the
            // real queue, even if the first queue reports the requested rate.
            try await Task.sleep(for: .milliseconds(attempt == 0 ? 300 : 160))
            try Task.checkCancellation()
            try session.setPreferredSampleRate(sourceSampleRate)
            try session.setActive(true)
            hardwareRate = try await primeSilentPCM(sampleRate: sourceSampleRate)
        }
        return hardwareRate
    }

    private func primeSilentPCM(sampleRate: Double) async throws -> Double? {
        let channelCount: UInt32 = 2
        let bytesPerSample: UInt32 = 2
        let bytesPerFrame = channelCount * bytesPerSample
        var format = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: bytesPerFrame,
            mFramesPerPacket: 1,
            mBytesPerFrame: bytesPerFrame,
            mChannelsPerFrame: channelCount,
            mBitsPerChannel: 16,
            mReserved: 0
        )
        var queue: AudioQueueRef?
        try checkAudioQueue(AudioQueueNewOutput(
            &format,
            hiResSilentQueueOutputCallback,
            nil,
            nil,
            nil,
            0,
            &queue
        ))
        guard let queue else { throw HiResAudioQueueProbeError.invalidFormat }
        defer {
            AudioQueueStop(queue, true)
            AudioQueueDispose(queue, true)
        }

        let frameCount = max(UInt32(sampleRate * 0.12), 1)
        let byteCount = frameCount * bytesPerFrame
        var buffer: AudioQueueBufferRef?
        try checkAudioQueue(AudioQueueAllocateBuffer(queue, byteCount, &buffer))
        guard let buffer else { throw HiResAudioQueueProbeError.emptyFile }
        memset(buffer.pointee.mAudioData, 0, Int(byteCount))
        buffer.pointee.mAudioDataByteSize = byteCount
        try checkAudioQueue(AudioQueueEnqueueBuffer(queue, buffer, 0, nil))
        var preparedFrames: UInt32 = 0
        try checkAudioQueue(AudioQueuePrime(queue, 0, &preparedFrames))
        try checkAudioQueue(AudioQueueStart(queue, nil))
        try await Task.sleep(for: .milliseconds(90))
        try Task.checkCancellation()

        var hardwareRate: Float64 = 0
        var propertySize = UInt32(MemoryLayout<Float64>.size)
        let status = AudioQueueGetProperty(
            queue,
            kAudioQueueDeviceProperty_SampleRate,
            &hardwareRate,
            &propertySize
        )
        return status == noErr && hardwareRate > 0 ? hardwareRate : nil
    }

    private func publishSnapshot(fileName: String, sourceSampleRate: Double, started: Bool) {
        let session = AVAudioSession.sharedInstance()
        let output = session.currentRoute.outputs.first
        var hardwareRate: Float64 = 0
        var hardwareRateSize = UInt32(MemoryLayout<Float64>.size)
        if let queue = context?.queue {
            let status = AudioQueueGetProperty(
                queue,
                kAudioQueueDeviceProperty_SampleRate,
                &hardwareRate,
                &hardwareRateSize
            )
            if status != noErr { hardwareRate = 0 }
        }
        let snapshot = HiResAudioQueueProbeSnapshot(
            fileName: fileName,
            sourceSampleRate: sourceSampleRate,
            sessionSampleRate: session.sampleRate > 0 ? session.sampleRate : nil,
            queueHardwareSampleRate: hardwareRate > 0 ? hardwareRate : nil,
            outputName: output?.portName ?? "Unknown",
            outputPortType: output?.portType.rawValue ?? "Unknown"
        )
        eventHandler?(started ? .started(snapshot) : .updated(snapshot))
    }

    private func schedulePlaybackUpdates(fileName: String, sourceSampleRate: Double) {
        refreshTask?.cancel()
        refreshTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                self?.publishSnapshot(
                    fileName: fileName,
                    sourceSampleRate: sourceSampleRate,
                    started: false
                )
                while !Task.isCancelled {
                    if let time = self?.playbackTime() {
                        self?.eventHandler?(.progress(time))
                    }
                    try await Task.sleep(for: .milliseconds(250))
                }
            } catch {
                // Stopping or replacing playback cancels these UI updates.
            }
        }
    }

    private func playbackTime() -> TimeInterval? {
        guard let context, let queue = context.queue else { return nil }
        var timestamp = AudioTimeStamp()
        let status = AudioQueueGetCurrentTime(queue, nil, &timestamp, nil)
        guard status == noErr,
              timestamp.mFlags.contains(.sampleTimeValid),
              context.sourceSampleRate > 0 else { return nil }
        return context.playbackOffset + max(timestamp.mSampleTime, 0) / context.sourceSampleRate
    }

    private func copyMagicCookie(from audioFile: AudioFileID, to queue: AudioQueueRef) throws {
        var cookieSize: UInt32 = 0
        var isWritable: UInt32 = 0
        let infoStatus = AudioFileGetPropertyInfo(
            audioFile,
            kAudioFilePropertyMagicCookieData,
            &cookieSize,
            &isWritable
        )
        guard infoStatus == noErr, cookieSize > 0 else { return }
        let cookie = UnsafeMutableRawPointer.allocate(
            byteCount: Int(cookieSize),
            alignment: MemoryLayout<UInt8>.alignment
        )
        defer { cookie.deallocate() }
        try checkAudioFile(AudioFileGetProperty(
            audioFile,
            kAudioFilePropertyMagicCookieData,
            &cookieSize,
            cookie
        ))
        try checkAudioQueue(AudioQueueSetProperty(
            queue,
            kAudioQueueProperty_MagicCookie,
            cookie,
            cookieSize
        ))
    }

    private func maximumPacketSize(for audioFile: AudioFileID) throws -> UInt32 {
        var packetSize: UInt32 = 0
        var propertySize = UInt32(MemoryLayout<UInt32>.size)
        try checkAudioFile(AudioFileGetProperty(
            audioFile,
            kAudioFilePropertyPacketSizeUpperBound,
            &propertySize,
            &packetSize
        ))
        return max(packetSize, 1)
    }

    private static func packetsPerBuffer(
        format: AudioStreamBasicDescription,
        maximumPacketSize: UInt32
    ) -> UInt32 {
        let targetBytes: UInt32 = 256 * 1_024
        let byteLimited = max(targetBytes / maximumPacketSize, 1)
        guard format.mFramesPerPacket > 0 else { return min(byteLimited, 512) }
        let quarterSecond = max(
            UInt32(format.mSampleRate * 0.25) / format.mFramesPerPacket,
            1
        )
        return min(max(quarterSecond, 1), byteLimited)
    }

    private func beginFileAccess(_ url: URL) throws {
        let libraryFolders = (try? fileImportService.restoreLibraryFolders()) ?? []
        let scopeURL = libraryFolders.first {
            url.standardizedFileURL.pathComponents.starts(with: $0.standardizedFileURL.pathComponents)
        } ?? url
        let hasAccess = scopeURL.startAccessingSecurityScopedResource()
        guard hasAccess || FileManager.default.isReadableFile(atPath: url.path) else {
            throw FileImportServiceError.accessDenied
        }
        accessedURL = scopeURL
        isAccessingSecurityScope = hasAccess
    }

    private func endFileAccess() {
        if isAccessingSecurityScope { accessedURL?.stopAccessingSecurityScopedResource() }
        accessedURL = nil
        isAccessingSecurityScope = false
    }

    private func disposePlayback() {
        guard let context else { return }
        context.isStopping.store(true, ordering: .releasing)
        if let queue = context.queue {
            AudioQueueStop(queue, true)
            AudioQueueDispose(queue, true)
        }
        AudioFileClose(context.audioFile)
        self.context = nil
    }

    private func checkAudioFile(_ status: OSStatus) throws {
        guard status == noErr else { throw HiResAudioQueueProbeError.audioFile(status) }
    }

    private func checkAudioQueue(_ status: OSStatus) throws {
        guard status == noErr else { throw HiResAudioQueueProbeError.audioQueue(status) }
    }
}

private let hiResAudioQueueOutputCallback: AudioQueueOutputCallback = { userData, _, buffer in
    guard let userData else { return }
    let context = Unmanaged<HiResAudioQueueProbeContext>
        .fromOpaque(userData)
        .takeUnretainedValue()
    _ = context.fill(buffer)
}

private let hiResAudioQueueRunningPropertyCallback: AudioQueuePropertyListenerProc = { userData, queue, propertyID in
    guard propertyID == kAudioQueueProperty_IsRunning, let userData else { return }
    let context = Unmanaged<HiResAudioQueueProbeContext>
        .fromOpaque(userData)
        .takeUnretainedValue()
    var isRunning: UInt32 = 0
    var size = UInt32(MemoryLayout<UInt32>.size)
    guard AudioQueueGetProperty(queue, propertyID, &isRunning, &size) == noErr,
          isRunning == 0,
          context.reachedEOF.load(ordering: .acquiring),
          !context.isStopping.load(ordering: .acquiring),
          context.didReportEnd.compareExchange(
            expected: false,
            desired: true,
            ordering: .acquiringAndReleasing
          ).exchanged else { return }
    context.eventHandler(.reachedEnd)
}

private let hiResSilentQueueOutputCallback: AudioQueueOutputCallback = { _, _, _ in }

private final class HiResAudioQueueProbeContext: @unchecked Sendable {
    let audioFile: AudioFileID
    let sourceSampleRate: Double
    let framesPerPacket: UInt32
    let totalPacketCount: Int64
    let eventHandler: @Sendable (HiResAudioQueueProbeEvent) -> Void
    var queue: AudioQueueRef?
    var buffers: [AudioQueueBufferRef] = []
    var packetsPerBuffer: UInt32 = 1
    var currentPacket: Int64 = 0
    var playbackOffset: TimeInterval = 0
    let isStopping = Atomic<Bool>(false)
    let hasStarted = Atomic<Bool>(false)
    let reachedEOF = Atomic<Bool>(false)
    let didReportEnd = Atomic<Bool>(false)

    init(
        audioFile: AudioFileID,
        format: AudioStreamBasicDescription,
        eventHandler: @escaping @Sendable (HiResAudioQueueProbeEvent) -> Void
    ) {
        self.audioFile = audioFile
        sourceSampleRate = format.mSampleRate
        framesPerPacket = format.mFramesPerPacket
        var packetCount: Int64 = 0
        var size = UInt32(MemoryLayout<Int64>.size)
        if AudioFileGetProperty(
            audioFile,
            kAudioFilePropertyAudioDataPacketCount,
            &size,
            &packetCount
        ) != noErr {
            packetCount = 0
        }
        totalPacketCount = packetCount
        self.eventHandler = eventHandler
    }

    func packetOffset(for time: TimeInterval) -> Int64 {
        guard sourceSampleRate > 0, framesPerPacket > 0 else { return 0 }
        let packet = Int64(time * sourceSampleRate / Double(framesPerPacket))
        guard totalPacketCount > 0 else { return max(packet, 0) }
        return min(max(packet, 0), totalPacketCount - 1)
    }

    func fill(_ buffer: AudioQueueBufferRef) -> Bool {
        guard !isStopping.load(ordering: .acquiring), let queue else { return false }
        var byteCount = buffer.pointee.mAudioDataBytesCapacity
        var packetCount = packetsPerBuffer
        let status = AudioFileReadPacketData(
            audioFile,
            false,
            &byteCount,
            buffer.pointee.mPacketDescriptions,
            currentPacket,
            &packetCount,
            buffer.pointee.mAudioData
        )
        guard status == noErr else {
            eventHandler(.failed(HiResAudioQueueProbeError.audioFile(status).localizedDescription))
            return false
        }
        guard packetCount > 0 else {
            if reachedEOF.compareExchange(
                expected: false,
                desired: true,
                ordering: .acquiringAndReleasing
            ).exchanged, hasStarted.load(ordering: .acquiring) {
                AudioQueueStop(queue, false)
            }
            return false
        }

        buffer.pointee.mAudioDataByteSize = byteCount
        buffer.pointee.mPacketDescriptionCount = packetCount
        let enqueueStatus = AudioQueueEnqueueBuffer(
            queue,
            buffer,
            packetCount,
            buffer.pointee.mPacketDescriptions
        )
        guard enqueueStatus == noErr else {
            eventHandler(.failed(HiResAudioQueueProbeError.audioQueue(enqueueStatus).localizedDescription))
            return false
        }
        currentPacket += Int64(packetCount)
        return true
    }
}
