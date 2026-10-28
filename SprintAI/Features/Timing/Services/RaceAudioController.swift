import AVFoundation

@MainActor
final class RaceAudioController: ObservableObject {
    private var sequence: Task<Void, Never>?
    private var player: AVAudioPlayer?

    func playSequence() {
        cancel()
        sequence = Task { [weak self] in
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback)
                try session.setActive(true)
                self?.play("on_your_marks")
                try await Task.sleep(nanoseconds: 10_000_000_000)
                self?.play("set")
                try await Task.sleep(nanoseconds: UInt64(Double.random(in: 1...3) * 1_000_000_000))
                self?.play("gun")
            } catch {
                // Cancellation stops pending callouts when leaving the timing screen.
            }
        }
    }

    func cancel() {
        sequence?.cancel()
        sequence = nil
        player?.stop()
        player = nil
    }

    private func play(_ name: String) {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else { return }
        player = try? AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
