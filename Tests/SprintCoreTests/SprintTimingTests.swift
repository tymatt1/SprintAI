import XCTest
@testable import SprintCore

final class SprintTimingTests: XCTestCase {
    private struct Trace {
        var machine = SprintStateMachine()
        var tick = 0
        var events: [SprintStateMachine.Event] = []
        mutating func append(_ count: Int, score: Double, acceleration: Double) {
            for _ in 0..<count {
                if let event = machine.update(.init(score: score, meanAcceleration: acceleration, timestamp: Double(tick) * 0.02)) {
                    events.append(event)
                }
                tick += 1
            }
        }
        var starts: [Double] { events.compactMap { if case .started(let t) = $0 { return t }; return nil } }
        var durations: [Double] { events.compactMap { if case .finished(let t) = $0 { return t }; return nil } }
    }

    func testContinuousSprintSurvivesRepeatedHundredMillisecondDropouts() {
        var trace = Trace()
        trace.append(50, score: 0.1, acceleration: 1)
        trace.append(50, score: 0.98, acceleration: 3)
        for _ in 0..<40 {
            trace.append(5, score: 0.98, acceleration: 3)
            trace.append(5, score: 0.1, acceleration: 1)
        }
        trace.append(50, score: 0.98, acceleration: 3)
        XCTAssertEqual(trace.starts.count, 1)
        XCTAssertTrue(trace.durations.isEmpty, "Brief dips must not split a continuous run")
        trace.append(50, score: 0.1, acceleration: 1)
        XCTAssertEqual(trace.durations.count, 1)
        XCTAssertEqual(trace.durations[0], 10, accuracy: 0.02)
    }

    func testNeutralZoneCannotStartASprintButKeepsAnActiveSprintRunning() {
        var trace = Trace()
        trace.append(100, score: 0.85, acceleration: 1.8)
        XCTAssertTrue(trace.events.isEmpty)
        trace.append(50, score: 0.98, acceleration: 3)
        for _ in 0..<100 {
            trace.append(1, score: 0.85, acceleration: 1.8)
            trace.append(1, score: 0.95, acceleration: 2.2)
        }
        XCTAssertEqual(trace.starts.count, 1)
        XCTAssertTrue(trace.durations.isEmpty)
        trace.append(50, score: 0.1, acceleration: 1)
        XCTAssertEqual(trace.durations.count, 1)
    }

    func testRapidStartStopNoiseCreatesNoSprintEvents() {
        var trace = Trace()
        for _ in 0..<100 {
            trace.append(5, score: 0.98, acceleration: 3)
            trace.append(5, score: 0.1, acceleration: 1)
        }
        XCTAssertTrue(trace.events.isEmpty, "0.1-second bursts must not start or save sprints")
    }

    func testVeryShortConfirmedMovementIsDiscardedWithoutSaving() {
        var trace = Trace()
        trace.append(50, score: 0.1, acceleration: 1)
        trace.append(12, score: 0.98, acceleration: 3)
        trace.append(50, score: 0.1, acceleration: 1)
        XCTAssertEqual(trace.starts.count, 1)
        XCTAssertTrue(trace.events.contains(.discarded))
        XCTAssertTrue(trace.durations.isEmpty)
        // A subsequent real bout still records normally after quiet re-arming.
        trace.append(50, score: 0.98, acceleration: 3)
        trace.append(50, score: 0.1, acceleration: 1)
        XCTAssertEqual(trace.starts.count, 2)
        XCTAssertEqual(trace.durations.count, 1)
    }

    func testFinishedSprintCannotImmediatelyRetriggerWithoutQuiet() {
        var trace = Trace()
        trace.append(50, score: 0.98, acceleration: 3)
        trace.append(16, score: 0.1, acceleration: 1) // Stop confirms after 300 ms.
        XCTAssertEqual(trace.durations.count, 1)
        trace.append(100, score: 0.98, acceleration: 3)
        XCTAssertEqual(trace.starts.count, 1, "A renewed signal cannot bypass the quiet interval")
        trace.append(25, score: 0.1, acceleration: 1) // Only 480 ms between first and last.
        trace.append(25, score: 0.98, acceleration: 3)
        XCTAssertEqual(trace.starts.count, 1)
        trace.append(26, score: 0.1, acceleration: 1)
        trace.append(25, score: 0.98, acceleration: 3)
        XCTAssertEqual(trace.starts.count, 2)
    }

