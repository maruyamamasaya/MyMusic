import Foundation
import XCTest
@testable import MyMusic

final class VisualWorldDynamicsTests: XCTestCase {
    func testSoundAttackAndDecayRemainSmoothAndBounded() {
        var motion = VisualWorldDynamics()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        motion.advance(date: start, level: 0, speed: 0.5)
        for frame in 1...10 {
            motion.advance(date: start.addingTimeInterval(Double(frame) / 30),
                           level: 0.8, speed: 0.5)
        }
        XCTAssertGreaterThan(motion.level, 0.65)
        let sounding = motion.level
        motion.advance(date: start.addingTimeInterval(11.0 / 30), level: 0, speed: 0.5)
        XCTAssertGreaterThan(motion.level, sounding * 0.8, "A silence sample should leave a visible tail")
        for frame in 12...160 {
            motion.advance(date: start.addingTimeInterval(Double(frame) / 30),
                           level: 0, speed: 0.5)
        }
        XCTAssertLessThan(motion.level, 0.001)
    }

    func testResumeDoesNotAdvanceByTimeSpentOffscreen() {
        var motion = VisualWorldDynamics()
        let start = Date(timeIntervalSinceReferenceDate: 100)
        motion.advance(date: start, level: 0.5, speed: 0.5)
        motion.advance(date: start.addingTimeInterval(0.03), level: 0.5, speed: 0.5)
        let savedTime = motion.time
        motion.suspend()
        motion.advance(date: start.addingTimeInterval(600), level: 0.5, speed: 0.5)
        XCTAssertEqual(motion.time, savedTime)
        motion.advance(date: start.addingTimeInterval(600.03), level: 0.5, speed: 0.5)
        XCTAssertLessThan(motion.time - savedTime, 0.04)
    }

    func testMalformedAudioValuesCannotPoisonGeometry() {
        var motion = VisualWorldDynamics()
        for frame in 0...100 {
            motion.advance(date: Date(timeIntervalSinceReferenceDate: Double(frame) / 30),
                           level: frame % 2 == 0 ? .nan : 8,
                           speed: .nan)
            XCTAssertTrue(motion.time.isFinite)
            XCTAssertTrue((0...1).contains(motion.level))
        }
    }
}
