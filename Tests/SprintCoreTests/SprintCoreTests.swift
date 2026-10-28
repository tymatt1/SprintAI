import XCTest
@testable import SprintCore

final class SprintCoreTests: XCTestCase {
    func testConfirmedBoundariesExcludeDebounceDelayAndIgnoreBriefDropout() {
        var machine = SprintStateMachine(startThreshold: 3, stopThreshold: 2)
        XCTAssertNil(machine.update(isSprinting: true, timestamp: 1))
        XCTAssertNil(machine.update(isSprinting: false, timestamp: 1.02))
        XCTAssertNil(machine.update(isSprinting: true, timestamp: 2))
        XCTAssertNil(machine.update(isSprinting: true, timestamp: 2.02))
        XCTAssertEqual(machine.update(isSprinting: true, timestamp: 2.04), .started(at: 2))
        XCTAssertNil(machine.update(isSprinting: false, timestamp: 3))
        XCTAssertNil(machine.update(isSprinting: true, timestamp: 3.02))
        XCTAssertNil(machine.update(isSprinting: false, timestamp: 5))
        XCTAssertEqual(machine.update(isSprinting: false, timestamp: 5.02), .finished(duration: 3))
    }

    func testResamplerInterpolatesJitterOnTrainingCadence() {
        var sampler = MotionResampler()
        func sample(_ time: Double) -> MotionResampler.Sample {
            .init(timestamp: time, values: Array(repeating: time * 10, count: 6))
        }
        XCTAssertEqual(sampler.append(sample(0)).samples.count, 1)
        XCTAssertTrue(sampler.append(sample(0.013)).samples.isEmpty)
        let batch = sampler.append(sample(0.047))
        XCTAssertFalse(batch.interrupted)
        XCTAssertEqual(batch.samples.count, 2)
        XCTAssertEqual(batch.samples[0].timestamp, 0.02, accuracy: 1e-9)
        XCTAssertEqual(batch.samples[1].timestamp, 0.04, accuracy: 1e-9)
        XCTAssertEqual(batch.samples[0].values[0], 0.2, accuracy: 1e-9)
        XCTAssertEqual(batch.samples[1].values[5], 0.4, accuracy: 1e-9)
        XCTAssertTrue(sampler.append(sample(0.047)).samples.isEmpty)
        XCTAssertTrue(sampler.append(sample(0.01)).samples.isEmpty)
        let outage = sampler.append(sample(1))
        XCTAssertTrue(outage.interrupted)
        XCTAssertEqual(outage.samples.map(\.timestamp), [1])
        XCTAssertEqual(sampler.append(sample(1.02)).samples[0].timestamp, 1.02, accuracy: 1e-9)
    }

    func testResamplerRejectsInvalidFeaturesAndResetStartsFreshGrid() {
        var sampler = MotionResampler()
        _ = sampler.append(.init(timestamp: 0, values: Array(repeating: 1, count: 6)))
        XCTAssertTrue(sampler.append(.init(timestamp: 0.02, values: [.nan])).interrupted)
        XCTAssertTrue(sampler.append(.init(timestamp: .infinity, values: Array(repeating: 1, count: 6))).samples.isEmpty)
        XCTAssertEqual(sampler.append(.init(timestamp: 5, values: Array(repeating: 2, count: 6))).samples.map(\.timestamp), [5])
        sampler.reset()
        XCTAssertEqual(sampler.append(.init(timestamp: 1, values: Array(repeating: 2, count: 6))).samples.map(\.timestamp), [1])
    }

    func testDebouncingAndDurationUseSensorTime() {
        var machine = SprintStateMachine(startThreshold: 2, stopThreshold: 2)
        XCTAssertNil(machine.update(isSprinting: true, timestamp: 10))
        XCTAssertEqual(machine.update(isSprinting: true, timestamp: 10.02), .started(at: 10))
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
        XCTAssertEqual(machine.update(isSprinting: true, timestamp: 3), .started(at: 2))
        machine.reset()
        XCTAssertNil(machine.update(isSprinting: false, timestamp: 4))
    }

    func testDuplicateAndOutOfOrderSamplesDoNotConfirmSprint() {
        var machine = SprintStateMachine(startThreshold: 2)
        XCTAssertNil(machine.update(isSprinting: true, timestamp: 2))
        XCTAssertNil(machine.update(isSprinting: true, timestamp: 2))
        XCTAssertNil(machine.update(isSprinting: true, timestamp: 1))
        XCTAssertNil(machine.update(isSprinting: true, timestamp: .nan))
        XCTAssertEqual(machine.update(isSprinting: true, timestamp: 3), .started(at: 2))
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
