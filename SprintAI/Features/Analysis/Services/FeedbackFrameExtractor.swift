import AVFoundation
import UIKit

struct FeedbackFrame: Codable, Sendable {
    let timestamp: Double
    let jpegBase64: String
}

enum FeedbackFrameExtractor {
    static func extract(url: URL, angles: [AngleData]) async throws -> [FeedbackFrame] {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration).seconds
        let changes = zip(angles, angles.dropFirst()).map { previous, next in
            (timestamp: next.timestamp, change: abs(next.kneeAngle - previous.kneeAngle))
        }.sorted { $0.change > $1.change }.map(\.timestamp)
        let times = KeyframeSelector.times(duration: duration, candidates: changes, limit: 14)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 1024, height: 1024)
        var frames: [FeedbackFrame] = []
        for seconds in times {
            try Task.checkCancellation()
            let result = try await generator.image(at: CMTime(seconds: seconds, preferredTimescale: 600))
            if let data = UIImage(cgImage: result.image).jpegData(compressionQuality: 0.65) {
                guard data.count <= 512 * 1024 else { throw FrameError.tooLarge }
                frames.append(FeedbackFrame(timestamp: result.actualTime.seconds, jpegBase64: data.base64EncodedString()))
            }
        }
        guard !frames.isEmpty else { throw FrameError.empty }
        return frames
    }

    private enum FrameError: LocalizedError {
        case empty, tooLarge
        var errorDescription: String? {
            switch self {
            case .empty: return "No frames could be extracted from this video."
            case .tooLarge: return "This clip's frames are too large to send. Try a lower-resolution video."
            }
        }
    }
}
