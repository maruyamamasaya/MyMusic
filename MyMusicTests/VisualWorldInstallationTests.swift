import AVFoundation
import Foundation
import XCTest
@testable import MyMusic

final class VisualWorldInstallationTests: XCTestCase {
    func testVisualizerRippleFamiliesRespondToFrequencyAndCycle() {
        let bass = (0..<3).map { VisualizerRipplePattern.index(bass: 0.8, mid: 0.2, treble: 0.1, serial: $0) }
        let mid = (0..<3).map { VisualizerRipplePattern.index(bass: 0.1, mid: 0.8, treble: 0.2, serial: $0) }
        let high = (0..<2).map { VisualizerRipplePattern.index(bass: 0.1, mid: 0.2, treble: 0.8, serial: $0) }
        XCTAssertEqual(Set(bass), Set([0, 1, 6]))
        XCTAssertEqual(Set(mid), Set([3, 5, 7]))
        XCTAssertEqual(Set(high), Set([2, 4]))
        XCTAssertEqual(Set(bass + mid + high).count, VisualizerRipplePattern.count)
    }

    func testPlasmaTemplatesAreDistinctAndReachOppositeEdges() {
        XCTAssertEqual(PlasmaSparkPattern.designs.count, 20)
        var signatures = Set<String>()
        for design in PlasmaSparkPattern.designs {
            let start = design.start, end = design.end
            XCTAssertTrue(start.x == 0 || start.x == 1 || start.y == 0 || start.y == 1)
            XCTAssertTrue(end.x == 0 || end.x == 1 || end.y == 0 || end.y == 1)
            XCTAssertGreaterThan(hypot(end.x-start.x,end.y-start.y), 0.8)
            XCTAssertEqual(design.bends.count, 7)
            signatures.insert("\(start)-\(end)-\(design.bends)")
        }
        XCTAssertEqual(signatures.count, 20)
    }

    func testPlasmaCycleVisitsEveryDesignAndKeepsEndpoints() {
        let routes = (0..<20).map { PlasmaSparkPattern.points(seed: 0.0, serial: $0, mid: 0.5) }
        XCTAssertEqual(Set(routes.map { "\($0[0])-\($0[8])" }).count, 20)
        for route in routes {
            XCTAssertEqual(route.count, 9)
            XCTAssertTrue(route.allSatisfy { $0.x.isFinite && $0.y.isFinite })
        }
        XCTAssertEqual(PlasmaSparkPattern.points(seed: 0, serial: 20, mid: 0.5), routes[0])
    }

    private func tone(_ hz: Double, rate: Double = 48_000, inverted: Bool = false,
                      analyzer: VisualWorldSpectrumAnalyzer = VisualWorldSpectrumAnalyzer()) -> VisualWorldAudioFrame {
        let left = (0..<2_048).map { Float(sin(Double($0) * hz * 2 * .pi / rate) * 0.4) }
        let right = left.map { inverted ? -$0 : $0 }
        return left.withUnsafeBufferPointer { l in right.withUnsafeBufferPointer { r in
            analyzer.analyze(left: l.baseAddress!, right: r.baseAddress!, count: left.count,
                             sampleRate: rate, timestamp: ProcessInfo.processInfo.systemUptime, generation: 1)
        }}
    }

    func testFrequencyBandsAndTonalDirection() {
        let low = tone(80), mid = tone(1_000), high = tone(8_000)
        XCTAssertGreaterThan(low.bass, max(low.mid, low.treble))
        XCTAssertGreaterThan(mid.mid, max(mid.bass, mid.treble))
        XCTAssertGreaterThan(high.treble, max(high.bass, high.mid))
        XCTAssertLessThan(low.tonalHeight, mid.tonalHeight)
        XCTAssertLessThan(mid.tonalHeight, high.tonalHeight)
        XCTAssertGreaterThan(mid.tonalConfidence, 0.5)
    }

    func testOppositePhaseStereoDoesNotCancel() {
        XCTAssertEqual(tone(1_000).mid, tone(1_000, inverted: true).mid, accuracy: 0.000_01)
        XCTAssertGreaterThan(tone(1_000, inverted: true).waveform.map { abs($0) }.max() ?? 0, 0.2)
    }

    func testSampleRatesAndSilence() {
        for rate in [44_100.0, 48_000, 96_000, 192_000] {
            let value = tone(1_000, rate: rate)
            XCTAssertGreaterThan(value.mid, max(value.bass, value.treble))
        }
        let silent = tone(0)
        XCTAssertEqual(silent.bands, Array(repeating: 0, count: 24))
        XCTAssertEqual(silent.tonalConfidence, 0)
        XCTAssertEqual(silent.waveform, Array(repeating: 0, count: 48))
    }

