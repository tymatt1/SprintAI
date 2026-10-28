import Foundation

/// Linear interpolation onto the classifier's training cadence. Never bridges a sensor outage.
public struct MotionResampler {
    public struct Sample {
        public let timestamp: TimeInterval
        public let values: [Double]
        public init(timestamp: TimeInterval, values: [Double]) {
            self.timestamp = timestamp
            self.values = values
        }
    }

    public struct Batch {
        public let samples: [Sample]
        public let interrupted: Bool
    }

    private let interval: TimeInterval
    private let maximumGap: TimeInterval
    private var previous: Sample?
    private var nextTimestamp: TimeInterval?

    public init(frequency: Double = 50, maximumGap: TimeInterval = 0.1) {
        precondition(frequency.isFinite && frequency > 0)
        precondition(maximumGap.isFinite && maximumGap >= 1 / frequency)
        interval = 1 / frequency
        self.maximumGap = maximumGap
    }

    public mutating func reset() {
        previous = nil
        nextTimestamp = nil
    }

    public mutating func append(_ sample: Sample) -> Batch {
        guard sample.timestamp.isFinite, sample.values.count == 6,
              sample.values.allSatisfy(\.isFinite) else {
            reset()
            return Batch(samples: [], interrupted: true)
        }
        guard let previous else {
            self.previous = sample
            nextTimestamp = sample.timestamp + interval
            return Batch(samples: [sample], interrupted: false)
        }
        guard sample.timestamp > previous.timestamp else {
            return Batch(samples: [], interrupted: false)
        }
        guard sample.timestamp - previous.timestamp <= maximumGap else {
            self.previous = sample
            nextTimestamp = sample.timestamp + interval
            return Batch(samples: [sample], interrupted: true)
        }
        var result: [Sample] = []
        var time = nextTimestamp ?? sample.timestamp
        while time <= sample.timestamp + 1e-9 {
            let fraction = min(1, (time - previous.timestamp) / (sample.timestamp - previous.timestamp))
            let values = zip(previous.values, sample.values).map { $0 + ($1 - $0) * fraction }
            result.append(Sample(timestamp: time, values: values))
            time += interval
        }
        self.previous = sample
        nextTimestamp = time
        return Batch(samples: result, interrupted: false)
    }
}
