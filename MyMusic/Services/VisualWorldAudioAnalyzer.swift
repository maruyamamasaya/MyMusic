import Accelerate
import AVFoundation
import Foundation
import Synchronization

nonisolated struct VisualWorldAudioFrame: Sendable {
    var bands: [Float] = Array(repeating: 0, count: 24)
    var bass: Float = 0
    var mid: Float = 0
    var treble: Float = 0
    var flux: Float = 0
    /// Log-frequency location of harmonic salience, not a reliable note transcription.
    var tonalHeight: Float = 0.5
    var tonalConfidence: Float = 0
    var capturedAt: TimeInterval = 0
    var generation: Int = 0
    static let silent = Self()
}

@MainActor
protocol VisualWorldAudioControlling: AnyObject {
    var visualAudioHandler: ((VisualWorldAudioFrame) -> Void)? { get set }
    func setVisualAnalysisEnabled(_ enabled: Bool)
}

/// A single bounded mailbox. Only the audio producer writes PCM; only the serial worker reads it.
/// Full mailbox => drop a visual sample. No wait, allocation, FFT or dispatch on the audio thread.
nonisolated final class VisualWorldAudioMailbox: @unchecked Sendable {
    let enabled = Atomic<Bool>(false)
    let generation = Atomic<Int>(0)
    private let state = Atomic<Int>(0) // empty / writing / ready / reading
    private let samples = UnsafeMutablePointer<Float>.allocate(capacity: 16_384)
    private var count = 0
    private var sampleRate = 48_000.0
    private var timestamp = 0.0
    private var capturedGeneration = 0

    init() { samples.initialize(repeating: 0, count: 16_384) }
    deinit { samples.deinitialize(count: 16_384); samples.deallocate() }

    func capture(_ buffer: AVAudioPCMBuffer) {
        guard enabled.load(ordering: .relaxed), buffer.format.channelCount <= 2,
              !buffer.format.isInterleaved, let channels = buffer.floatChannelData else { return }
        guard state.compareExchange(expected: 0, desired: 1, ordering: .acquiring).exchanged else { return }
        let currentGeneration = generation.load(ordering: .acquiring)
        if capturedGeneration != currentGeneration || sampleRate != buffer.format.sampleRate { count = 0 }
        capturedGeneration = currentGeneration
        let frames = Int(buffer.frameLength)
        // Some routes ignore the requested tap size. Accumulate short callbacks in the same slot.
        if frames >= 2_048 { count = 0 }
        let n = min(frames, 2_048 - count)
        let offset = max(0, frames - n)
        samples.advanced(by: count).update(from: channels[0].advanced(by: offset), count: n)
        samples.advanced(by: 8_192 + count).update(
            from: channels[buffer.format.channelCount > 1 ? 1 : 0].advanced(by: offset), count: n)
        count += n
        sampleRate = buffer.format.sampleRate
        timestamp = ProcessInfo.processInfo.systemUptime
        state.store(count == 2_048 ? 2 : 0, ordering: .releasing)
    }

    func consume(_ body: (UnsafePointer<Float>, UnsafePointer<Float>, Int, Double, Double, Int) -> Void) {
        guard state.compareExchange(expected: 2, desired: 3, ordering: .acquiring).exchanged else { return }
        defer { count = 0; state.store(0, ordering: .releasing) }
        body(UnsafePointer(samples), UnsafePointer(samples.advanced(by: 8_192)), count, sampleRate, timestamp, capturedGeneration)
    }
}

