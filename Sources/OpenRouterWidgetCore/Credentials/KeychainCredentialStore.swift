import Foundation
import Security

/// Stores the OpenRouter API key in the macOS Keychain. Nothing else in the
/// app knows about Keychain specifics; everything talks to `CredentialStore`.
public final class KeychainCredentialStore: CredentialStore, @unchecked Sendable {
    private let service: String
    private let account: String

    public init(
        service: String = "dev.gsingh.openrouter-widget",
        account: String = "openrouter-api-key"
    ) {
        self.service = service
        self.account = account
    }

    public func saveAPIKey(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let data = Data(trimmed.utf8)

        var query = baseQuery()
        query[kSecValueData as String] = data
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly

        // Replace semantics: delete any existing item, then add the new one.
        SecItemDelete(baseQuery() as CFDictionary)
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            AppLog.credentials.error("Keychain save failed: \(status)")
            throw CredentialStoreError.keychain(status)
        }
        AppLog.credentials.info("API key saved to Keychain")
    }

    public func loadAPIKey() throws -> String? {
        var query = baseQuery()
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound {
            return nil
        }
        guard status == errSecSuccess else {
            AppLog.credentials.error("Keychain load failed: \(status)")
            throw CredentialStoreError.keychain(status)
        }
        guard let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public func deleteAPIKey() throws {
        let status = SecItemDelete(baseQuery() as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            AppLog.credentials.error("Keychain delete failed: \(status)")
            throw CredentialStoreError.keychain(status)
        }
        AppLog.credentials.info("API key deleted from Keychain")
    }

    private func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }
}
