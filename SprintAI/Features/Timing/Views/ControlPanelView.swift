import SwiftUI

struct ControlPanelView: View {
    @ObservedObject var viewModel: SprintTimerViewModel
    var body: some View {
        Button(action: viewModel.toggleRecording) {
            HStack {
                Text(viewModel.isRecording ? "Stop monitoring" : "Start monitoring")
                Spacer(minLength: 20)
                Image(systemName: viewModel.isRecording ? "stop" : "arrow.up.right")
            }.frame(maxWidth: .infinity)
        }
        .buttonStyle(PrimaryActionStyle())
    }
}
