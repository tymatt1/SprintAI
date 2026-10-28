import Foundation
import Security

/// User-entered development credentials stay in Keychain, never in source or UserDefaults.
struct FeedbackConfiguration {
    static let endpointKey = "feedbackEndpoint"
    private static let service = "com.sprintai.feedback"

    static var token: String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "accessToken",
            kSecReturnData as String: true
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return "" }
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func saveToken(_ token: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "accessToken"
        ]
        if token.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw ConfigurationError.keychain }
            return
        }
        let data = Data(token.utf8)
        var status = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            status = SecItemAdd(item as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw ConfigurationError.keychain }
    }

    static func endpoint(from value: String) throws -> URL {
        guard let url = URL(string: value.trimmingCharacters(in: .whitespacesAndNewlines)),
              let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil,
              url.scheme == "https" || (url.scheme == "http" && ["localhost", "127.0.0.1", "::1"].contains(host)) else {
            throw ConfigurationError.endpoint
        }
        return url
    }

    enum ConfigurationError: LocalizedError {
        case endpoint, keychain, missing
        var errorDescription: String? {
            switch self {
            case .endpoint: return "Enter an HTTPS feedback endpoint. HTTP is allowed only on localhost for development."
            case .keychain: return "The access token could not be saved securely."
            case .missing: return "Configure your feedback server and access token in Settings first."
            }
        }
    }
}
