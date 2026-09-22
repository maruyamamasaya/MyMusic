import XCTest
@testable import MyMusic

final class AudioResolutionClassificationTests: XCTestCase {
    func testHiResolutionUsesJEITACDQualityBoundaryForLosslessSources() {
        XCTAssertTrue(information(codec: "FLAC", rate: 96_000, depth: 24).isHiResolutionSource)
        XCTAssertTrue(information(codec: "ALAC", rate: 44_100, depth: 24).isHiResolutionSource)
        XCTAssertTrue(information(codec: "PCM", rate: 96_000, depth: 16).isHiResolutionSource)

        XCTAssertFalse(information(codec: "FLAC", rate: 44_100, depth: 16).isHiResolutionSource)
        XCTAssertFalse(information(codec: "FLAC", rate: 32_000, depth: 24).isHiResolutionSource)
        XCTAssertFalse(information(codec: "FLAC", rate: 96_000, depth: 12).isHiResolutionSource)
        XCTAssertFalse(information(codec: "AAC", rate: 96_000, depth: 24).isHiResolutionSource)
    }

    func testSampleRatePathComparesSourceAndActualOutput() {
        XCTAssertEqual(information(rate: 96_000, outputRate: 96_000).sampleRatePath, .native)
        XCTAssertEqual(information(rate: 44_100, outputRate: 48_000).sampleRatePath, .converted)
        XCTAssertEqual(information(rate: 96_000, outputRate: nil).sampleRatePath, .unknown)
    }

    private func information(
        codec: String = "FLAC",
        rate: Double,
        depth: Int? = 24,
        outputRate: Double? = nil
    ) -> AudioInformation {
        AudioInformation(
            codec: codec,
            sampleRate: rate,
            bitDepth: depth,
            bitRate: nil,
            channels: 2,
            outputName: outputRate == nil ? "Unknown" : "USB DAC",
            outputSampleRate: outputRate
        )
    }
}

@MainActor
final class SourceSampleRateSettingsTests: XCTestCase {
    func testDefaultsOnAndPersistsControllerChanges() {
        let suiteName = "SourceSampleRateSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let controller = SourceSampleRateControllerSpy()

        let settings = SettingsStore(sourceSampleRateController: controller, defaults: defaults)
        XCTAssertTrue(settings.sourceSampleRateMatchingEnabled)
        XCTAssertEqual(controller.enabledValues, [true])

        settings.setSourceSampleRateMatchingEnabled(false)
        XCTAssertFalse(defaults.bool(forKey: "sourceSampleRateMatchingEnabled"))

        let reloadedController = SourceSampleRateControllerSpy()
        let reloaded = SettingsStore(sourceSampleRateController: reloadedController, defaults: defaults)
        XCTAssertFalse(reloaded.sourceSampleRateMatchingEnabled)
        XCTAssertEqual(reloadedController.enabledValues, [false])
    }
}

@MainActor
private final class SourceSampleRateControllerSpy: SourceSampleRateControlling {
    var enabledValues: [Bool] = []

    func setSourceSampleRateMatchingEnabled(_ isEnabled: Bool) {
        enabledValues.append(isEnabled)
    }
}
