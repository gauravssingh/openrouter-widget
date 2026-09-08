import Foundation
import os

/// Central logging. Never log API keys, authorization headers, or raw
/// response payloads — only statuses, codes, and non-sensitive metadata.
public enum AppLog {
    private static let subsystem = "dev.gsingh.openrouter-widget"

    public static let api = Logger(subsystem: subsystem, category: "API")
    public static let refresh = Logger(subsystem: subsystem, category: "Refresh")
    public static let credentials = Logger(subsystem: subsystem, category: "Credentials")
    public static let app = Logger(subsystem: subsystem, category: "App")
}
