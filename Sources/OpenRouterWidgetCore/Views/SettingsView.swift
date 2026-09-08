import SwiftUI

/// Settings window: OpenRouter key management, refresh interval, menu-bar
/// display, launch-at-login, about.
public struct SettingsView: View {
    @EnvironmentObject private var appState: AppState

    @State private var newKey = ""
    @State private var showingReplaceKey = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchStatus = LaunchAtLogin.statusDescription

    public init() {}

    public var body: some View {
        Form {
            Section {
                connectionRow
                if showingReplaceKey {
                    replaceKeyRow
                } else {
                    Button("Replace Key…") { showingReplaceKey = true }
                }
                testConnectionRow
            } header: {
                Text("OpenRouter")
            } footer: {
                Text("The key is stored only in the macOS Keychain and is sent solely to openrouter.ai.")
            }

            Section {
                Picker("Refresh interval", selection: intervalBinding) {
                    Text("1 minute").tag(1)
                    Text("5 minutes").tag(5)
                    Text("15 minutes").tag(15)
                    Text("30 minutes").tag(30)
                    Text("1 hour").tag(60)
                    Text("Manual only").tag(0)
                }
            } header: {
                Text("Refresh")
            } footer: {
                Text("5 minutes is plenty for most accounts; more frequent polling rarely shows anything new.")
            }

            Section("Menu Bar") {
                Toggle("Show balance in menu bar", isOn: menuBarBalanceBinding)
            }

            Section {
                Toggle("Launch at Login", isOn: launchAtLoginBinding)
                Text(launchStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } header: {
                Text("Launch")
            } footer: {
                Text("Uses SMAppService. Requires the packaged app — copy OpenRouterWidget.app out of .build (e.g. to /Applications) first.")
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
                LabeledContent("Project") {
                    Link(
                        "gauravssingh/openrouter-widget",
                        destination: URL(string: "https://github.com/gauravssingh/openrouter-widget")!
                    )
                }
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 460, minHeight: 420)
    }

    // MARK: - Rows

    private var connectionRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(appState.hasStoredKey ? "Connected" : "Not connected")
                    .fontWeight(.medium)
                if let masked = appState.maskedStoredKey() {
                    Text(masked)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if let key = appState.snapshot?.key {
                    Text(key.isManagementKey ? "Management key" : "Inference key (limited data)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            Image(systemName: appState.hasStoredKey ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(appState.hasStoredKey ? .green : .secondary)
                .accessibilityLabel(appState.hasStoredKey ? "Connected" : "Not connected")
        }
    }

    private var replaceKeyRow: some View {
        HStack {
            SecureField("New API key", text: $newKey)
                .onSubmit(replaceKey)
            Button("Save") { replaceKey() }
                .disabled(newKey.trimmingCharacters(in: .whitespaces).isEmpty || appState.isConnecting)
        }
    }

    private var testConnectionRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Button("Test Connection") {
                    Task { await appState.testConnection() }
                }
                .disabled(!appState.hasStoredKey || appState.isTestingConnection)
                if appState.isTestingConnection {
                    ProgressView().controlSize(.small)
                }
            }
            if let result = appState.lastTestResult {
                Text(result)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    // MARK: - Bindings

    private var intervalBinding: Binding<Int> {
        Binding(
            get: { appState.refreshIntervalMinutes },
            set: { appState.refreshIntervalMinutes = $0 }
        )
    }

    private var menuBarBalanceBinding: Binding<Bool> {
        Binding(
            get: { appState.showBalanceInMenuBar },
            set: { appState.showBalanceInMenuBar = $0 }
        )
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { newValue in
                do {
                    try LaunchAtLogin.setEnabled(newValue)
                    launchAtLogin = newValue
                } catch {
                    launchAtLogin = LaunchAtLogin.isEnabled
                }
                launchStatus = LaunchAtLogin.statusDescription
            }
        )
    }

    // MARK: - Actions

    private func replaceKey() {
        let key = newKey
        newKey = ""
        showingReplaceKey = false
        Task {
            await appState.replaceKey(apiKey: key)
            appState.lastTestResult = appState.setupError ?? "Key updated."
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        return version ?? "1.0.0 (dev)"
    }
}
