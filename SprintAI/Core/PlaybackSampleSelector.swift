import Foundation

public enum PlaybackSampleSelector {
    /// Nearest sample in an ascending timeline. Detection gaps must remain gaps.
    public static func index(at time: Double, in timestamps: [Double], maximumDistance: Double = 0.1) -> Int? {
        guard time.isFinite, time >= 0, maximumDistance.isFinite, maximumDistance >= 0,
              !timestamps.isEmpty else { return nil }
        var low = 0
        var high = timestamps.count
        while low < high {
            let middle = low + (high - low) / 2
            if timestamps[middle] < time { low = middle + 1 } else { high = middle }
        }
        let candidates = [low - 1, low].filter { timestamps.indices.contains($0) }
        guard let nearest = candidates.min(by: { abs(timestamps[$0] - time) < abs(timestamps[$1] - time) }),
              abs(timestamps[nearest] - time) <= maximumDistance else { return nil }
        return nearest
    }
}
