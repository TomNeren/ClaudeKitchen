import Foundation
import Security

/// The Anthropic API key, kept only in the Keychain of this device (never in the repository or in UserDefaults).
enum APIKeyStore {
    private static let service = "com.tomren.claudekitchen.anthropic"
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

    /// Whether a key is stored, without reading the secret itself.
    static var hasKey: Bool {
        SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess
    }

    /// Saves `key`, updating an existing entry in place so a failed write never loses the old key.
    /// Readable only while the device is unlocked, never synced.
    @discardableResult
    static func save(_ key: String) -> Bool {
        let data = Data(key.utf8)
        let update = SecItemUpdate(query as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if update == errSecSuccess { return true }
        guard update == errSecItemNotFound else { return false }
        var item = query
        item[kSecValueData as String] = data
        item[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
    }

    static func delete() {
        SecItemDelete(query as CFDictionary)
    }
}
