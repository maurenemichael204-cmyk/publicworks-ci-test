import Foundation
import Security

enum KeychainStore {
    private static let service = "PublicWorks.API"
    private static let account = "bearer-token"

    static func save(_ value: String) throws {
        // 先保留旧值，新值写入失败时回滚，避免"删了旧的、没写上新的"。
        let backup = read()
        delete()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8)
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            if !backup.isEmpty {
                let restore: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrService as String: service,
                    kSecAttrAccount as String: account,
                    kSecValueData as String: Data(backup.utf8)
                ]
                SecItemAdd(restore as CFDictionary, nil)
            }
            throw NSError(domain: NSOSStatusErrorDomain, code: Int(status))
        }
    }

    static func read() -> String {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else {
            return ""
        }

        return String(decoding: data, as: UTF8.self)
    }

    static func delete() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }
}
