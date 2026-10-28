import Foundation

public enum KeyframeSelector {
    public static func times(duration: Double, candidates: [Double], limit: Int) -> [Double] {
        guard duration.isFinite, duration > 0, limit > 0 else { return [] }
        let count = max(1, limit / 2)
        let even = (1...count).map { duration * Double($0) / Double(count + 1) }
        let margin = min(0.05, duration / 4)
        var buckets = Set<Int>()
        return (even + candidates.filter(\.isFinite))
            .map { min(max($0, margin), duration - margin) }
            .filter { buckets.insert(Int(($0 * 20).rounded())).inserted }
            .prefix(limit)
            .sorted()
    }
}
