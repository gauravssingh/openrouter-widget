import Foundation
import os

/// Lightweight on-disk cache of the last successful snapshot so the popover
/// renders instantly after relaunch, even before the first network refresh.
/// Uses a single Codable JSON file in Application Support — no database.
public final class SnapshotCache: @unchecked Sendable {
    private let fileURL: URL?
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let queue = DispatchQueue(label: "dev.gsingh.openrouter-widget.snapshot-cache")

    public init(directory: URL? = nil) {
        let base = directory
            ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
                .appendingPathComponent("OpenRouterWidget", isDirectory: true)
        self.fileURL = base?.appendingPathComponent("last-snapshot.json")
        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func save(_ snapshot: UsageSnapshot) {
        guard let fileURL else { return }
        queue.async { [encoder, fileURL] in
            do {
                try FileManager.default.createDirectory(
                    at: fileURL.deletingLastPathComponent(),
                    withIntermediateDirectories: true
                )
                let data = try encoder.encode(snapshot)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                AppLog.app.error("Snapshot cache write failed: \(String(describing: error))")
            }
        }
    }

    public func load() -> UsageSnapshot? {
        guard let fileURL, let data = try? Data(contentsOf: fileURL) else { return nil }
        do {
            return try decoder.decode(UsageSnapshot.self, from: data)
        } catch {
            AppLog.app.error("Snapshot cache read failed: \(String(describing: error))")
            try? FileManager.default.removeItem(at: fileURL)
            return nil
        }
    }

    public func clear() {
        guard let fileURL else { return }
        queue.async { try? FileManager.default.removeItem(at: fileURL) }
    }
}
