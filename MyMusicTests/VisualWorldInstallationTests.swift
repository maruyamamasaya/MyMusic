import AVFoundation
import Foundation
import XCTest
@testable import MyMusic

final class VisualWorldInstallationTests: XCTestCase {
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
    }

    func testSampleRatesAndSilence() {
        for rate in [44_100.0, 48_000, 96_000, 192_000] {
            let value = tone(1_000, rate: rate)
            XCTAssertGreaterThan(value.mid, max(value.bass, value.treble))
        }
        let silent = tone(0)
        XCTAssertEqual(silent.bands, Array(repeating: 0, count: 24))
        XCTAssertEqual(silent.tonalConfidence, 0)
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

    func testStrongMotionIsBoundedAndHasFiniteTail() {
        var simulation = VisualWorldSimulation()
        let start = Date()
        var audio = tone(80)
        for i in 0..<900 {
            audio.capturedAt = ProcessInfo.processInfo.systemUptime
            simulation.advance(date: start.addingTimeInterval(Double(i) / 30), audio: audio, playing: true,
                               energy: 1, aggressive: 1, calm: 0, ambient: 1, seed: 42)
            XCTAssertTrue(simulation.displacement.isFinite)
            XCTAssertLessThanOrEqual(abs(simulation.displacement), 1.5)
        }
        XCTAssertGreaterThan(abs(simulation.displacement), 0.5)
        let time = simulation.clock
        simulation.suspend()
        simulation.advance(date: start.addingTimeInterval(500), audio: audio, playing: true,
                           energy: 1, aggressive: 1, calm: 0, ambient: 1, seed: 42)
        XCTAssertEqual(simulation.clock, time)
        for i in 1...360 {
            simulation.advance(date: start.addingTimeInterval(500 + Double(i) / 30), audio: .silent, playing: false,
                               energy: 1, aggressive: 1, calm: 0, ambient: 1, seed: 42)
        }
        XCTAssertTrue(simulation.resting)
        XCTAssertLessThan(abs(simulation.displacement), 0.01)
    }

    func testStaleAndMalformedSamplesDoNotExciteWorld() {
        var simulation = VisualWorldSimulation()
        var audio = VisualWorldAudioFrame()
        audio.bass = .nan; audio.mid = .infinity; audio.treble = 1
        audio.capturedAt = 0
        for i in 0..<90 {
            simulation.advance(date: Date(timeIntervalSinceReferenceDate: Double(i) / 30), audio: audio,
                               playing: true, energy: .nan, aggressive: .infinity, calm: 0, ambient: 0, seed: 1)
        }
        XCTAssertEqual(simulation.bass, 0)
        XCTAssertEqual(simulation.treble, 0)
        XCTAssertEqual(simulation.displacement, 0)
    }
}
