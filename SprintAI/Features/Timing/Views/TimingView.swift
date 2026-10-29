import SwiftUI

@MainActor
struct TimingView: View {
    var isActive = true
    @StateObject private var viewModel = SprintTimerViewModel()
    @StateObject private var raceAudio = RaceAudioController()
    @State private var selectedRecord: SprintTimeRecord?
    @State private var recordToDelete: SprintTimeRecord?
    @State private var showColor = false
    @Environment(\.scenePhase) private var scenePhase

    private var records: [SprintTimeRecord] { viewModel.filteredSprintTimes() }
    private var status: String { viewModel.isSprinting ? "Sprinting" : viewModel.isRecording ? "Monitoring" : "Standby" }

    var body: some View {
        Workspace { width, wide in
            VStack(alignment: .leading, spacing: 32) {
                Masthead { actions }
                if wide {
                    HStack(alignment: .top, spacing: 64) {
                        timer.frame(width: (width - 64) * 0.57)
                        history.frame(maxWidth: .infinity)
                    }
                } else {
                    timer
                    history.padding(.top, 16)
                }
            }
        }
        .onChange(of: viewModel.isRecording) { _, recording in UIApplication.shared.isIdleTimerDisabled = recording }
        .onChange(of: viewModel.historyRange) { _, _ in selectedRecord = nil }
        .onDisappear { stopSession() }
        .onChange(of: isActive) { _, active in if !active { stopSession() } }
        .onChange(of: scenePhase) { _, phase in if phase != .active { stopSession() } }
        .sheet(isPresented: $showColor) {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Rep color").font(SprintType.section)
                    Spacer()
                    Button("Done") { showColor = false }.buttonStyle(TextActionStyle())
                }
                ColorPicker("Chart marker", selection: $viewModel.selectedColor, supportsOpacity: false)
                    .font(SprintType.body)
                Spacer()
            }
            .padding(28).background(SprintTheme.background)
            .presentationDetents([.medium]).presentationDragIndicator(.visible)
        }
        .confirmationDialog("Delete this sprint?", isPresented: Binding(get: { recordToDelete != nil }, set: { if !$0 { recordToDelete = nil } }), titleVisibility: .visible) {
            Button("Delete sprint", role: .destructive) {
                if let record = recordToDelete { viewModel.deleteSprintTimeRecord(withId: record.id) }
                recordToDelete = nil; selectedRecord = nil
            }
        } message: { Text("This removes the saved time from your history.") }
    }

    private var actions: some View {
        Menu {
            Button(raceAudio.isPlaying ? "Stop race callouts" : "Play race callouts", systemImage: raceAudio.isPlaying ? "stop" : "speaker.wave.2") {
                raceAudio.isPlaying ? raceAudio.cancel() : raceAudio.playSequence()
            }
            Button("Rep color", systemImage: "paintpalette") { showColor = true }
        } label: {
            Image(systemName: "ellipsis").font(SprintType.label).frame(width: 44, height: 44).contentShape(Rectangle())
        }.accessibilityLabel("Timing options").tint(SprintTheme.ink)
    }

    private var timer: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Timing").font(SprintType.display(48)).accessibilityAddTraits(.isHeader)
            Text(status.uppercased()).font(SprintType.caption).tracking(1.4)
                .foregroundStyle(viewModel.isRecording ? SprintTheme.accent : SprintTheme.muted)
                .padding(.top, 28)
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text(viewModel.timeElapsed, format: .number.precision(.fractionLength(2)))
                    .font(SprintType.display(148)).monospacedDigit().tracking(-2)
                    .minimumScaleFactor(0.35).lineLimit(1)
                    .accessibilityLabel("\(viewModel.timeElapsed, specifier: "%.2f") seconds")
                Text("s").font(SprintType.section).foregroundStyle(SprintTheme.muted).accessibilityHidden(true)
            }
            .padding(.top, 2).padding(.bottom, 24)
            ControlPanelView(viewModel: viewModel)
            Text("Secure your phone. Allow 1 second to warm up.")
                .font(SprintType.detail).foregroundStyle(SprintTheme.muted).padding(.top, 12)
            if let error = viewModel.errorMessage {
                Text(error).font(SprintType.detail).foregroundStyle(SprintTheme.accent).padding(.top, 12)
            }
            if raceAudio.isPlaying { Text("Race callouts playing").font(SprintType.detail).foregroundStyle(SprintTheme.accent).padding(.top, 12) }
            if let error = raceAudio.errorMessage { Text(error).font(SprintType.detail).foregroundStyle(SprintTheme.accent).padding(.top, 12) }
            Text("Detection timing · uncalibrated")
                .font(SprintType.caption).foregroundStyle(SprintTheme.muted).padding(.top, 24)
        }
    }

    private var history: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .firstTextBaseline) {
                Text("Session").font(SprintType.section).accessibilityAddTraits(.isHeader)
                Spacer()
                Menu {
                    Picker("History range", selection: $viewModel.historyRange) {
                        ForEach(SprintTimerViewModel.HistoryRange.allCases) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    HStack(spacing: 6) { Text(viewModel.historyRange.rawValue); Image(systemName: "chevron.down") }
                        .font(SprintType.detail).frame(minHeight: 44)
                }.tint(SprintTheme.ink).accessibilityLabel("History range: \(viewModel.historyRange.rawValue)")
            }
            summary
            if records.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No sprints recorded.").font(SprintType.label)
                    Text("Completed reps save here.").font(SprintType.detail).foregroundStyle(SprintTheme.muted)
                }.padding(.vertical, 12)
            } else {
                SprintChartView(viewModel: viewModel, selectedRecord: $selectedRecord).frame(height: 260)
                VStack(spacing: 0) {
                    HStack { FieldCaption("Recorded"); Spacer(); FieldCaption("Seconds") }.padding(.bottom, 12)
                    Hairline()
                    ForEach(Array(records.sorted { $0.date > $1.date }.prefix(10))) { record in recordRow(record) }
                }
            }
        }
    }

    private var summary: some View {
        let best = records.map(\.time).min().map { String(format: "%.2f", $0) } ?? "—"
        let average = records.isEmpty ? "—" : String(format: "%.2f s", records.map(\.time).reduce(0, +) / Double(records.count))
        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .bottom, spacing: 32) {
                bestTime(best).frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 8) { Text("\(records.count) reps"); Text("Avg  \(average)").foregroundStyle(SprintTheme.muted) }.font(SprintType.detail)
            }
            VStack(alignment: .leading, spacing: 16) {
                bestTime(best)
                Text("\(records.count) reps · Avg \(average)").font(SprintType.detail).foregroundStyle(SprintTheme.muted)
            }
        }
    }

    private func bestTime(_ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            FieldCaption("Best / s")
            Text(value).font(SprintType.display(52)).monospacedDigit()
        }.accessibilityElement(children: .combine)
    }

    private func recordRow(_ record: SprintTimeRecord) -> some View {
        HStack(spacing: 8) {
            Button { selectedRecord = selectedRecord?.id == record.id ? nil : record } label: {
                HStack(spacing: 12) {
                    if selectedRecord?.id == record.id { Image(systemName: "arrow.right").foregroundStyle(SprintTheme.accent) }
                    Text(record.date, format: .dateTime.month(.abbreviated).day().hour().minute()).font(SprintType.detail)
                    Spacer(minLength: 12)
                    Text(String(format: "%.2f", record.time)).font(SprintType.display(30)).monospacedDigit()
                }.frame(minHeight: 54).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityAddTraits(selectedRecord?.id == record.id ? .isSelected : [])
            if selectedRecord?.id == record.id {
                Menu {
                    Button("Delete sprint", systemImage: "trash", role: .destructive) { recordToDelete = record }
                } label: { Image(systemName: "ellipsis").font(SprintType.label).frame(width: 44, height: 44) }
                .tint(SprintTheme.ink).accessibilityLabel("Selected sprint options")
            }
        }
    }

    private func stopSession() {
        UIApplication.shared.isIdleTimerDisabled = false
        viewModel.stopRecording(); raceAudio.cancel()
    }
}