    func testMailboxDropsOverflowAndHonorsDisable() throws {
        let mailbox = VisualWorldAudioMailbox()
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 2_048))
        buffer.frameLength = 2_048
        for i in 0..<2_048 { buffer.floatChannelData![0][i] = 0.25; buffer.floatChannelData![1][i] = -0.25 }
        mailbox.capture(buffer)
        var reads = 0
        mailbox.consume { _, _, _, _, _, _ in reads += 1 }
        XCTAssertEqual(reads, 0)
        mailbox.enabled.store(true, ordering: .releasing)
        mailbox.capture(buffer)
        buffer.floatChannelData![0][0] = 0.9
        mailbox.capture(buffer)
        mailbox.consume { left, right, count, rate, _, _ in
            reads += 1
            XCTAssertEqual(left[0], 0.25)
            XCTAssertEqual(right[0], -0.25)
            XCTAssertEqual(count, 2_048)
            XCTAssertEqual(rate, 48_000)
        }
        mailbox.consume { _, _, _, _, _, _ in reads += 1 }
        XCTAssertEqual(reads, 1)
    }

    func testShortTapBuffersAccumulateWithoutPublishingPartialFFT() throws {
        let mailbox = VisualWorldAudioMailbox()
        mailbox.enabled.store(true, ordering: .releasing)
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 1_024))
        buffer.frameLength = 1_024
        for i in 0..<1_024 { buffer.floatChannelData![0][i] = 0.2 }
        mailbox.capture(buffer)
        var reads = 0
        mailbox.consume { _, _, _, _, _, _ in reads += 1 }
        XCTAssertEqual(reads, 0)
        for i in 0..<1_024 { buffer.floatChannelData![0][i] = 0.4 }
        mailbox.capture(buffer)
        mailbox.consume { left, right, count, _, _, _ in
            reads += 1
            XCTAssertEqual(count, 2_048)
            XCTAssertEqual(left[0], 0.2)
            XCTAssertEqual(left[1_024], 0.4)
            XCTAssertEqual(right[1_024], 0.4)
        }
        XCTAssertEqual(reads, 1)
    }

    func testStrongSoundHasBoundedPresentationAndFiniteTail() {
        var simulation = VisualWorldSimulation()
        let start = Date()
        var audio = tone(80)
        for i in 0..<900 {
            audio.capturedAt = ProcessInfo.processInfo.systemUptime
            simulation.advance(date: start.addingTimeInterval(Double(i) / 30), audio: audio, playing: true,
                               energy: 1, aggressive: 1, ambient: 1)
            XCTAssertTrue(simulation.memory.isFinite)
            XCTAssertTrue((0...1).contains(simulation.memory))
        }
        XCTAssertGreaterThan(simulation.memory, 0.2)
        let time = simulation.clock
        simulation.suspend()
        simulation.advance(date: start.addingTimeInterval(500), audio: audio, playing: true,
                           energy: 1, aggressive: 1, ambient: 1)
        XCTAssertEqual(simulation.clock, time)
        for i in 1...360 {
            simulation.advance(date: start.addingTimeInterval(500 + Double(i) / 30), audio: .silent, playing: false,
                               energy: 1, aggressive: 1, ambient: 1)
        }
        XCTAssertTrue(simulation.resting)
        XCTAssertLessThan(simulation.memory, 0.1)
    }

    func testStaleAndMalformedSamplesDoNotExciteWorld() {
        var simulation = VisualWorldSimulation()
        var audio = VisualWorldAudioFrame()
        audio.bass = .nan; audio.mid = .infinity; audio.treble = 1
        audio.capturedAt = 0
        for i in 0..<90 {
            simulation.advance(date: Date(timeIntervalSinceReferenceDate: Double(i) / 30), audio: audio,
                               playing: true, energy: .nan, aggressive: .infinity, ambient: 0)
        }
        XCTAssertEqual(simulation.bass, 0)
        XCTAssertEqual(simulation.treble, 0)
        XCTAssertEqual(simulation.memory, 0)
        XCTAssertEqual(simulation.beat, 0)
        XCTAssertTrue(simulation.waveform.allSatisfy { $0 == 0 })
    }

    func testBeatAndWaveformDecayAfterPlaybackStops() {
        var simulation = VisualWorldSimulation()
        var audio = VisualWorldAudioFrame()
        audio.bass = 0.7
        audio.flux = 0.35
        audio.waveform[8] = 0.8
        audio.capturedAt = ProcessInfo.processInfo.systemUptime
        let start = Date()
        simulation.advance(date: start, audio: audio, playing: true,
                           energy: 0.5, aggressive: 0.5, ambient: 0.5)
        simulation.advance(date: start.addingTimeInterval(1.0/30), audio: audio, playing: true,
                           energy: 0.5, aggressive: 0.5, ambient: 0.5)
        XCTAssertGreaterThan(simulation.beat, 0.5)
        XCTAssertEqual(simulation.burstAge, 0)
        XCTAssertGreaterThan(simulation.burstBass, 0.5)
        XCTAssertEqual(simulation.burstSerial, 1)
        XCTAssertGreaterThan(simulation.waveform[8], 0.1)
        for frame in 2...90 {
            simulation.advance(date: start.addingTimeInterval(Double(frame)/30),
                               audio: .silent, playing: false,
                               energy: 0.5, aggressive: 0.5, ambient: 0.5)
        }
        XCTAssertLessThan(simulation.beat, 0.01)
        XCTAssertGreaterThan(simulation.burstAge, 0.95)
        XCTAssertLessThan(abs(simulation.waveform[8]), 0.01)

        var high = VisualWorldSimulation()
        var highAudio = VisualWorldAudioFrame()
        highAudio.treble = 0.8
        highAudio.flux = 0.35
        highAudio.capturedAt = ProcessInfo.processInfo.systemUptime
        high.advance(date: start, audio: highAudio, playing: true,
                     energy: 0.5, aggressive: 0.5, ambient: 0.5)
        high.advance(date: start.addingTimeInterval(1.0/30), audio: highAudio, playing: true,
                     energy: 0.5, aggressive: 0.5, ambient: 0.5)
        XCTAssertEqual(high.burstAge, 0)
        XCTAssertGreaterThan(high.burstTreble, high.burstBass)
        XCTAssertGreaterThan(high.burstTreble, high.burstMid)
    }
}
