import Foundation
import Security

public protocol KeychainStore {
    func set(secret: String, account: String) throws
    func get(account: String) throws -> String?
    func delete(account: String) throws
}

public enum KeychainAccount {
    public static func key(env: String?, name: String) -> String {
        "\(env ?? "base")/\(name)"
    }
}

public final class InMemoryKeychainStore: KeychainStore {
    private var storage: [String: String] = [:]
    public init() {}
    public func set(secret: String, account: String) throws { storage[account] = secret }
    public func get(account: String) throws -> String? { storage[account] }
    public func delete(account: String) throws { storage[account] = nil }
}

public final class SecurityKeychainStore: KeychainStore {
    private let service: String
    public init(service: String = "envswitch") { self.service = service }

    public func set(secret: String, account: String) throws {
        try delete(account: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(secret.utf8),
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else { throw EnvSwitchError.keychain("add failed: \(status)") }
    }

    public func get(account: String) throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            throw EnvSwitchError.keychain("read failed: \(status)")
        }
        return String(data: data, encoding: .utf8)
    }

    public func delete(account: String) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw EnvSwitchError.keychain("delete failed: \(status)")
        }
    }
}
