import AVFoundation
import CoreML
import MediaPipeTasksVision
import XCTest
import SwiftUI
@testable import SprintAI

final class VideoProcessingTests: XCTestCase {
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
        let landmarks = (0..<33).map { index in
            NormalizedLandmark(x: Float(index % 4 + 1) / 6, y: Float(index % 5 + 1) / 7, z: 0, visibility: 1, presence: 1)
        }
        let (output, measurement) = drawer.drawAnnotations(imageBuffer: source, poseLandmarks: [landmarks], timestamp: 0)
        XCTAssertNotNil(measurement)
        // The colored top and bottom corners must survive the render round trip.
        XCTAssertEqual(pixel(source, x: 2, y: 2), pixel(output, x: 2, y: 2))
        XCTAssertEqual(pixel(source, x: 2, y: 237), pixel(output, x: 2, y: 237))
        var hidden = landmarks
        hidden[26] = NormalizedLandmark(x: 0.5, y: 0.5, z: 0, visibility: 0.1, presence: 1)
        XCTAssertNil(drawer.drawAnnotations(imageBuffer: source, poseLandmarks: [hidden], timestamp: 0).1)
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
