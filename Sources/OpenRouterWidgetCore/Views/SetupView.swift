import SwiftUI

/// First-run screen: paste an API key, connect, learn that the key is stored
/// in the macOS Keychain.
public struct SetupView: View {
    @EnvironmentObject private var appState: AppState
    @State private var apiKey = ""
    @FocusState private var keyFieldFocused: Bool

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("OpenRouter Widget")
                    .font(.headline)
                Text("Connect your OpenRouter account to view credits and usage.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            SecureField("Paste API key", text: $apiKey)
                .textFieldStyle(.roundedBorder)
                .focused($keyFieldFocused)
                .onSubmit(connect)
                .accessibilityLabel("OpenRouter API key")

            if let error = appState.setupError {
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button("Connect") {
                    connect()
                }
                .buttonStyle(.borderedProminent)
                .disabled(apiKey.trimmingCharacters(in: .whitespaces).isEmpty || appState.isConnecting)

                if appState.isConnecting {
                    ProgressView()
                        .controlSize(.small)
                    Text("Connecting…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Your key is stored securely in the macOS Keychain. A management key is required for account credits and spend history.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 340)
        .onAppear { keyFieldFocused = true }
    }

    private func connect() {
        Task { await appState.connect(apiKey: apiKey) }
    }
}
