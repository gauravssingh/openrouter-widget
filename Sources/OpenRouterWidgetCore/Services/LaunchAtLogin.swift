import Foundation
import ServiceManagement

/// Modern launch-at-login support via `SMAppService` (macOS 13+).
/// Only functional once the app runs from a proper `.app` bundle.
public enum LaunchAtLogin {
    public static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    public static var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled: "Enabled"
        case .notRegistered: "Disabled"
        case .requiresApproval: "Requires approval in System Settings"
        case .notFound: "Requires the packaged app"
        @unknown default: "Unknown"
        }
    }

    public static func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }
}
