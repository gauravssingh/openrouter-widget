import Foundation

public enum CredentialStoreError: Error, Equatable, Sendable {
    /// The underlying security framework returned an unexpected status.
    case keychain(OSStatus)
}

/// Storage abstraction for the OpenRouter API key. Concrete implementations
/// may use the macOS Keychain, in-memory storage (tests/previews), etc.
public protocol CredentialStore: Sendable {
    func saveAPIKey(_ key: String) throws
    func loadAPIKey() throws -> String?
    func deleteAPIKey() throws
}

/// In-memory implementation used by unit tests and SwiftUI previews.
public final class InMemoryCredentialStore: CredentialStore, @unchecked Sendable {
    private let lock = NSLock()
    private var key: String?

    public init(key: String? = nil) {
        self.key = key
    }

    public func saveAPIKey(_ key: String) throws {
        lock.lock(); defer { lock.unlock() }
        self.key = key
    }

    public func loadAPIKey() throws -> String? {
        lock.lock(); defer { lock.unlock() }
        return key
    }

    public func deleteAPIKey() throws {
        lock.lock(); defer { lock.unlock() }
        key = nil
    }
}
