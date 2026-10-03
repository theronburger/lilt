import Foundation
import Security

// No automatic operation may display a Keychain authorization dialog.
// Only the explicit Unlock / Save / Remove actions are interactive.
@MainActor
enum FilterKeyStore {
    enum State { case missing, saved, locked }
    private static var unlocked: [String: String] = [:]

    static func account(_ endpoint: String) -> String {
        guard let url = URLComponents(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.scheme == "https", let host = url.host, url.user == nil, url.password == nil else { return endpoint }
        return "https://" + host.lowercased() + (url.port.map { ":\($0)" } ?? "")
    }
    private static func query(_ account: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: (Bundle.main.bundleIdentifier ?? "app.lilt.reader.dev") + ".ai-filter",
         kSecAttrAccount as String: account]
    }
    private static func accounts(_ endpoint: String) -> [String] {
        account(endpoint) == endpoint ? [endpoint] : [account(endpoint), endpoint]
    }
    static func state(_ endpoint: String) -> State {
        for name in accounts(endpoint) {
            var attributes = query(name)
            attributes[kSecReturnAttributes as String] = true
            attributes[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUIFail
            attributes[kSecMatchLimit as String] = kSecMatchLimitOne
            let status = SecItemCopyMatching(attributes as CFDictionary, nil)
            if status == errSecSuccess { return .saved }
            if status != errSecItemNotFound { return .locked }
        }
        return .missing
    }
    static func read(_ endpoint: String, allowInteraction: Bool = false) throws -> String? {
        let origin = account(endpoint)
        if let key = unlocked[origin] { return key }
        for name in accounts(endpoint) {
            var item = query(name)
            item[kSecReturnData as String] = true
            item[kSecMatchLimit as String] = kSecMatchLimitOne
            item[kSecUseAuthenticationUI as String] = allowInteraction ? kSecUseAuthenticationUIAllow : kSecUseAuthenticationUIFail
            var result: CFTypeRef?
            let status = SecItemCopyMatching(item as CFDictionary, &result)
            if status == errSecItemNotFound { continue }
            guard status == errSecSuccess, let data = result as? Data,
                  let key = String(data: data, encoding: .utf8) else { throw FilterError.keyLocked }
            unlocked[origin] = key
            return key
        }
        return nil
    }
    static func save(_ key: String, endpoint: String) throws {
        let item = query(account(endpoint))
        let data = Data(key.utf8)
        let updated = SecItemUpdate(item as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if updated != errSecSuccess {
            guard updated == errSecItemNotFound else { throw FilterError.keychain }
            var added = item
            added[kSecValueData as String] = data
            added[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            guard SecItemAdd(added as CFDictionary, nil) == errSecSuccess else { throw FilterError.keychain }
        }
        unlocked[account(endpoint)] = key
    }
    static func remove(_ endpoint: String) throws {
        for name in accounts(endpoint) {
            let status = SecItemDelete(query(name) as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else { throw FilterError.keychain }
        }
        unlocked.removeValue(forKey: account(endpoint))
    }
}
