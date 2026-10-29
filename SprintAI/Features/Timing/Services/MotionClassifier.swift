import CoreMotion
import CoreML
import Foundation

/// Owns sensor acquisition and inference on one serial queue.
final class MotionClassifier {
    enum Update {
        case prediction(SprintStateMachine.Decision)
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
    private var input: MLMultiArray?
    private var samples: [[Double]] = []
    private var resampler = MotionResampler()
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
            self?.resampler.reset()
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
                if self.input == nil {
                    self.input = try MLMultiArray(shape: [1, 50, 6], dataType: .double)
                }
                // Reconstruct gravity-inclusive acceleration to preserve the old input convention.
                // DeviceMotion supplies synchronized acceleration/rotation with a monotonic timestamp.
                let acceleration = motion.userAcceleration
                let gravity = motion.gravity
                let rotation = motion.rotationRate
                let batch = self.resampler.append(.init(timestamp: motion.timestamp, values: [
                    acceleration.x + gravity.x, acceleration.y + gravity.y, acceleration.z + gravity.z,
                    rotation.x, rotation.y, rotation.z
                ]))
                if batch.interrupted {
                    self.samples.removeAll(keepingCapacity: true)
                    onUpdate(.success(.interrupted))
                }
                for sample in batch.samples {
                    self.samples.append(sample.values)
                    if self.samples.count > 50 { self.samples.removeFirst() }
                    guard !session.isCancelled else { return }
                    guard self.samples.count == 50, let model = self.model, let input = self.input else { continue }
                    for (i, sample) in self.samples.enumerated() {
                        for j in 0..<6 {
                            input[[0, NSNumber(value: i), NSNumber(value: j)]] = NSNumber(value: (sample[j] - self.means[j]) / self.deviations[j])
                        }
                    }
                    let output = try model.prediction(lstm_input: input).Identity[0].doubleValue
                    let magnitude = self.samples.reduce(0.0) { sum, sample in
                        sum + sqrt(sample[0] * sample[0] + sample[1] * sample[1] + sample[2] * sample[2])
                    } / Double(self.samples.count)
                    let decision = SprintStateMachine.Decision(score: output, meanAcceleration: magnitude, timestamp: sample.timestamp)
                    guard decision.isValid else { throw MotionError.invalidPrediction }
                    guard !session.isCancelled else { return }
                    onUpdate(.success(.prediction(decision)))
                }
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
        case unavailable, invalidPrediction
        var errorDescription: String? {
            switch self {
            case .unavailable: return "Motion sensors are unavailable. Run automatic timing on a physical iPhone."
            case .invalidPrediction: return "Motion classification returned an invalid value. Restart monitoring."
            }
        }
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
