import AVFoundation
import CoreML
import MediaPipeTasksVision
import XCTest
import SwiftUI
@testable import SprintAI

final class VideoProcessingTests: XCTestCase {
    @MainActor
    func testBrandFontsAreBundledAndRegistered() throws {
        for name in ["Barlow-Regular", "Barlow-Medium", "Barlow-SemiBold", "BarlowCondensed-Medium"] {
            XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: "ttf"))
            let font = try XCTUnwrap(UIFont(name: name, size: 17), "Missing brand font must not silently fall back")
            XCTAssertTrue(font.familyName.hasPrefix("Barlow"))
        }
    }

    func testFeedbackFramesHaveStrictlyIncreasingActualTimestamps() async throws {
        let source = try await makeVideo(rotated: false)
        defer { try? FileManager.default.removeItem(at: source) }
        let frames = try await FeedbackFrameExtractor.extract(url: source, angles: [])
        XCTAssertGreaterThan(frames.count, 1, "A one-second, 24 fps clip should provide multiple distinct frames")
        XCTAssertLessThanOrEqual(frames.count, 14)
        XCTAssertTrue(zip(frames, frames.dropFirst()).allSatisfy { $0.timestamp < $1.timestamp }, "Coaching should receive distinct frames in chronological order")
        for frame in frames {
            XCTAssertTrue(frame.timestamp.isFinite && frame.timestamp >= 0)
            let bytes = try XCTUnwrap(Data(base64Encoded: frame.jpegBase64))
            XCTAssertLessThanOrEqual(bytes.count, 512 * 1024)
        }
    }

    func testBundledSprintModelAcceptsTrainingInputShape() throws {
        let model = try SprintDetectionModel(configuration: MLModelConfiguration())
        let input = try MLMultiArray(shape: [1, 50, 6], dataType: .double)
        for index in 0..<input.count { input[index] = 0 }
        let score = try model.prediction(lstm_input: input).Identity[0].doubleValue
        XCTAssertTrue(score.isFinite)
        XCTAssertTrue((0...1).contains(score))
    }

    func testVideoExportBakesPortraitTransformAndProducesPlayableFrames() async throws {
        let source = try await makeVideo(rotated: true)
        defer { try? FileManager.default.removeItem(at: source) }
        let result = try await VideoProcessor.process(url: source) { _ in }
        defer { try? FileManager.default.removeItem(at: result.url) }
        XCTAssertEqual(result.aspectRatio, 240.0 / 320, accuracy: 0.001)
        XCTAssertTrue(result.angles.isEmpty, "Solid colors should not be interpreted as an athlete")
        let asset = AVURLAsset(url: result.url)
        let tracks = try await asset.loadTracks(withMediaType: .video)
        let track = try XCTUnwrap(tracks.first)
        let size = try await track.load(.naturalSize)
        XCTAssertEqual(size.width, 240)
        XCTAssertEqual(size.height, 320)
        let duration = try await asset.load(.duration)
        XCTAssertGreaterThan(duration.seconds, 0.8)
        let frame = try await AVAssetImageGenerator(asset: asset).image(at: .zero)
        XCTAssertEqual(frame.image.width, 240)
        XCTAssertEqual(frame.image.height, 320)
    }

    func testCancelledProcessingDoesNotReturnAnExport() async throws {
        let source = try await makeVideo(rotated: false)
        defer { try? FileManager.default.removeItem(at: source) }
        let job = Task { try await VideoProcessor.process(url: source) { _ in } }
        job.cancel()
        do {
            _ = try await job.value
            XCTFail("Cancelled processing should not produce an export")
        } catch is CancellationError {
            // Expected: a cancelled job must not be published to a new video session.
        }
    }

    func testAnnotationPreservesImageOrientationAndRejectsOccludedMeasurements() throws {
        let source = try makeBuffer()
        let drawer = AnnotationDrawer()
        var landmarks: [NormalizedLandmark] = []
        for index in 0..<33 {
            let x: Float = Float(index % 4 + 1) / 6.0
            let y: Float = Float(index % 5 + 1) / 7.0
            let confidence = NSNumber(value: 1.0)
            let landmark = NormalizedLandmark(x: x, y: y, z: 0, visibility: confidence, presence: confidence)
            landmarks.append(landmark)
        }
        let (output, measurement) = drawer.drawAnnotations(imageBuffer: source, poseLandmarks: [landmarks], timestamp: 0)
        XCTAssertNotNil(measurement)
        // The colored top and bottom corners must survive the render round trip.
        XCTAssertEqual(pixel(source, x: 2, y: 2), pixel(output, x: 2, y: 2))
        XCTAssertEqual(pixel(source, x: 2, y: 237), pixel(output, x: 2, y: 237))
        var hidden = landmarks
        hidden[26] = NormalizedLandmark(x: 0.5, y: 0.5, z: 0, visibility: 0.1, presence: 1)
        XCTAssertNil(drawer.drawAnnotations(imageBuffer: source, poseLandmarks: [hidden], timestamp: 0).1)
        hidden[26] = NormalizedLandmark(x: 1.2, y: 0.5, z: 0, visibility: 1, presence: 1)
        XCTAssertNil(drawer.drawAnnotations(imageBuffer: source, poseLandmarks: [hidden], timestamp: 0).1)
        // Right-side occlusion must not prevent a valid left-side analysis.
        let left = AnnotationDrawer(side: .left)
        XCTAssertNotNil(left.drawAnnotations(imageBuffer: source, poseLandmarks: [hidden], timestamp: 0).1)
        hidden[25] = NormalizedLandmark(x: 0.5, y: 0.5, z: 0, visibility: 0.1, presence: 1)
        XCTAssertNil(left.drawAnnotations(imageBuffer: source, poseLandmarks: [hidden], timestamp: 0).1)
    }

    func testRecordColorsRoundTripAndLegacyGrayscaleDecodes() throws {
        for color in [Color.black, .white, .gray, .red] {
            let record = SprintTimeRecord(time: 2.3, color: color)
            let decoded = try JSONDecoder().decode(SprintTimeRecord.self, from: JSONEncoder().encode(record))
            XCTAssertEqual(decoded.id, record.id)
            XCTAssertEqual(decoded.time, record.time)
            XCTAssertEqual(rgba(decoded.color), rgba(record.color))
        }
        let legacy = try JSONSerialization.data(withJSONObject: [
            "id": UUID().uuidString, "date": 123.0, "time": 2.3, "color": [0.5, 1]
        ])
        let decoded = try JSONDecoder().decode(SprintTimeRecord.self, from: legacy)
        XCTAssertEqual(rgba(decoded.color), [0.5, 0.5, 0.5, 1])
    }

    @MainActor
    func testInvalidHistoryDurationIsPreservedForRecovery() throws {
        let name = "SprintAI-invalid-duration-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let original = try JSONEncoder().encode([SprintTimeRecord(time: -4, color: .blue)])
        defaults.set(original, forKey: "sprintTimes")
        let model = SprintTimerViewModel(defaults: defaults)
        XCTAssertTrue(model.sprintTimes.isEmpty)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(defaults.data(forKey: "sprintTimesRecoveryBackup"), original)
    }

    @MainActor
    func testHistoryRangeCanRecoverOlderSavedSprints() throws {
        let name = "SprintAI-range-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let older = SprintTimeRecord(date: Date().addingTimeInterval(-7200), time: 12, color: .blue)
        let recent = SprintTimeRecord(time: 11.5, color: .green)
        defaults.set(try JSONEncoder().encode([older, recent]), forKey: "sprintTimes")
        let model = SprintTimerViewModel(defaults: defaults)
        model.historyRange = .recent
        XCTAssertEqual(model.filteredSprintTimes().map(\.id), [recent.id])
        model.historyRange = .all
        XCTAssertEqual(model.filteredSprintTimes().map(\.id), [older.id, recent.id])
    }

    @MainActor
    func testUnreadableHistoryIsPreservedBeforeNewWrites() {
        let name = "SprintAI-history-test-\(UUID())"
        let defaults = UserDefaults(suiteName: name)!
        defer { defaults.removePersistentDomain(forName: name) }
        let original = Data("unreadable history".utf8)
        defaults.set(original, forKey: "sprintTimes")
        let model = SprintTimerViewModel(defaults: defaults)
        XCTAssertNotNil(model.errorMessage)
        XCTAssertEqual(defaults.data(forKey: "sprintTimesRecoveryBackup"), original)
        model.deleteSprintTimeRecord(withId: UUID())
        XCTAssertEqual(defaults.data(forKey: "sprintTimesRecoveryBackup"), original)
    }

    private func rgba(_ color: Color) -> [CGFloat] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        XCTAssertTrue(UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a))
        return [r, g, b, a]
    }

    private func makeVideo(rotated: Bool) async throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("fixture-\(UUID()).mp4")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 320, AVVideoHeightKey: 240
        ])
        if rotated { input.transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 240, ty: 0) }
        writer.add(input)
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: nil)
        XCTAssertTrue(writer.startWriting())
        writer.startSession(atSourceTime: .zero)
        let buffer = try makeBuffer()
        for frame in 0..<24 {
            while !input.isReadyForMoreMediaData { try await Task.sleep(nanoseconds: 1_000_000) }
            XCTAssertTrue(adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 24)))
        }
        input.markAsFinished()
        await withCheckedContinuation { continuation in writer.finishWriting { continuation.resume() } }
        XCTAssertEqual(writer.status, .completed)
        return url
    }

    private func makeBuffer() throws -> CVPixelBuffer {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(nil, 320, 240, kCVPixelFormatType_32BGRA,
                                        [kCVPixelBufferIOSurfacePropertiesKey as String: [:]] as CFDictionary, &buffer)
        XCTAssertEqual(status, kCVReturnSuccess)
        let result = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(result, [])
        defer { CVPixelBufferUnlockBaseAddress(result, []) }
        let address = CVPixelBufferGetBaseAddress(result)!.assumingMemoryBound(to: UInt8.self)
        let stride = CVPixelBufferGetBytesPerRow(result)
        for y in 0..<240 {
            for x in 0..<320 {
                let offset = y * stride + x * 4
                address[offset] = y < 120 ? 255 : 0
                address[offset + 1] = y < 120 ? 0 : 255
                address[offset + 2] = 0
                address[offset + 3] = 255
            }
        }
        return result
    }

    private func pixel(_ buffer: CVPixelBuffer, x: Int, y: Int) -> [UInt8] {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let address = CVPixelBufferGetBaseAddress(buffer)!.assumingMemoryBound(to: UInt8.self)
        let offset = y * CVPixelBufferGetBytesPerRow(buffer) + x * 4
        return (0..<4).map { address[offset + $0] }
    }
}
