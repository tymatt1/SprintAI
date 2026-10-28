import CoreImage
import MediaPipeTasksVision
import UIKit

/// Renders in upright UIKit coordinates and measures visible right-side joints.
final class AnnotationDrawer {
    private let context = CIContext()
    private let connections = PoseLandmark.connections.filter {
        !Set(0...10).union(17...22).contains($0.startIndex) &&
        !Set(0...10).union(17...22).contains($0.endIndex)
    }

    func drawAnnotations(imageBuffer: CVPixelBuffer, poseLandmarks: [[NormalizedLandmark]], timestamp: Double) -> (CVPixelBuffer, AngleData?) {
        guard let landmarks = poseLandmarks.first, landmarks.count >= 33 else { return (imageBuffer, nil) }
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        let image = CIImage(cvPixelBuffer: imageBuffer)
        guard let cgImage = context.createCGImage(image, from: bounds) else { return (imageBuffer, nil) }
        let points = landmarks.map { CGPoint(x: CGFloat($0.x) * CGFloat(width), y: CGFloat($0.y) * CGFloat(height)) }
        let measurement = angles(landmarks: landmarks, points: points, timestamp: timestamp)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: bounds.size, format: format)
        let annotated = renderer.image { renderer in
            UIImage(cgImage: cgImage).draw(in: bounds)
            let drawing = renderer.cgContext
            drawing.setStrokeColor(UIColor.white.withAlphaComponent(0.85).cgColor)
            drawing.setLineWidth(max(2, CGFloat(height) / 400))
            for connection in connections where isVisible(landmarks[connection.startIndex]) && isVisible(landmarks[connection.endIndex]) {
                drawing.move(to: points[connection.startIndex])
                drawing.addLine(to: points[connection.endIndex])
                drawing.strokePath()
            }
            if measurement != nil {
                let hip = midpoint(points[23], points[24])
                let shoulder = midpoint(points[11], points[12])
                drawing.setStrokeColor(UIColor.systemTeal.cgColor)
                drawing.move(to: hip)
                drawing.addLine(to: shoulder)
                drawing.strokePath()
                drawing.setFillColor(UIColor.systemTeal.cgColor)
                for point in [points[24], points[26]] {
                    drawing.fillEllipse(in: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8))
                }
            }
        }
        var output: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:],
            kCVPixelBufferCGImageCompatibilityKey as String: true
        ]
        guard CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &output) == kCVReturnSuccess,
              let output, let rendered = CIImage(image: annotated) else { return (imageBuffer, measurement) }
        context.render(rendered, to: output)
        return (output, measurement)
    }

    private func angles(landmarks: [NormalizedLandmark], points: [CGPoint], timestamp: Double) -> AngleData? {
        guard [11, 12, 23, 24, 26, 28].allSatisfy({ isVisible(landmarks[$0]) }) else { return nil }
        func angle(_ a: CGPoint, _ b: CGPoint, _ c: CGPoint) -> CGFloat? {
            JointGeometry.angle(a: .init(x: a.x, y: a.y), b: .init(x: b.x, y: b.y), c: .init(x: c.x, y: c.y)).map { CGFloat($0) }
        }
        let hip = midpoint(points[23], points[24])
        let shoulder = midpoint(points[11], points[12])
        guard let torso = angle(shoulder, hip, CGPoint(x: hip.x, y: hip.y - 100)),
              let knee = angle(points[24], points[26], points[28]),
              let hipAngle = angle(points[12], points[24], points[26]) else { return nil }
        return AngleData(timestamp: timestamp, hipAngle: hipAngle, kneeAngle: knee, torsoAngle: torso)
    }

    private func isVisible(_ landmark: NormalizedLandmark) -> Bool {
        landmark.x.isFinite && landmark.y.isFinite &&
        (landmark.visibility?.doubleValue ?? 1) >= 0.5 && (landmark.presence?.doubleValue ?? 1) >= 0.5
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }
}
