import Foundation

/// Segments model decisions into sustained bouts, using sensor time throughout.
/// Boundaries describe motion detection, not calibrated start/finish-line crossings.
public struct SprintStateMachine {
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

        fileprivate func exceeds(score: Double, acceleration: Double) -> Bool {
            self.score > score && meanAcceleration > acceleration
        }

        fileprivate func boundary(since previous: Decision?, score: Double, acceleration: Double) -> TimeInterval {
            guard let previous, previous.isValid, isValid,
                  timestamp > previous.timestamp, timestamp - previous.timestamp <= 0.1,
                  exceeds(score: score, acceleration: acceleration) != previous.exceeds(score: score, acceleration: acceleration)
            else { return timestamp }
            // Both gates are required to enter; crossing either is enough to leave.
            let gates = [(previous.score, self.score, score), (previous.meanAcceleration, meanAcceleration, acceleration)]
            let crossings = gates.compactMap { before, after, threshold -> TimeInterval? in
                guard (before > threshold) != (after > threshold) else { return nil }
                let fraction = min(1, max(0, (threshold - before) / (after - before)))
                return previous.timestamp + (timestamp - previous.timestamp) * fraction
            }
            return (exceeds(score: score, acceleration: acceleration) ? crossings.max() : crossings.min()) ?? timestamp
        }
    }

    public enum Event: Equatable {
        case started(at: TimeInterval)
        case finished(duration: TimeInterval)
        case discarded
        case interrupted
    }

    // Entry retains the trained model's existing gates. Lower continuation gates
    // create hysteresis so ordinary fluctuations near entry don't split a run.
    private let entryScore = 0.9
    private let entryAcceleration = 2.0
    private let continuationScore = 0.7
    private let continuationAcceleration = 1.6
    private let startConfirmation: TimeInterval
    private let stopConfirmation: TimeInterval
    private let rearmConfirmation: TimeInterval
    private let minimumSprintDuration: TimeInterval
    private struct Candidate {
        let boundary: TimeInterval
        let observedAt: TimeInterval
    }
    private var startCandidate: Candidate?
    private var stopCandidate: Candidate?
    private var startedAt: TimeInterval?
    private var waitingForQuiet = false
    private var quietSince: TimeInterval?
    private var previousDecision: Decision?

    public init(startConfirmation: TimeInterval = 0.20, stopConfirmation: TimeInterval = 0.30,
                rearmConfirmation: TimeInterval = 0.50, minimumSprintDuration: TimeInterval = 0.50) {
        precondition([startConfirmation, stopConfirmation, rearmConfirmation, minimumSprintDuration].allSatisfy { $0.isFinite && $0 >= 0 })
        self.startConfirmation = startConfirmation
        self.stopConfirmation = stopConfirmation
        self.rearmConfirmation = rearmConfirmation
        self.minimumSprintDuration = minimumSprintDuration
    }

    public mutating func reset() {
        startCandidate = nil
        stopCandidate = nil
        startedAt = nil
        waitingForQuiet = false
        quietSince = nil
        previousDecision = nil
    }

    public mutating func update(_ decision: Decision) -> Event? {
        guard decision.isValid else { reset(); return .interrupted }
        let previous = previousDecision
        if let previous {
            guard decision.timestamp > previous.timestamp else { return nil }
            // An outage is not evidence of a stop, nor time toward confirmation.
            if decision.timestamp - previous.timestamp > 0.1 + 1e-9 {
                reset()
                previousDecision = decision
                return .interrupted
            }
        }
        previousDecision = decision
        let continuing = decision.exceeds(score: continuationScore, acceleration: continuationAcceleration)

        if waitingForQuiet {
            if continuing {
                quietSince = nil
            } else {
                if quietSince == nil { quietSince = decision.timestamp }
                if let quietSince, elapsed(since: quietSince, at: decision.timestamp, meets: rearmConfirmation) {
                    waitingForQuiet = false
                    self.quietSince = nil
                }
            }
            return nil
        }

        if let start = startedAt {
            guard !continuing else { stopCandidate = nil; return nil }
            if stopCandidate == nil {
                stopCandidate = Candidate(boundary: decision.boundary(since: previous, score: continuationScore, acceleration: continuationAcceleration),
                                          observedAt: decision.timestamp)
            }
            guard let candidate = stopCandidate else { return nil }
            guard elapsed(since: candidate.observedAt, at: decision.timestamp, meets: stopConfirmation) else { return nil }
            let duration = candidate.boundary - start
            startedAt = nil
            startCandidate = nil
            stopCandidate = nil
            waitingForQuiet = rearmConfirmation > 0
            // The already-confirmed quiet interval counts toward re-arming.
            quietSince = candidate.observedAt
            return duration > 0 && duration + 1e-9 >= minimumSprintDuration ? .finished(duration: duration) : .discarded
        }

        guard decision.exceeds(score: entryScore, acceleration: entryAcceleration) else {
            startCandidate = nil
            return nil
        }
        if startCandidate == nil {
            startCandidate = Candidate(boundary: decision.boundary(since: previous, score: entryScore, acceleration: entryAcceleration),
                                       observedAt: decision.timestamp)
        }
        guard let candidate = startCandidate else { return nil }
        guard elapsed(since: candidate.observedAt, at: decision.timestamp, meets: startConfirmation) else { return nil }
        startedAt = candidate.boundary
        startCandidate = nil
        return .started(at: candidate.boundary)
    }

    private func elapsed(since start: TimeInterval, at timestamp: TimeInterval, meets duration: TimeInterval) -> Bool {
        timestamp - start + 1e-9 >= duration
    }
}
