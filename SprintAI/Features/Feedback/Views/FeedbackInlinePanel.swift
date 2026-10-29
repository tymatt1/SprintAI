import SwiftUI

struct FeedbackInlinePanel: View {
    @ObservedObject var viewModel: AnalysisViewModel
    @State private var expanded = false
    @State private var showConsent = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Coach’s notes", systemImage: "sparkles").font(.headline)
                Spacer()
                Button {
                    withAnimation { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.down" : "chevron.up").frame(minWidth: 44, minHeight: 44)
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
                Button(viewModel.feedbackText == nil ? "Get AI feedback" : "Generate again") { showConsent = true }
                    .buttonStyle(.borderedProminent)
                    .tint(SprintTheme.accent)
                    .foregroundStyle(SprintTheme.background)
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
                Text("Optional AI observations for this clip. Configure your feedback server in Settings to get started.")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SprintTheme.surface, in: RoundedRectangle(cornerRadius: 24))
        .overlay(RoundedRectangle(cornerRadius: 24).stroke(.white.opacity(0.07)))
        .confirmationDialog("Send frames for AI feedback?", isPresented: $showConsent, titleVisibility: .visible) {
            Button("Send frames") { viewModel.generateFormFeedback() }
        } message: {
            Text("Up to 14 frames and your measured angle summaries will be sent to your configured server and OpenAI. Timing and pose analysis stay on your device.")
        }
    }
}
