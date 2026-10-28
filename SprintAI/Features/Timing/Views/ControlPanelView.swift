import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var viewModel: SprintTimerViewModel
    @Binding var selectedRecord: SprintTimeRecord?

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 20) {
                Button(action: viewModel.toggleRecording) {
                    Text(viewModel.isRecording ? "Stop recording" : "Start recording")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(viewModel.isRecording ? .red : .green)
                ColorPicker("Sprint color", selection: $viewModel.selectedColor)
                    .labelsHidden()
                    .accessibilityLabel("Sprint color")
            }
            if let selectedRecord {
                Button(role: .destructive) {
                    viewModel.deleteSprintTimeRecord(withId: selectedRecord.id)
                    self.selectedRecord = nil
                } label: {
                    Label("Delete selected sprint", systemImage: "trash")
                }
            }
        }
    }
}
