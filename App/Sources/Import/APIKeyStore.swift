import Foundation
import Security

/// The Anthropic API key, kept only in the Keychain of this device (never in the repository or in UserDefaults).
enum APIKeyStore {
    private static let service = "de.tomneren.ClaudeKitchen.anthropic"
    private static let account = "api-key"

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }

    static func load() -> String? {
        var item: CFTypeRef?
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        guard SecItemCopyMatching(request as CFDictionary, &item) == errSecSuccess, let data = item as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    static var hasKey: Bool { load() != nil }

    /// Saves `key`, replacing an earlier one. Readable only while the device is unlocked, never synced.
    @discardableResult
    static func save(_ key: String) -> Bool {
        delete()
        var item = query
        item[kSecValueData as String] = Data(key.utf8)
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
