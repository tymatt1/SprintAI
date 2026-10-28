import Foundation

public enum JointGeometry {
    public struct Point {
        public let x: Double
        public let y: Double
        public init(x: Double, y: Double) { self.x = x; self.y = y }
    }

    /// Interior angle at b. Missing/degenerate points produce no measurement.
    public static func angle(a: Point, b: Point, c: Point) -> Double? {
        let ax = a.x - b.x, ay = a.y - b.y
        let cx = c.x - b.x, cy = c.y - b.y
        let denominator = hypot(ax, ay) * hypot(cx, cy)
        guard denominator.isFinite, denominator > 1e-10 else { return nil }
        let cosine = (ax * cx + ay * cy) / denominator
        guard cosine.isFinite else { return nil }
        return acos(min(1, max(-1, cosine))) * 180 / .pi
    }
}
