import Foundation

struct AngleData: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Double
    let hipAngle: CGFloat
    let kneeAngle: CGFloat
    let torsoAngle: CGFloat
}

/// Choose the side facing the camera; never infer side changes between frames.
enum AnalysisSide: String, CaseIterable, Identifiable, Sendable {
    case right = "Right"
    case left = "Left"
    var id: String { rawValue }
    var shoulder: Int { self == .right ? 12 : 11 }
    var hip: Int { self == .right ? 24 : 23 }
    var knee: Int { self == .right ? 26 : 25 }
    var ankle: Int { self == .right ? 28 : 27 }
}
