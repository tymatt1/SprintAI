import CoreMotion
import CoreML
import Foundation

/// Owns sensor acquisition and inference on one serial queue.
final class MotionClassifier {
    enum Update {
        case prediction(isSprinting: Bool, timestamp: TimeInterval)
        case interrupted
    }

    private let manager = CMMotionManager()
    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.sprintai.motion"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    private var activeSession: MotionSession?
    private var model: SprintDetectionModel?
    private var samples: [[Double]] = []
    private var lastTimestamp: TimeInterval?
    // These values are coupled to the bundled trained model; do not retune independently.
    private let means = [-0.02220794, -0.07266588, 0.05048688, 0.02006975, 0.03090024, -0.01814013]
    private let deviations = [0.79717622, 0.77048275, 0.37217978, 0.91366268, 1.80617763, 2.13475018]

    func start(onUpdate: @escaping (Result<Update, Error>) -> Void) {
        stop()
        guard manager.isDeviceMotionAvailable else {
            onUpdate(.failure(MotionError.unavailable))
            return
        }
        let session = MotionSession()
        activeSession = session
        queue.addOperation { [weak self] in
            self?.samples.removeAll(keepingCapacity: true)
            self?.lastTimestamp = nil
        }
        manager.deviceMotionUpdateInterval = 0.02
        manager.startDeviceMotionUpdates(to: queue) { [weak self] motion, error in
            guard let self, !session.isCancelled else { return }
            if let error { onUpdate(.failure(error)); return }
            guard let motion else { return }
            do {
                if self.model == nil {
                    self.model = try SprintDetectionModel(configuration: MLModelConfiguration())
                }
                if let previous = self.lastTimestamp {
                    guard motion.timestamp > previous else { return }
                    if motion.timestamp - previous > 0.1 {
                        self.samples.removeAll(keepingCapacity: true)
                        onUpdate(.success(.interrupted))
                    }
                }
                self.lastTimestamp = motion.timestamp
                // Reconstruct gravity-inclusive acceleration to preserve the old input convention.
                // DeviceMotion supplies synchronized acceleration/rotation with a monotonic timestamp.
                let acceleration = motion.userAcceleration
                let gravity = motion.gravity
                let rotation = motion.rotationRate
                self.samples.append([
                    acceleration.x + gravity.x, acceleration.y + gravity.y, acceleration.z + gravity.z,
                    rotation.x, rotation.y, rotation.z
                ])
                if self.samples.count > 50 { self.samples.removeFirst() }
                guard self.samples.count == 50, let model = self.model else { return }
                let input = try MLMultiArray(shape: [1, 50, 6], dataType: .double)
                for (i, sample) in self.samples.enumerated() {
                    for j in 0..<6 {
                        input[[0, NSNumber(value: i), NSNumber(value: j)]] = NSNumber(value: (sample[j] - self.means[j]) / self.deviations[j])
                    }
                }
                let output = try model.prediction(lstm_input: input).Identity[0].doubleValue
                let magnitude = self.samples.reduce(0.0) { sum, sample in
                    sum + sqrt(sample[0] * sample[0] + sample[1] * sample[1] + sample[2] * sample[2])
                } / Double(self.samples.count)
                onUpdate(.success(.prediction(isSprinting: output > 0.9 && magnitude > 2, timestamp: motion.timestamp)))
            } catch {
                onUpdate(.failure(error))
            }
        }
    }

    func stop() {
        activeSession?.cancel()
        activeSession = nil
        manager.stopDeviceMotionUpdates()
        // Do not mutate inference buffers from the main thread.
    }

    deinit { activeSession?.cancel(); manager.stopDeviceMotionUpdates() }

    private enum MotionError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Motion sensors are unavailable. Run automatic timing on a physical iPhone." }
    }
}

private final class MotionSession {
    private let lock = NSLock()
    private var cancelled = false
    var isCancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return cancelled
    }
    func cancel() {
        lock.lock()
        cancelled = true
        lock.unlock()
    }
}
