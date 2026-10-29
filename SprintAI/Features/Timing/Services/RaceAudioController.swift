import AVFoundation

@MainActor
final class RaceAudioController: ObservableObject {
    @Published private(set) var isPlaying = false
    @Published private(set) var errorMessage: String?
    private var sequenceID = UUID()
    private var sequence: Task<Void, Never>?
    private var player: AVAudioPlayer?

    func playSequence() {
        cancel()
        isPlaying = true
        errorMessage = nil
        let currentID = sequenceID
        sequence = Task { [weak self] in
            defer { if self?.sequenceID == currentID { self?.isPlaying = false } }
            do {
                let session = AVAudioSession.sharedInstance()
                try session.setCategory(.playback)
                try session.setActive(true)
                try self?.play("on_your_marks")
                try await Task.sleep(nanoseconds: 10_000_000_000)
                try self?.play("set")
                try await Task.sleep(nanoseconds: UInt64(Double.random(in: 1...3) * 1_000_000_000))
                try self?.play("gun")
                let duration = self?.player?.duration ?? 1
                try await Task.sleep(nanoseconds: UInt64(max(0, duration) * 1_000_000_000))
            } catch {
                if !(error is CancellationError) { self?.errorMessage = error.localizedDescription }
            }
        }
    }

    func cancel() {
        sequenceID = UUID()
        sequence?.cancel()
        sequence = nil
        isPlaying = false
        player?.stop()
        player = nil
    }

    private func play(_ name: String) throws {
        guard let url = Bundle.main.url(forResource: name, withExtension: "mp3") else {
            throw NSError(domain: "SprintAI.Audio", code: 1, userInfo: [NSLocalizedDescriptionKey: "A race callout audio file is missing."])
        }
        player = try AVAudioPlayer(contentsOf: url)
        player?.play()
    }
}
