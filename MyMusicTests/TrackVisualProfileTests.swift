import Foundation
import XCTest
@testable import MyMusic

final class TrackVisualProfileTests: XCTestCase {
    func testMissingFeaturesStayNeutralAndFinite() {
        let profile = TrackVisualProfile.make(from: nil)
        XCTAssertEqual(profile.energy, 0.5)
        XCTAssertEqual(profile.bassWeight, 0.5)
        XCTAssertTrue(profile.motionSpeed.isFinite)
        XCTAssertGreaterThan(profile.density, 0)
    }

    func testTransitionMovesTowardTargetWithoutJumpingOrOvershoot() {
        let start = TrackVisualProfile()
        var target = TrackVisualProfile()
        target.energy = 1
        target.aggression = 1
        let first = start.approaching(target, dt: 1.0 / 30)
        XCTAssertGreaterThan(first.energy, start.energy)
        XCTAssertLessThan(first.energy, target.energy)
        var position = first
        for _ in 0..<120 { position = position.approaching(target, dt: 1.0 / 30) }
        XCTAssertGreaterThan(position.energy, 0.95)
        XCTAssertLessThanOrEqual(position.energy, 1)
    }

    func testTrackSeedIsStableAndDifferentForDifferentIDs() {
        let first = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        let second = UUID(uuidString: "00000000-0000-0000-0000-000000000002")!
        XCTAssertEqual(TrackVisualSeed.value(for: first), TrackVisualSeed.value(for: first))
        XCTAssertNotEqual(TrackVisualSeed.value(for: first), TrackVisualSeed.value(for: second))
    }
}
