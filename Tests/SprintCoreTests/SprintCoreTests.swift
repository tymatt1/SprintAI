import XCTest
@testable import SprintCore

final class SprintCoreTests: XCTestCase {
    func testDebouncingAndDurationUseSensorTime() {
        var machine = SprintStateMachine(startThreshold: 2, stopThreshold: 2)
        XCTAssertNil(machine.update(isSprinting: true, timestamp: 10))
        XCTAssertEqual(machine.update(isSprinting: true, timestamp: 10.02), .started(at: 10.02))
        XCTAssertNil(machine.update(isSprinting: false, timestamp: 12))
        guard case .finished(let duration) = machine.update(isSprinting: false, timestamp: 12.02) else {
            return XCTFail("Expected one completed sprint")
        }
        XCTAssertEqual(duration, 2, accuracy: 0.000001)
        XCTAssertNil(machine.update(isSprinting: false, timestamp: 12.04))
    }

    func testNewSprintCanStartImmediatelyWithoutAnOldReset() {
        var machine = SprintStateMachine(startThreshold: 1, stopThreshold: 1)
        XCTAssertEqual(machine.update(isSprinting: true, timestamp: 1), .started(at: 1))
        XCTAssertEqual(machine.update(isSprinting: false, timestamp: 2), .finished(duration: 1))
        XCTAssertEqual(machine.update(isSprinting: true, timestamp: 3), .started(at: 3))
        XCTAssertEqual(machine.update(isSprinting: false, timestamp: 15), .finished(duration: 12))
    }

    func testResetDiscardsPartialAndActiveSprints() {
        var machine = SprintStateMachine(startThreshold: 2, stopThreshold: 1)
        _ = machine.update(isSprinting: true, timestamp: 1)
        machine.reset()
        XCTAssertNil(machine.update(isSprinting: true, timestamp: 2))
        XCTAssertEqual(machine.update(isSprinting: true, timestamp: 3), .started(at: 3))
        machine.reset()
        XCTAssertNil(machine.update(isSprinting: false, timestamp: 4))
    }

    func testDuplicateAndOutOfOrderSamplesDoNotConfirmSprint() {
        var machine = SprintStateMachine(startThreshold: 2)
        XCTAssertNil(machine.update(isSprinting: true, timestamp: 2))
        XCTAssertNil(machine.update(isSprinting: true, timestamp: 2))
        XCTAssertNil(machine.update(isSprinting: true, timestamp: 1))
        XCTAssertNil(machine.update(isSprinting: true, timestamp: .nan))
        XCTAssertEqual(machine.update(isSprinting: true, timestamp: 3), .started(at: 3))
    }

    func testAnglesRejectDegenerateAndNonfinitePoints() {
        let origin = JointGeometry.Point(x: 0, y: 0)
        XCTAssertNil(JointGeometry.angle(a: origin, b: origin, c: .init(x: 1, y: 0)))
        XCTAssertNil(JointGeometry.angle(a: .init(x: .infinity, y: 0), b: origin, c: .init(x: 1, y: 0)))
        XCTAssertEqual(JointGeometry.angle(a: .init(x: 1, y: 0), b: origin, c: .init(x: 0, y: 1))!, 90, accuracy: 0.000001)
        XCTAssertEqual(JointGeometry.angle(a: .init(x: -1, y: 0), b: origin, c: .init(x: 1, y: 0))!, 180, accuracy: 0.000001)
    }

    func testKeyframesStayInsideShortClipsAndDeduplicate() {
        let times = KeyframeSelector.times(duration: 0.02, candidates: [-1, 0, 2, .nan], limit: 14)
        XCTAssertFalse(times.isEmpty)
        XCTAssertTrue(times.allSatisfy { $0 > 0 && $0 < 0.02 })
        XCTAssertEqual(Set(times).count, times.count)
        XCTAssertTrue(KeyframeSelector.times(duration: .infinity, candidates: [], limit: 14).isEmpty)
        XCTAssertTrue(KeyframeSelector.times(duration: 2, candidates: [], limit: 0).isEmpty)
    }
}
