import SwiftUI

struct FeedbackInlinePanel: View {
    @ObservedObject var viewModel: AnalysisViewModel
    @AppStorage(FeedbackConfiguration.endpointKey) private var endpoint = ""
    @State private var expanded = false
    @State private var showFullText = false
    @State private var showConsent = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isGeneratingFeedback {
                    HStack(spacing: 12) {
                        ProgressView().tint(SprintTheme.accent)
                        Text(viewModel.currentStage?.rawValue ?? "Requesting feedback").font(SprintType.detail)
                    }
                    Button("Cancel request", role: .cancel) { viewModel.cancelFeedback() }.buttonStyle(TextActionStyle())
                } else if endpoint.isEmpty {
                    Text("Configure a feedback server in Settings.").font(SprintType.detail).foregroundStyle(SprintTheme.muted)
                } else {
                    Button(viewModel.feedbackText == nil ? "Request feedback" : "Request again") { showConsent = true }
                        .buttonStyle(TextActionStyle())
                }
                if let error = viewModel.feedbackError { Text(error).font(SprintType.detail).foregroundStyle(SprintTheme.accent) }
                if let feedback = viewModel.feedbackText {
                    Text(LocalizedStringKey(feedback)).font(SprintType.body).lineLimit(showFullText ? nil : 5).textSelection(.enabled)
                    Button(showFullText ? "Show less" : "Read all") { showFullText.toggle() }.buttonStyle(TextActionStyle())
                }
            }.padding(.top, 12)
        } label: {
            HStack {
                Text("AI feedback").font(SprintType.label)
                if viewModel.isGeneratingFeedback { Text("In progress").font(SprintType.caption).foregroundStyle(SprintTheme.muted) }
            }
        }
        .tint(SprintTheme.ink)
        .confirmationDialog("Send frames for AI feedback?", isPresented: $showConsent, titleVisibility: .visible) {
            Button("Send frames") { viewModel.generateFormFeedback() }
        } message: {
            Text("Up to 14 frames and measured angle summaries will be sent to your configured server and OpenAI. Timing and pose analysis stay on your device.")
        }
    }
}
