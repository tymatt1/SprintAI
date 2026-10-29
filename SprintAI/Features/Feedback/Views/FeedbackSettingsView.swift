import SwiftUI

struct FeedbackSettingsView: View {
    @AppStorage(FeedbackConfiguration.endpointKey) private var savedEndpoint = ""
    @State private var endpoint = ""
    @State private var token = ""
    @State private var message: String?
    @State private var showRemoval = false
    @FocusState private var focused: Field?
    private enum Field { case endpoint, token }

    var body: some View {
        Workspace { width, wide in
            VStack(alignment: .leading, spacing: 32) {
                Masthead {
                    if !savedEndpoint.isEmpty {
                        Menu {
                            Button("Remove server configuration", systemImage: "trash", role: .destructive) { showRemoval = true }
                        } label: { Image(systemName: "ellipsis").font(SprintType.label).frame(width: 44, height: 44) }
                            .tint(SprintTheme.ink).accessibilityLabel("Settings options")
                    }
                }
                Text("Settings").font(SprintType.display(48)).accessibilityAddTraits(.isHeader)
                if wide {
                    HStack(alignment: .top, spacing: 80) {
                        configuration.frame(width: (width - 80) * 0.6)
                        details.frame(maxWidth: .infinity, alignment: .leading)
                    }
                } else {
                    configuration
                    details.padding(.top, 16)
                }
            }
        }
        .onAppear { endpoint = savedEndpoint; token = FeedbackConfiguration.token }
        .confirmationDialog("Remove server configuration?", isPresented: $showRemoval, titleVisibility: .visible) {
            Button("Remove configuration", role: .destructive) {
                do {
                    try FeedbackConfiguration.saveToken("")
                    savedEndpoint = ""; endpoint = ""; token = ""
                    message = "Configuration removed."
                } catch { message = error.localizedDescription }
            }
        }
    }

    private var configuration: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Feedback server").font(SprintType.section).accessibilityAddTraits(.isHeader)
            }
            VStack(alignment: .leading, spacing: 8) {
                FieldCaption("Endpoint")
                TextField("Feedback server URL", text: $endpoint, prompt: Text("https://your-server.example/feedback").foregroundStyle(SprintTheme.muted))
                    .font(SprintType.body).textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
                    .textContentType(.URL).focused($focused, equals: .endpoint).submitLabel(.next)
                    .onSubmit { focused = .token }.padding(.vertical, 12).overlay(alignment: .bottom) { Hairline() }
                    .accessibilityLabel("Feedback server URL")
            }
            VStack(alignment: .leading, spacing: 8) {
                FieldCaption("Access token")
                SecureField("Server access token", text: $token, prompt: Text("Server token").foregroundStyle(SprintTheme.muted))
                    .font(SprintType.body).textInputAutocapitalization(.never).autocorrectionDisabled()
                    .focused($focused, equals: .token).submitLabel(.done).onSubmit { save() }
                    .padding(.vertical, 12).overlay(alignment: .bottom) { Hairline() }
                    .accessibilityLabel("Server access token")
            }
            Button("Save configuration") { save() }.buttonStyle(PrimaryActionStyle())
            if let message { Text(message).font(SprintType.detail).foregroundStyle(SprintTheme.accent) }
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 28) {
            DisclosureGroup {
                Text("Use your server token, not an OpenAI API key. Tokens are stored in Keychain; saving does not test connectivity. AI feedback asks before sending up to 14 frames and angle summaries to your server and OpenAI. Timing and local pose analysis do not send footage.")
                    .font(SprintType.detail).foregroundStyle(SprintTheme.muted).padding(.top, 10)
            } label: { Text("Data & privacy").font(SprintType.label) }
            DisclosureGroup {
                Text("Motion timing is not calibrated against race timing equipment. Pose angles are 2D estimates affected by camera position and visibility.")
                    .font(SprintType.detail).foregroundStyle(SprintTheme.muted).padding(.top, 10)
            } label: { Text("Measurement limits").font(SprintType.label) }
        }.tint(SprintTheme.ink)
    }

    private func save() {
        do {
            let url = try FeedbackConfiguration.endpoint(from: endpoint)
            guard !token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw FeedbackConfiguration.ConfigurationError.missing }
            try FeedbackConfiguration.saveToken(token.trimmingCharacters(in: .whitespacesAndNewlines))
            savedEndpoint = url.absoluteString
            focused = nil
            message = "Configuration saved."
        } catch { message = error.localizedDescription }
    }
}
