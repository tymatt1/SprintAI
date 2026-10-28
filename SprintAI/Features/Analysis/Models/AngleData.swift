import Foundation

struct AngleData: Identifiable, Sendable {
    let id = UUID()
    let timestamp: Double
    let hipAngle: CGFloat
    let kneeAngle: CGFloat
    let torsoAngle: CGFloat
}
