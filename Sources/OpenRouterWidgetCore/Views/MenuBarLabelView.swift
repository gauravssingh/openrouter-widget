import SwiftUI

/// Menu-bar label: `OR $42.18` when a balance is known, otherwise `OR`.
public struct MenuBarLabelView: View {
    @EnvironmentObject private var appState: AppState

    public init() {}

    public var body: some View {
        Text(appState.menuBarTitle)
            .font(.system(size: 12, weight: .medium))
            .monospacedDigit()
            .accessibilityLabel("OpenRouter: \(appState.menuBarTitle)")
            .task {
                // The label is always materialized, so the app boots here:
                // load cached data, refresh, and arm the auto-refresh timer.
                appState.start()
            }
    }
}
