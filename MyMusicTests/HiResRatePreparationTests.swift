import XCTest
@testable import MyMusic

@MainActor
final class HiResRatePreparationTests: XCTestCase {
    func testStopThenPrepareWaitsForCancelledWarmUpCleanup() async {
        let service = SuspendedPreparationService()
        let store = HiResDirectOutputProbeStore(service: service)
        store.prepare(sampleRate: 44_100)
        for _ in 0..<100 where service.continuation == nil { await Task.yield() }
        XCTAssertNotNil(service.continuation)
        store.stop()
        store.prepare(sampleRate: 192_000)
        for _ in 0..<20 { await Task.yield() }
        XCTAssertEqual(service.rates, [44_100])
        service.continuation?.resume()
        service.continuation = nil
        for _ in 0..<100 where service.rates.count < 2 { await Task.yield() }
        XCTAssertEqual(service.rates, [44_100, 192_000])
        XCTAssertTrue(service.cleanedUp)
        store.stop()
    }

    func testBothWarmUpsFinishBeforeNextDeactivation() async throws {
        var steps: [String] = []
        let rate = try await HiResRatePreparation.run(
            deactivate: { steps.append("deactivate") },
            wait: { steps.append("wait-\($0)") },
            configure: { steps.append("configure") },
            activate: { steps.append("activate") },
            warmUp: { attempt in
                steps.append("warm-\(attempt)-disposed")
                return attempt == 0 ? 44_100 : 192_000
            }
        )
        XCTAssertEqual(steps, ["deactivate", "wait-300", "configure", "activate", "warm-0-disposed",
                               "deactivate", "wait-160", "configure", "activate", "warm-1-disposed"])
        XCTAssertEqual(rate, 192_000)
    }

    func testFailureDoesNotActivateOrWarmUp() async {
        enum Failure: Error { case deactivate }
        var steps: [String] = []
        do {
            _ = try await HiResRatePreparation.run(
                deactivate: { throw Failure.deactivate },
                wait: { _ in steps.append("wait") },
                configure: { steps.append("configure") },
                activate: { steps.append("activate") },
                warmUp: { _ in steps.append("warm"); return nil }
            )
            XCTFail("Expected failure")
        } catch { XCTAssertTrue(error is Failure) }
        XCTAssertTrue(steps.isEmpty)
    }

    func testCancellationDuringWaitDoesNotConfigure() async {
        var configured = false
        let task = Task { @MainActor in
            try await HiResRatePreparation.run(
                deactivate: {},
                wait: { _ in withUnsafeCurrentTask { $0?.cancel() } },
                configure: { configured = true },
                activate: {},
                warmUp: { _ in XCTFail("Cancelled request warmed up"); return nil }
            )
        }
        do { _ = try await task.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertFalse(configured)
    }
}

@MainActor
private final class SuspendedPreparationService: HiResAudioQueueProbeServicing {
    var eventHandler: ((HiResAudioQueueProbeEvent) -> Void)?
    var continuation: CheckedContinuation<Void, Never>?
    var rates: [Double] = []
    var cleanedUp = false
    func prepare(sampleRate: Double) async throws {
        rates.append(sampleRate)
        if rates.count == 1 {
            await withCheckedContinuation { continuation = $0 }
            cleanedUp = true
            try Task.checkCancellation()
        } else {
            XCTAssertTrue(cleanedUp)
        }
    }
    func play(url: URL) async throws {}
    func pause() throws {}
    func resume() throws {}
    func seek(to time: TimeInterval) throws {}
    func stop() {}
}
