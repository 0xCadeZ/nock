import Foundation
import Security

enum Keychain {
    static let service = "com.cade.Nock"
    private static let legacyService = "com.cade.Notch"

    static func set(_ value: String, account: String, service: String = Keychain.service) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
        var add = query
        add[kSecValueData as String] = data
        SecItemAdd(add as CFDictionary, nil)
        if service == Self.service {
            delete(account: account, service: legacyService)
        }
    }

    static func get(account: String, service: String = Keychain.service) -> String? {
        if let value = copy(account: account, service: service) {
            return value
        }
        guard service == Self.service, let legacy = copy(account: account, service: legacyService) else {
            return nil
        }
        set(legacy, account: account)
        return legacy
    }

    static func delete(account: String, service: String = Keychain.service) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func copy(account: String, service: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