/// FFT storage and history are owned exclusively by the analysis queue (or a single test caller).
nonisolated final class VisualWorldSpectrumAnalyzer {
    private let size = 2_048
    private let setup = vDSP_create_fftsetup(11, FFTRadix(kFFTRadix2))!
    private var window = [Float](repeating: 0, count: 2_048)
    private var input = [Float](repeating: 0, count: 2_048)
    private var real = [Float](repeating: 0, count: 1_024)
    private var imaginary = [Float](repeating: 0, count: 1_024)
    private var powers = [Float](repeating: 0, count: 1_024)
    private var combined = [Float](repeating: 0, count: 1_024)
    private var previous = [Float](repeating: 0, count: 24)
    private var previousGeneration = -1
    private var previousRate = 0.0

    init() { vDSP_hann_window(&window, vDSP_Length(size), Int32(vDSP_HANN_NORM)) }
    deinit { vDSP_destroy_fftsetup(setup) }

    func analyze(left: UnsafePointer<Float>, right: UnsafePointer<Float>, count: Int,
                 sampleRate: Double, timestamp: Double, generation: Int) -> VisualWorldAudioFrame {
        guard count >= size, sampleRate.isFinite, sampleRate >= 8_000 else { return .silent }
        if previousGeneration != generation || previousRate != sampleRate {
            previous = Array(repeating: 0, count: 24)
            previousGeneration = generation
            previousRate = sampleRate
        }
        combined.withUnsafeMutableBufferPointer { $0.initialize(repeating: 0) }
        // Sum channel power, never waveform averages: opposite-phase stereo must remain visible.
        for channel in [left, right] {
            for i in 0..<size {
                let sample = channel[count - size + i]
                input[i] = (sample.isFinite ? sample : 0) * window[i]
            }
            real.withUnsafeMutableBufferPointer { r in
                imaginary.withUnsafeMutableBufferPointer { im in
                    var split = DSPSplitComplex(realp: r.baseAddress!, imagp: im.baseAddress!)
                    input.withUnsafeBufferPointer { data in
                        data.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: size / 2) {
                            vDSP_ctoz($0, 2, &split, 1, vDSP_Length(size / 2))
                        }
                    }
                    vDSP_fft_zrip(setup, &split, 1, 11, FFTDirection(FFT_FORWARD))
                    split.realp[0] = 0; split.imagp[0] = 0
                    vDSP_zvmags(&split, 1, &powers, 1, vDSP_Length(size / 2))
                }
            }
            for i in 1..<size / 2 { combined[i] += powers[i] / Float(size * size) }
        }
        var frame = VisualWorldAudioFrame()
        frame.capturedAt = timestamp; frame.generation = generation
        var low: Float = 0, middle: Float = 0, high: Float = 0
        var total: Float = 0
        for bin in 1..<size / 2 {
            let hz = Double(bin) * sampleRate / Double(size)
            guard hz >= 30 && hz <= min(12_000, sampleRate / 2) else { continue }
            let power = combined[bin]
            let position = Float(log(hz / 30) / log(12_000.0 / 30))
            let band = min(23, max(0, Int(position * 24)))
            frame.bands[band] += power
            if hz < 180 { low += power } else if hz < 3_000 { middle += power } else { high += power }
            total += power
        }
        func response(_ power: Float) -> Float { min(1, max(0, log10(1 + sqrt(power) * 35) / 1.35)) }
        for i in 0..<24 {
            frame.bands[i] = response(frame.bands[i])
            frame.flux += max(0, frame.bands[i] - previous[i]) / 8
        }
        frame.flux = min(frame.flux, 1)
        previous = frame.bands
        frame.bass = response(low); frame.mid = response(middle); frame.treble = response(high)
        if total > 0.000_001 {
            // A bounded harmonic-comb salience, rather than naming the largest FFT bin as a note.
            // Mixed music can be ambiguous; confidence gates its effect on geometry.
            var best: Float = 0
            var bestBin = 1
            for bin in 2..<size / 2 {
                let hz = Double(bin) * sampleRate / Double(size)
                guard hz >= 60 && hz <= 8_000 else { continue }
                var salience: Float = 0
                for harmonic in 1...4 {
                    let center = bin * harmonic
                    guard center + 1 < size / 2 else { break }
                    let power = combined[center] + (combined[center - 1] + combined[center + 1]) * 0.5
                    salience += power / Float(harmonic * harmonic)
                }
                if salience > best { best = salience; bestBin = bin }
            }
            let hz = Double(bestBin) * sampleRate / Double(size)
            frame.tonalHeight = Float(min(1, max(0, log(max(60, hz) / 60) / log(8_000.0 / 60))))
            frame.tonalConfidence = min(1, max(0, (best / total - 0.12) * 1.8))
        }
        return frame
    }
}

@MainActor
final class VisualWorldAudioAnalysisService {
    let mailbox = VisualWorldAudioMailbox()
    var handler: ((VisualWorldAudioFrame) -> Void)?
    private let queue = DispatchQueue(label: "MyMusic.visual-spectrum", qos: .utility)
    private var timer: DispatchSourceTimer?

    func setEnabled(_ enabled: Bool) {
        guard enabled != mailbox.enabled.load(ordering: .relaxed) else { return }
        invalidate()
        mailbox.enabled.store(enabled, ordering: .releasing)
        timer?.cancel(); timer = nil
        guard enabled else { return }
        let mailbox = mailbox
        // One analyzer per worker lifetime; canceled workers cannot share mutable FFT history.
        let analyzer = VisualWorldSpectrumAnalyzer()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(50), leeway: .milliseconds(8))
        timer.setEventHandler { [weak self] in
            mailbox.consume { left, right, count, rate, timestamp, generation in
                guard mailbox.enabled.load(ordering: .acquiring),
                      generation == mailbox.generation.load(ordering: .acquiring) else { return }
                let frame = analyzer.analyze(left: left, right: right, count: count,
                                             sampleRate: rate, timestamp: timestamp, generation: generation)
                Task { @MainActor [weak self] in
                    guard mailbox.enabled.load(ordering: .acquiring),
                          generation == mailbox.generation.load(ordering: .acquiring) else { return }
                    self?.handler?(frame)
                }
            }
        }
        self.timer = timer
        timer.resume()
    }

    func invalidate() {
        _ = mailbox.generation.wrappingAdd(1, ordering: .acquiringAndReleasing)
        handler?(.silent)
    }

    deinit { timer?.cancel() }
}
