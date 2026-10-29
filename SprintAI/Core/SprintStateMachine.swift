import Foundation

/// Debounces classification decisions. Times describe detection boundaries,
/// backdated to the threshold crossing of each confirmed run, not calibrated track crossings.
public struct SprintStateMachine {
    /// Continuous values from the existing model and acceleration gate, before binarization.
    public struct Decision {
        public let score: Double
        public let meanAcceleration: Double
        public let timestamp: TimeInterval

        public init(score: Double, meanAcceleration: Double, timestamp: TimeInterval) {
            self.score = score
            self.meanAcceleration = meanAcceleration
            self.timestamp = timestamp
        }

        public var isValid: Bool {
            score.isFinite && (0...1).contains(score) && meanAcceleration.isFinite && meanAcceleration >= 0 && timestamp.isFinite
        }
        public var isSprinting: Bool { score > 0.9 && meanAcceleration > 2 }

        fileprivate func boundary(since previous: Decision?) -> TimeInterval {
            guard let previous, previous.isValid, isValid,
                  timestamp > previous.timestamp, timestamp - previous.timestamp <= 0.1,
                  isSprinting != previous.isSprinting else { return timestamp }
            // Interpolate each gate separately: BOTH must be crossed to start;
            // crossing EITHER gate is enough to stop. Never extrapolate model lag.
            let gates = [(previous.score, score, 0.9), (previous.meanAcceleration, meanAcceleration, 2.0)]
            let crossings = gates.compactMap { before, after, threshold -> TimeInterval? in
                guard (before > threshold) != (after > threshold) else { return nil }
                let fraction = min(1, max(0, (threshold - before) / (after - before)))
                return previous.timestamp + (timestamp - previous.timestamp) * fraction
            }
            return (isSprinting ? crossings.max() : crossings.min()) ?? timestamp
        }
    }

    public enum Event: Equatable {
        case started(at: TimeInterval)
        case finished(duration: TimeInterval)
    }

    private let startThreshold: Int
    private let stopThreshold: Int
    private var positiveCount = 0
    private var negativeCount = 0
    private var positiveRunStartedAt: TimeInterval?
    private var negativeRunStartedAt: TimeInterval?
    private var startedAt: TimeInterval?
    private var lastTimestamp: TimeInterval?
    private var previousDecision: Decision?

    public init(startThreshold: Int = 5, stopThreshold: Int = 3) {
        precondition(startThreshold > 0 && stopThreshold > 0)
        self.startThreshold = startThreshold
        self.stopThreshold = stopThreshold
    }

    public mutating func reset() {
        positiveCount = 0
        negativeCount = 0
        startedAt = nil
        positiveRunStartedAt = nil
        negativeRunStartedAt = nil
        lastTimestamp = nil
        previousDecision = nil
    }

    public mutating func update(_ decision: Decision) -> Event? {
        guard decision.isValid, lastTimestamp.map({ decision.timestamp > $0 }) ?? true else { return nil }
        let boundary = decision.boundary(since: previousDecision)
        previousDecision = decision
        return update(isSprinting: decision.isSprinting, timestamp: decision.timestamp, boundary: boundary)
    }

    /// Boolean-only callers retain sample-boundary behavior.
    public mutating func update(isSprinting: Bool, timestamp: TimeInterval) -> Event? {
        previousDecision = nil
        return update(isSprinting: isSprinting, timestamp: timestamp, boundary: timestamp)
    }

    private mutating func update(isSprinting: Bool, timestamp: TimeInterval, boundary: TimeInterval) -> Event? {
        guard timestamp.isFinite, lastTimestamp.map({ timestamp > $0 }) ?? true else { return nil }
        lastTimestamp = timestamp
        if isSprinting {
            if positiveCount == 0 { positiveRunStartedAt = boundary }
            negativeRunStartedAt = nil
            positiveCount = min(positiveCount + 1, startThreshold)
            negativeCount = 0
            if startedAt == nil, positiveCount == startThreshold {
                let boundary = positiveRunStartedAt ?? timestamp
                startedAt = boundary
                return .started(at: boundary)
            }
        } else {
            if negativeCount == 0 { negativeRunStartedAt = boundary }
            positiveRunStartedAt = nil
            positiveCount = 0
            negativeCount = min(negativeCount + 1, stopThreshold)
            if let start = startedAt, negativeCount == stopThreshold {
                startedAt = nil
                return .finished(duration: (negativeRunStartedAt ?? timestamp) - start)
            }
        }
        return nil
    }
}
