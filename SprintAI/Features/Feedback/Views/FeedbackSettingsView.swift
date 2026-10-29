import SwiftUI

struct FeedbackSettingsView: View {
    @AppStorage(FeedbackConfiguration.endpointKey) private var savedEndpoint = ""
    @State private var endpoint = ""
    @State private var token = ""
    @State private var message: String?
    @State private var succeeded = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TrainingHeader(eyebrow: "SprintAI · Preferences", title: "Your training, your setup.", subtitle: "Local tools first. Optional coaching when you want it.")
                        .padding(.vertical, 12)
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets())
                Section {
                    Label("Timing & pose analysis", systemImage: "iphone")
                        .foregroundStyle(SprintTheme.teal)
                    Text("Ready to use on your device. No server or account required.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section {
                    LabeledContent("Status", value: savedEndpoint.isEmpty ? "Not configured" : "Configuration saved")
                        .font(.subheadline)
                    TextField("https://your-server.example/feedback", text: $endpoint)
                        .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                        .accessibilityLabel("Feedback server URL")
                    SecureField("Server access token", text: $token)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Save configuration") { save() }
                        .frame(minHeight: 44)
                    if !savedEndpoint.isEmpty {
                        Button("Remove configuration", role: .destructive) {
                            do {
                                try FeedbackConfiguration.saveToken("")
                                savedEndpoint = ""; endpoint = ""; token = ""
                                succeeded = true
                                message = "Configuration removed."
                            } catch { succeeded = false; message = error.localizedDescription }
                        }.frame(minHeight: 44)
                    }
                    if let message {
                        Label(message, systemImage: succeeded ? "checkmark.circle" : "exclamationmark.circle")
                            .font(.footnote).foregroundStyle(succeeded ? SprintTheme.teal : .orange)
                    }
                } header: { Text("Optional AI coaching") } footer: {
                    Text("Use your own feedback server and its access token. Never enter an OpenAI API key here. Your token is stored in Keychain. Saving configuration does not test server connectivity.")
                }
                Section("What gets shared") {
                    Label("You choose when to send", systemImage: "hand.raised")
                    Text("AI feedback asks for confirmation before sending up to 14 frames and measured angle summaries to your configured server and OpenAI. Timing and local pose analysis do not send your footage.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Section("About the measurements") {
                    Text("Motion timing is experimental and has not been calibrated against race timing equipment. Angles are 2D estimates from a side view and depend on camera placement and landmark visibility.")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .scrollContentBackground(.hidden).background(SprintTheme.background)
            .toolbar(.hidden, for: .navigationBar)
            .onAppear { endpoint = savedEndpoint; token = FeedbackConfiguration.token }
        }
    }

    private func save() {
        do {
            let url = try FeedbackConfiguration.endpoint(from: endpoint)
            guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw FeedbackConfiguration.ConfigurationError.missing
            }
            try FeedbackConfiguration.saveToken(token.trimmingCharacters(in: .whitespacesAndNewlines))
            savedEndpoint = url.absoluteString
            succeeded = true
            message = "Configuration saved."
        } catch { succeeded = false; message = error.localizedDescription }
    }
}
