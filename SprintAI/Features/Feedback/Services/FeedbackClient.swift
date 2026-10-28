import Foundation

/// Calls the owner's backend. OpenAI credentials never leave the server.
struct FeedbackClient {
    private struct Request: Encodable {
        let frames: [FeedbackFrame]
        let context: String?
    }
    private struct Response: Decodable { let feedback: String }

    func generate(frames: [FeedbackFrame], context: String?) async throws -> String {
        let endpoint = UserDefaults.standard.string(forKey: FeedbackConfiguration.endpointKey) ?? ""
        let token = FeedbackConfiguration.token
        guard !endpoint.isEmpty, !token.isEmpty else { throw FeedbackConfiguration.ConfigurationError.missing }
        var request = URLRequest(url: try FeedbackConfiguration.endpoint(from: endpoint))
        request.httpMethod = "POST"
        request.timeoutInterval = 180
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(Request(frames: frames, context: context))
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse else { throw FeedbackError.invalidResponse }
        guard (200..<300).contains(response.statusCode) else {
            throw FeedbackError.server(response.statusCode)
        }
        let feedback = try JSONDecoder().decode(Response.self, from: data).feedback
        guard !feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw FeedbackError.invalidResponse }
        return feedback
    }

    private enum FeedbackError: LocalizedError {
        case invalidResponse, server(Int)
        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "The feedback server returned an unreadable response."
            case .server(401): return "The feedback server rejected your access token. Check Settings."
            case .server(429): return "The feedback server is busy. Please try again later."
            case .server(let code): return "The feedback request failed (HTTP \(code))."
            }
        }
    }
}
