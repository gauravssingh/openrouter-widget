import Foundation
import OpenRouterWidgetCore
import XCTest

final class CredentialStoreTests: XCTestCase {
    private func makeKey(_ n: Int) -> String {
        String(repeating: "k", count: n)
    }

    func testInMemoryRoundTrip() throws {
        let store = InMemoryCredentialStore()
        XCTAssertNil(try store.loadAPIKey())

        try store.saveAPIKey(makeKey(40))
        XCTAssertEqual(try store.loadAPIKey(), makeKey(40))

        try store.deleteAPIKey()
        XCTAssertNil(try store.loadAPIKey())

        // Deleting when empty must not throw.
        try store.deleteAPIKey()
    }

    func testInMemoryOverwrites() throws {
        let store = InMemoryCredentialStore(key: "first")
        try store.saveAPIKey("second")
        XCTAssertEqual(try store.loadAPIKey(), "second")
    }

    /// Exercises the real Keychain with an isolated service name so it never
    /// touches the widget's production entry. Skipped when the host cannot
    /// reach the Keychain (e.g. sandboxed CI) — the abstraction is fully
    /// covered by the in-memory tests above.
    func testKeychainRoundTrip() throws {
        let store = KeychainCredentialStore(
            service: "dev.gsingh.openrouter-widget.tests",
            account: "test-\(UUID().uuidString)"
        )
        try store.deleteAPIKey() // clean slate

        do {
            XCTAssertNil(try store.loadAPIKey())

            let key = "sk-or-v1-\(UUID().uuidString)"
            try store.saveAPIKey(key)
            XCTAssertEqual(try store.loadAPIKey(), key)

            // Replace semantics: saving a new key overwrites the old one.
            let replacement = "sk-or-v1-\(UUID().uuidString)"
            try store.saveAPIKey(replacement)
            XCTAssertEqual(try store.loadAPIKey(), replacement)

            try store.deleteAPIKey()
            XCTAssertNil(try store.loadAPIKey())
        } catch CredentialStoreError.keychain(let status) where status == errSecInteractionNotAllowed {
            throw XCTSkip("Keychain unavailable to the test process (status \(status))")
        }
    }

    func testKeychainTrimsWhitespace() throws {
        let store = KeychainCredentialStore(
            service: "dev.gsingh.openrouter-widget.tests",
            account: "test-trim-\(UUID().uuidString)"
        )
        do {
            try store.saveAPIKey("  sk-or-v1-padded  \n")
            XCTAssertEqual(try store.loadAPIKey(), "sk-or-v1-padded")
            try store.deleteAPIKey()
        } catch CredentialStoreError.keychain(let status) where status == errSecInteractionNotAllowed {
            throw XCTSkip("Keychain unavailable to the test process (status \(status))")
        }
    }
}
