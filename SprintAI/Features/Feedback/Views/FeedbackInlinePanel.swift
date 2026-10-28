import SwiftUI

struct FeedbackInlinePanel: View {
    @ObservedObject var viewModel: AnalysisViewModel
    @State private var expanded = false
    @State private var showConsent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI Form Feedback", systemImage: "sparkles").font(.headline)
                Spacer()
                Button {
                    withAnimation { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.down" : "chevron.up")
                }
                .accessibilityLabel(expanded ? "Collapse feedback" : "Expand feedback")
            }
            if viewModel.isGeneratingFeedback {
                HStack {
                    ProgressView()
                    Text(viewModel.currentStage?.rawValue ?? "Working…").font(.footnote)
                    Spacer()
                    Button("Cancel", role: .cancel) { viewModel.cancelFeedback() }
                }
            } else {
                Button("Get feedback") { showConsent = true }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
            }
            if let error = viewModel.feedbackError {
                Text(error).font(.footnote).foregroundStyle(.red)
            }
            if let feedback = viewModel.feedbackText {
                ScrollView {
                    Text(LocalizedStringKey(feedback))
                        .font(.subheadline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
                .frame(maxHeight: expanded ? 340 : 140)
            } else if !viewModel.isGeneratingFeedback {
                Text("Get observations and coaching suggestions for this clip.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding()
        .foregroundStyle(.white)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .confirmationDialog("Send frames for AI feedback?", isPresented: $showConsent, titleVisibility: .visible) {
            Button("Send frames") { viewModel.generateFormFeedback() }
        } message: {
            Text("Up to 14 frames and your measured angle summaries will be sent to your configured server and OpenAI. Timing and pose analysis stay on your device.")
        }
    }
}
