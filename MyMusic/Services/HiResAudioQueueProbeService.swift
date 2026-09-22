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
    func stop()
}

@MainActor
final class HiResAudioQueueProbeService: HiResAudioQueueProbeServicing {
    var eventHandler: ((HiResAudioQueueProbeEvent) -> Void)?

    private var context: HiResAudioQueueProbeContext?
    private var accessedURL: URL?
    private var isAccessingSecurityScope = false
    private var refreshTask: Task<Void, Never>?

    isolated deinit {
        refreshTask?.cancel()
        disposePlayback()
        endFileAccess()
    }

    func play(url: URL) async throws {
        stop()
        beginFileAccess(url)

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
                    if playbackContext.fill(buffer) { enqueuedBufferCount += 1 }
                }
                guard enqueuedBufferCount > 0 else {
                    throw HiResAudioQueueProbeError.emptyFile
                }

                var preparedFrames: UInt32 = 0
                try checkAudioQueue(AudioQueuePrime(queue, 0, &preparedFrames))
                try checkAudioQueue(AudioQueueStart(queue, nil))
                context = playbackContext
                publishSnapshot(fileName: url.lastPathComponent, sourceSampleRate: format.mSampleRate, started: true)
                scheduleSnapshotRefresh(fileName: url.lastPathComponent, sourceSampleRate: format.mSampleRate)
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

    func stop() {
        refreshTask?.cancel()
        refreshTask = nil
        disposePlayback()
        endFileAccess()
        // Manual mode intentionally leaves the shared session inactive until
        // the user selects the next file, giving the USB stream time to close.
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func configureAudioSession(sourceSampleRate: Double) async throws {
        let session = AVAudioSession.sharedInstance()
        // A paused AVAudioEngine can keep the previous hardware rate alive. The
        // diagnostic stops normal playback before reaching here, so failure to
        // deactivate is actionable and must not be hidden.
        try session.setActive(false)
        // AudioQueueStop/Dispose and setActive(false) return synchronously, but
        // USB hardware can still be releasing its previous stream. Without a
        // short cancellation point, a mid-track selection can reactivate the
        // session quickly enough to retain the first track's hardware rate.
        try await Task.sleep(for: .milliseconds(300))
        try Task.checkCancellation()
        try session.setCategory(.playback, mode: .default)
        try session.setPreferredSampleRate(sourceSampleRate)
        try session.setActive(true)
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

    private func scheduleSnapshotRefresh(fileName: String, sourceSampleRate: Double) {
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
            } catch {
                // Stopping or replacing the probe cancels this refresh.
            }
        }
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

    private func beginFileAccess(_ url: URL) {
        accessedURL = url
        isAccessingSecurityScope = url.startAccessingSecurityScopedResource()
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

private final class HiResAudioQueueProbeContext: @unchecked Sendable {
    let audioFile: AudioFileID
    let eventHandler: @Sendable (HiResAudioQueueProbeEvent) -> Void
    var queue: AudioQueueRef?
    var packetsPerBuffer: UInt32 = 1
    var currentPacket: Int64 = 0
    let isStopping = Atomic<Bool>(false)
    private var didReportEnd = false

    init(
        audioFile: AudioFileID,
        eventHandler: @escaping @Sendable (HiResAudioQueueProbeEvent) -> Void
    ) {
        self.audioFile = audioFile
        self.eventHandler = eventHandler
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
            if !didReportEnd {
                didReportEnd = true
                eventHandler(.reachedEnd)
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
