import Foundation

/// Debounces classification decisions. Times describe detection boundaries,
/// not calibrated start-line or finish-line crossings.
public struct SprintStateMachine {
    public enum Event: Equatable {
        case started(at: TimeInterval)
        case finished(duration: TimeInterval)
    }

    private let startThreshold: Int
    private let stopThreshold: Int
    private var positiveCount = 0
    private var negativeCount = 0
    private var startedAt: TimeInterval?
    private var lastTimestamp: TimeInterval?

    public init(startThreshold: Int = 5, stopThreshold: Int = 3) {
        precondition(startThreshold > 0 && stopThreshold > 0)
        self.startThreshold = startThreshold
        self.stopThreshold = stopThreshold
    }

    public mutating func reset() {
        positiveCount = 0
        negativeCount = 0
        startedAt = nil
        lastTimestamp = nil
    }

    public mutating func update(isSprinting: Bool, timestamp: TimeInterval) -> Event? {
        guard timestamp.isFinite, lastTimestamp.map({ timestamp > $0 }) ?? true else { return nil }
        lastTimestamp = timestamp
        if isSprinting {
            positiveCount = min(positiveCount + 1, startThreshold)
            negativeCount = 0
            if startedAt == nil, positiveCount == startThreshold {
                startedAt = timestamp
                return .started(at: timestamp)
            }
        } else {
            positiveCount = 0
            negativeCount = min(negativeCount + 1, stopThreshold)
            if let start = startedAt, negativeCount == stopThreshold {
                startedAt = nil
                return .finished(duration: timestamp - start)
            }
        }
        return nil
    }
}
