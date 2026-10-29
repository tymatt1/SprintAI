import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var viewModel: SprintTimerViewModel
    @Binding var selectedRecord: SprintTimeRecord?
    @State private var recordToDelete: SprintTimeRecord?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: viewModel.toggleRecording) {
                Label(viewModel.isRecording ? "Stop monitoring" : "Start monitoring", systemImage: viewModel.isRecording ? "stop.fill" : "play.fill")
                    .font(.headline).frame(maxWidth: .infinity, minHeight: 48)
            }
            .buttonStyle(.borderedProminent)
            .tint(viewModel.isRecording ? .red : SprintTheme.accent)
            .foregroundStyle(viewModel.isRecording ? .white : SprintTheme.background)
            HStack {
                Text("Rep color").font(.subheadline).foregroundStyle(.secondary)
                Spacer()
                ColorPicker("Rep color", selection: $viewModel.selectedColor, supportsOpacity: false)
                    .labelsHidden().frame(minWidth: 44, minHeight: 44).accessibilityLabel("Rep color")
            }
            if let selectedRecord {
                Button(role: .destructive) { recordToDelete = selectedRecord } label: {
                    Label("Delete selected sprint", systemImage: "trash").frame(minHeight: 44)
                }
            }
        }
        .confirmationDialog("Delete this sprint?", isPresented: Binding(get: { recordToDelete != nil }, set: { if !$0 { recordToDelete = nil } }), titleVisibility: .visible) {
            Button("Delete sprint", role: .destructive) {
                if let record = recordToDelete { viewModel.deleteSprintTimeRecord(withId: record.id) }
                selectedRecord = nil
                recordToDelete = nil
            }
        } message: { Text("This removes the saved time from your history.") }
    }
}
