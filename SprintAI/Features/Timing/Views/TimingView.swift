import SwiftUI

@MainActor
struct TimingView: View {
    @StateObject private var viewModel = SprintTimerViewModel()
    @StateObject private var raceAudio = RaceAudioController()
    @State private var selectedRecord: SprintTimeRecord?
    @Environment(\.scenePhase) private var scenePhase

    private var records: [SprintTimeRecord] { viewModel.filteredSprintTimes() }
    private var status: String {
        viewModel.isSprinting ? "Sprint detected" : viewModel.isRecording ? "Ready for your sprint" : "Ready when you are"
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    TrainingHeader(eyebrow: "SprintAI · Training", title: "Make every rep count.", subtitle: "Automatic timing. A clearer view of your progress.")
                    timerCard
                    sessionSummary
                    historyCard
                    TrainingCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Race start", systemImage: "speaker.wave.2").font(.headline)
                            Text("Practice your start with marks, set, and a randomized signal.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button {
                                raceAudio.isPlaying ? raceAudio.cancel() : raceAudio.playSequence()
                            } label: {
                                Label(raceAudio.isPlaying ? "Stop callouts" : "Play callouts", systemImage: raceAudio.isPlaying ? "stop.fill" : "play.fill")
                                    .frame(minHeight: 32)
                            }
                            .buttonStyle(.bordered)
                            .tint(SprintTheme.teal)
                            if let error = raceAudio.errorMessage { Text(error).font(.footnote).foregroundStyle(.orange) }
                        }
                    }
                    Label("Experimental motion timing. Detection boundaries are not calibrated to a finish line.", systemImage: "info.circle")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(20)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .background(SprintTheme.background)
            .toolbar(.hidden, for: .navigationBar)
        }
        .onChange(of: viewModel.isRecording) { _, recording in UIApplication.shared.isIdleTimerDisabled = recording }
        .onChange(of: viewModel.historyRange) { _, _ in selectedRecord = nil }
        .onDisappear { stopSession() }
        .onChange(of: scenePhase) { _, phase in if phase != .active { stopSession() } }
    }

    private var timerCard: some View {
        TrainingCard {
            VStack(alignment: .leading, spacing: 20) {
                Label(status, systemImage: viewModel.isRecording ? "waveform.path" : "circle.dotted")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(viewModel.isRecording ? SprintTheme.accent : SprintTheme.teal)
                    .accessibilityAddTraits(.updatesFrequently)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(viewModel.timeElapsed, format: .number.precision(.fractionLength(2)))
                        .font(.system(size: 76, weight: .medium, design: .rounded)).monospacedDigit()
                        .minimumScaleFactor(0.5).lineLimit(1)
                        .contentTransition(.numericText())
                    Text("sec").font(.title3).foregroundStyle(.secondary)
                }
                Text(viewModel.isRecording ? "Keep your phone secured in the same position throughout each rep. Completed sprints save automatically." : "Secure your phone, start monitoring, then sprint. Allow one second for sensor warm-up.")
                    .font(.subheadline).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                ControlPanelView(viewModel: viewModel, selectedRecord: $selectedRecord)
                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.circle")
                        .font(.footnote).foregroundStyle(.orange).accessibilityAddTraits(.isStaticText)
                }
            }
        }
    }

    private var sessionSummary: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 95), alignment: .leading)], alignment: .leading, spacing: 16) {
            metric("Sprints", value: "\(records.count)", symbol: "figure.run")
            metric("Fastest", value: records.map(\.time).min().map { String(format: "%.2fs", $0) } ?? "—", symbol: "bolt.fill")
            metric("Average", value: records.isEmpty ? "—" : String(format: "%.2fs", records.map(\.time).reduce(0, +) / Double(records.count)), symbol: "chart.bar.fill")
        }
    }

    private func metric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol).foregroundStyle(SprintTheme.teal).accessibilityHidden(true)
            Text(value).font(.title2.bold()).monospacedDigit().minimumScaleFactor(0.7).lineLimit(1)
            Text(title).font(.caption).foregroundStyle(.secondary)
        }
        .padding(16).frame(maxWidth: .infinity, alignment: .leading)
        .background(SprintTheme.surface, in: RoundedRectangle(cornerRadius: 18))
        .accessibilityElement(children: .combine)
    }

    private var historyCard: some View {
        TrainingCard {
            VStack(alignment: .leading, spacing: 16) {
                Text("Your session").font(.title3.bold())
                Picker("History range", selection: $viewModel.historyRange) {
                    ForEach(SprintTimerViewModel.HistoryRange.allCases) { range in Text(range.rawValue).tag(range) }
                }.pickerStyle(.segmented)
                if records.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "chart.xyaxis.line").font(.largeTitle).foregroundStyle(SprintTheme.teal)
                        Text("Your next rep starts here.").font(.headline)
                        Text("Completed sprints will appear in your chart and history.")
                            .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }.frame(maxWidth: .infinity).padding(.vertical, 28)
                } else {
                    SprintChartView(viewModel: viewModel, selectedRecord: $selectedRecord)
                        .frame(height: 280)
                    Text("RECENT REPS · TAP TO SELECT").font(.caption2.weight(.bold)).tracking(1).foregroundStyle(.secondary)
                    ForEach(Array(records.sorted { $0.date > $1.date }.prefix(10))) { record in
                        Button { selectedRecord = selectedRecord?.id == record.id ? nil : record } label: {
                            HStack(spacing: 12) {
                                Circle().fill(record.color).frame(width: 10, height: 10)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(record.date, format: .dateTime.month(.abbreviated).day().hour().minute()).font(.subheadline)
                                    Text(selectedRecord?.id == record.id ? "Selected" : "Completed sprint").font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(String(format: "%.2f s", record.time)).font(.headline).monospacedDigit()
                                if selectedRecord?.id == record.id { Image(systemName: "checkmark.circle.fill").foregroundStyle(SprintTheme.accent) }
                            }
                            .padding(12).frame(minHeight: 48)
                            .background(selectedRecord?.id == record.id ? Color.white.opacity(0.07) : .clear, in: RoundedRectangle(cornerRadius: 12))
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func stopSession() {
        UIApplication.shared.isIdleTimerDisabled = false
        viewModel.stopRecording()
        raceAudio.cancel()
    }
}
