import AVKit
import SwiftUI

@MainActor
struct AnalysisVideoPlayer: View {
    let player: AVPlayer
    let onTimeChange: (Double) -> Void
    @StateObject private var observer: PlaybackTimeObserver

    init(player: AVPlayer, onTimeChange: @escaping (Double) -> Void) {
        self.player = player
        self.onTimeChange = onTimeChange
        _observer = StateObject(wrappedValue: PlaybackTimeObserver(player: player))
    }

    var body: some View {
        VideoPlayer(player: player)
            .onChange(of: observer.time) { _, time in onTimeChange(time) }
    }
}

private final class PlaybackTimeObserver: ObservableObject {
    @Published var time = 0.0
    private let player: AVPlayer
    private var token: Any?

    init(player: AVPlayer) {
        self.player = player
        token = player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.1, preferredTimescale: 600), queue: .main) { [weak self] time in
            self?.time = time.seconds
        }
    }

    deinit {
        if let token { player.removeTimeObserver(token) }
    }
}
