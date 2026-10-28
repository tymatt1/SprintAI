import SwiftUI

struct FeedbackSettingsView: View {
    @AppStorage(FeedbackConfiguration.endpointKey) private var savedEndpoint = ""
    @State private var endpoint = ""
    @State private var token = ""
    @State private var message: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://your-server.example/feedback", text: $endpoint)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    SecureField("Access token", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button("Save configuration") { save() }
                    Button("Remove configuration", role: .destructive) {
                        do {
                            try FeedbackConfiguration.saveToken("")
                            savedEndpoint = ""
                            endpoint = ""
                            token = ""
                            message = "Configuration removed."
                        } catch { message = error.localizedDescription }
                    }
                    if let message { Text(message).font(.footnote) }
                } header: {
                    Text("AI feedback server")
                } footer: {
                    Text("Timing and pose analysis run on your device. Getting AI feedback sends up to 14 video frames and measured angle summaries to the configured server and OpenAI. Use an access token for your own server, never an OpenAI API key.")
                }
                Section("About SprintAI") {
                    Text("Automatic sprint detection and video form analysis.")
                    Text("Motion timing is experimental and has not been calibrated against race timing equipment. Angles are 2D estimates from a side view.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                endpoint = savedEndpoint
                token = FeedbackConfiguration.token
            }
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
            message = "Configuration saved."
        } catch { message = error.localizedDescription }
    }
}
