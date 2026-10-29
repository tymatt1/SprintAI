import SwiftUI
import Foundation

@MainActor
final class SprintTimerViewModel: ObservableObject {
    @Published private(set) var timeElapsed: TimeInterval = 0
    @Published private(set) var sprintTimes: [SprintTimeRecord] = []
    @Published private(set) var isRecording = false
    @Published private(set) var isSprinting = false
    enum HistoryRange: String, CaseIterable, Identifiable {
        case recent = "Last hour"
        case all = "All time"
        var id: String { rawValue }
    }
    @Published var historyRange: HistoryRange = .all
    @Published var selectedColor: Color = SprintTheme.accent
    @Published var errorMessage: String?

    private let classifier: MotionClassifier
    private let defaults: UserDefaults
    private var stateMachine = SprintStateMachine()
    private var displayTimer: Timer?
    private var sessionID = UUID()

    init(defaults: UserDefaults = .standard, classifier: MotionClassifier = MotionClassifier()) {
        self.defaults = defaults
        self.classifier = classifier
        loadSprintTimes()
    }

    func toggleRecording() {
        isRecording ? stopRecording() : startRecording()
    }

    func startRecording() {
        guard !isRecording else { return }
        stateMachine.reset()
        timeElapsed = 0
        errorMessage = nil
        isRecording = true
        sessionID = UUID()
        let currentSession = sessionID
        classifier.start { [weak self] result in
            DispatchQueue.main.async {
                guard let self, self.isRecording, self.sessionID == currentSession else { return }
                switch result {
                case .failure(let error):
                    self.stopRecording()
                    self.errorMessage = error.localizedDescription
                case .success(.interrupted):
                    self.stateMachine.reset()
                    self.isSprinting = false
                    self.displayTimer?.invalidate()
                    self.timeElapsed = 0
                case .success(.prediction(let sprinting, let timestamp)):
                    self.handle(self.stateMachine.update(isSprinting: sprinting, timestamp: timestamp))
                }
            }
        }
    }

    /// An interrupted recording is discarded rather than saved as a complete sprint.
    func stopRecording() {
        sessionID = UUID()
        classifier.stop()
        displayTimer?.invalidate()
        displayTimer = nil
        stateMachine.reset()
        isRecording = false
        isSprinting = false
    }

    private func handle(_ event: SprintStateMachine.Event?) {
        switch event {
        case .started(let timestamp):
            isSprinting = true
            displayTimer?.invalidate()
            timeElapsed = max(0, ProcessInfo.processInfo.systemUptime - timestamp)
            displayTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.timeElapsed = max(0, ProcessInfo.processInfo.systemUptime - timestamp)
                }
            }
        case .finished(let duration):
            displayTimer?.invalidate()
            displayTimer = nil
            isSprinting = false
            timeElapsed = duration
            sprintTimes.append(SprintTimeRecord(time: duration, color: selectedColor))
            saveSprintTimes()
        case nil:
            break
        }
    }

    func deleteSprintTimeRecord(withId id: UUID) {
        sprintTimes.removeAll { $0.id == id }
        saveSprintTimes()
    }

    private func saveSprintTimes() {
        do {
            defaults.set(try JSONEncoder().encode(sprintTimes), forKey: "sprintTimes")
        } catch {
            errorMessage = "Could not save sprint history: \(error.localizedDescription)"
        }
    }

    private func loadSprintTimes() {
        guard let data = defaults.data(forKey: "sprintTimes") else { return }
        do {
            sprintTimes = try JSONDecoder().decode([SprintTimeRecord].self, from: data)
        } catch {
            // Preserve unreadable legacy bytes before a later recording writes new history.
            if defaults.data(forKey: "sprintTimesRecoveryBackup") == nil {
                defaults.set(data, forKey: "sprintTimesRecoveryBackup")
            }
            errorMessage = "Saved sprint history could not be read. A recovery copy has been retained."
        }
    }

    func filteredSprintTimes() -> [SprintTimeRecord] {
        if historyRange == .all { return sprintTimes }
        let cutoff = Date().addingTimeInterval(-3600)
        return sprintTimes.filter { $0.date >= cutoff }
    }
}
