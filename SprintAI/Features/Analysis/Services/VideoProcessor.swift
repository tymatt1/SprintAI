import AVFoundation
import CoreImage
import MediaPipeTasksVision
import UIKit

struct ProcessedVideo: Sendable {
    let url: URL
    let angles: [AngleData]
    let aspectRatio: CGFloat
}

/// One processor per job. No player/UI state is shared with the processing executor.
enum VideoProcessor {
    static func process(url: URL, progress: @escaping @Sendable (Double) -> Void) async throws -> ProcessedVideo {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            throw ProcessingError.message("This file has no video track.")
        }
        let duration = try await asset.load(.duration).seconds
        guard duration.isFinite, duration > 0, duration <= 60 else {
            throw ProcessingError.message("Choose a video between 0 and 60 seconds long.")
        }
        let naturalSize = try await track.load(.naturalSize)
        let transform = try await track.load(.preferredTransform)
        let frameRate = try await track.load(.nominalFrameRate)
        let bounds = CGRect(origin: .zero, size: naturalSize).applying(transform)
        let width = Int(abs(bounds.width).rounded())
        let height = Int(abs(bounds.height).rounded())
        guard width > 0, height > 0, width <= 4096, height <= 4096 else {
            throw ProcessingError.message("Choose a video with dimensions up to 4096 pixels per side.")
        }

        guard let modelPath = Bundle.main.path(forResource: "pose_landmarker_full", ofType: "task") else {
            throw ProcessingError.message("The pose model is missing from the app bundle.")
        }
        let options = PoseLandmarkerOptions()
        options.baseOptions.modelAssetPath = modelPath
        options.runningMode = .video
        options.numPoses = 1
        let landmarker = try PoseLandmarker(options: options)
        let drawer = AnnotationDrawer()
        let context = CIContext()
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw ProcessingError.message("Cannot read this video format.") }
        reader.add(output)

        let destination = FileManager.default.temporaryDirectory
            .appendingPathComponent("sprintai-annotated-\(UUID().uuidString).mp4")
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height
        ])
        input.expectsMediaDataInRealTime = false
        guard writer.canAdd(input) else { throw ProcessingError.message("Cannot export this video format.") }
        writer.add(input)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ])

        do {
            try Task.checkCancellation()
            guard reader.startReading(), writer.startWriting() else {
                throw reader.error ?? writer.error ?? ProcessingError.message("Could not start video processing.")
            }
            writer.startSession(atSourceTime: .zero)
            var angles: [AngleData] = []
            var origin: CMTime?
            var lastPoseTimestamp = -1
            var frameCount = 0
            while let sample = output.copyNextSampleBuffer() {
                try Task.checkCancellation()
                while !input.isReadyForMoreMediaData {
                    guard writer.status == .writing else {
                        throw writer.error ?? ProcessingError.message("Video export stopped unexpectedly.")
                    }
                    try await Task.sleep(nanoseconds: 2_000_000)
                }
                guard let source = CMSampleBufferGetImageBuffer(sample), let pool = adaptor.pixelBufferPool else {
                    throw ProcessingError.message("A video frame could not be decoded.")
                }
                let presentation = CMSampleBufferGetPresentationTimeStamp(sample)
                if origin == nil { origin = presentation }
                let time = presentation - origin!
                let timestampMs = Int((time.seconds * 1000).rounded())
                let measurement: AngleData? = try autoreleasepool {
                    var upright: CVPixelBuffer?
                    guard CVPixelBufferPoolCreatePixelBuffer(nil, pool, &upright) == kCVReturnSuccess,
                          let upright else { throw ProcessingError.message("Not enough memory to render video.") }
                    let image = CIImage(cvPixelBuffer: source).transformed(by: transform)
                    let normalized = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
                    context.render(normalized, to: upright)
                    var rendered = upright
                    var angle: AngleData?
                    // MediaPipe requires strictly increasing integer millisecond timestamps.
                    if timestampMs > lastPoseTimestamp {
                        let pose = try landmarker.detect(videoFrame: MPImage(pixelBuffer: upright), timestampInMilliseconds: timestampMs)
                        (rendered, angle) = drawer.drawAnnotations(imageBuffer: upright, poseLandmarks: pose.landmarks, timestamp: time.seconds)
                        lastPoseTimestamp = timestampMs
                    }
                    guard adaptor.append(rendered, withPresentationTime: time) else {
                        throw writer.error ?? ProcessingError.message("Could not write an annotated frame.")
                    }
                    return angle
                }
                if let measurement { angles.append(measurement) }
                frameCount += 1
                // Publish at most ~10 updates per second of source footage.
                if frameCount % max(1, Int(frameRate / 10)) == 0 {
                    progress(min(time.seconds / duration, 0.99))
                }
            }
            try Task.checkCancellation()
            guard reader.status == .completed else {
                throw reader.error ?? ProcessingError.message("The video could not be completely read.")
            }
            guard frameCount > 0 else { throw ProcessingError.message("This video contains no readable frames.") }
            input.markAsFinished()
            await withCheckedContinuation { continuation in
                writer.finishWriting { continuation.resume() }
            }
            try Task.checkCancellation()
            guard writer.status == .completed else {
                throw writer.error ?? ProcessingError.message("The annotated video could not be saved.")
            }
            return ProcessedVideo(url: destination, angles: angles, aspectRatio: CGFloat(width) / CGFloat(height))
        } catch {
            reader.cancelReading()
            writer.cancelWriting()
            try? FileManager.default.removeItem(at: destination)
            throw error
        }
    }

    private enum ProcessingError: LocalizedError {
        case message(String)
        var errorDescription: String? { if case .message(let message) = self { return message }; return nil }
    }
}