    func testConfirmedStopRetainsInterpolatedBoundaryAndExcludesDwellDelay() {
        var machine = SprintStateMachine(startConfirmation: 0, stopConfirmation: 0.30, rearmConfirmation: 0, minimumSprintDuration: 0)
        _ = machine.update(.init(score: 0.8, meanAcceleration: 3, timestamp: 1))
        guard case .started(let start) = machine.update(.init(score: 1, meanAcceleration: 3, timestamp: 1.02)) else {
            return XCTFail("Expected interpolated entry")
        }
        XCTAssertEqual(start, 1.01, accuracy: 1e-9)
        for tick in 52...150 {
            XCTAssertNil(machine.update(.init(score: 1, meanAcceleration: 3, timestamp: Double(tick) * 0.02)))
        }
        for tick in 151...165 {
            XCTAssertNil(machine.update(.init(score: 0.4, meanAcceleration: 3, timestamp: Double(tick) * 0.02)))
        }
        guard case .finished(let duration) = machine.update(.init(score: 0.4, meanAcceleration: 3, timestamp: 3.32)) else {
            return XCTFail("Expected stop only after the full confirmation interval")
        }
        XCTAssertEqual(duration, 2, accuracy: 1e-9)
    }

    func testBoundaryRequiresBothEntryGatesAndEitherLowerExitGate() {
        var machine = SprintStateMachine(startConfirmation: 0, stopConfirmation: 0, rearmConfirmation: 0, minimumSprintDuration: 0)
        _ = machine.update(.init(score: 0.8, meanAcceleration: 1, timestamp: 0))
        guard case .started(let start) = machine.update(.init(score: 1, meanAcceleration: 7.0 / 3, timestamp: 0.02)) else {
            return XCTFail("Expected both entry gates to cross")
        }
        XCTAssertEqual(start, 0.015, accuracy: 1e-9)
        for tick in 2...50 {
            _ = machine.update(.init(score: 1, meanAcceleration: 3, timestamp: Double(tick) * 0.02))
        }
        guard case .finished(let duration) = machine.update(.init(score: 0.4, meanAcceleration: 0, timestamp: 1.02)) else {
            return XCTFail("Expected first lower exit gate to cross")
        }
        XCTAssertEqual(duration, 1 + 0.02 * (3 - 1.6) / 3 - start, accuracy: 1e-9)
    }

    func testDuplicateAndOutOfOrderDecisionsDoNotCountAsStartEvidence() {
        var machine = SprintStateMachine()
        for _ in 0..<30 {
            XCTAssertNil(machine.update(.init(score: 0.98, meanAcceleration: 3, timestamp: 1)))
            XCTAssertNil(machine.update(.init(score: 0.98, meanAcceleration: 3, timestamp: 0.9)))
        }
        for tick in 1...9 {
            XCTAssertNil(machine.update(.init(score: 0.98, meanAcceleration: 3, timestamp: 1 + Double(tick) * 0.02)))
        }
        XCTAssertEqual(machine.update(.init(score: 0.98, meanAcceleration: 3, timestamp: 1.2)), .started(at: 1))
    }

    func testSensorGapAndInvalidDecisionInterruptInsteadOfSaving() {
        var trace = Trace()
        trace.append(50, score: 0.98, acceleration: 3)
        XCTAssertEqual(trace.machine.update(.init(score: 0.1, meanAcceleration: 1, timestamp: 2)), .interrupted)
        XCTAssertNil(trace.machine.update(.init(score: 0.1, meanAcceleration: 1, timestamp: 2.02)))
        XCTAssertEqual(trace.machine.update(.init(score: .nan, meanAcceleration: 3, timestamp: 2.04)), .interrupted)
        XCTAssertTrue(trace.durations.isEmpty)
    }

    func testResetDiscardsAnActiveBoutAndStartsAFreshSession() {
        var trace = Trace()
        trace.append(50, score: 0.98, acceleration: 3)
        trace.machine.reset()
        trace.append(50, score: 0.1, acceleration: 1)
        XCTAssertTrue(trace.durations.isEmpty)
        trace.append(50, score: 0.98, acceleration: 3)
        trace.append(50, score: 0.1, acceleration: 1)
        XCTAssertEqual(trace.starts.count, 2)
        XCTAssertEqual(trace.durations.count, 1)
    }
}
