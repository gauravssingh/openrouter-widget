import AppKit
import OpenRouterWidgetCore
import SwiftUI

@main
struct OpenRouterWidgetApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MainPopoverView()
                .environmentObject(appState)
        } label: {
            MenuBarLabelView()
                .environmentObject(appState)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(appState)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu-bar utility: no Dock icon, no main window; keep running when
        // the popover closes (termination only via Quit).
        NSApp.setActivationPolicy(.accessory)

        // Guaranteed bootstrap: load cached data, run the first refresh, and
        // arm the auto-refresh timer at launch. `start()` is idempotent, so
        // the SwiftUI `.task` calls are harmless duplicates.
        Task { @MainActor in
            AppState.shared.start()
        }
    }
}
