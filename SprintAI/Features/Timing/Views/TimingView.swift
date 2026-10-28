import SwiftUI

@MainActor
struct TimingView: View {
    @StateObject private var viewModel = SprintTimerViewModel()
    @StateObject private var raceAudio = RaceAudioController()
    @State private var selectedRecord: SprintTimeRecord?
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.timeElapsed, format: .number.precision(.fractionLength(2)))
                                .font(.system(size: 48, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                            Text(viewModel.isSprinting ? "Sprint detected" : viewModel.isRecording ? "Listening for a sprint…" : "Seconds")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(action: raceAudio.playSequence) {
                            Image(systemName: "megaphone.fill").font(.title2)
                                .padding()
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Play race start callouts")
                    }
                    Text("Sprint times · last hour").font(.headline)
                    SprintChartView(viewModel: viewModel, selectedRecord: $selectedRecord)
                        .frame(height: 280)
                    ControlPanelView(viewModel: viewModel, selectedRecord: $selectedRecord)
                    Text("Motion-based timing · detection delay is not calibrated")
                        .font(.caption).foregroundStyle(.secondary)
                    if let error = viewModel.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }
                .padding()
            }
            .navigationTitle("Sprint timing")
        }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { stopSession() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { stopSession() }
            else { UIApplication.shared.isIdleTimerDisabled = true }
        }
    }

    private func stopSession() {
        UIApplication.shared.isIdleTimerDisabled = false
        viewModel.stopRecording()
        raceAudio.cancel()
    }
}
