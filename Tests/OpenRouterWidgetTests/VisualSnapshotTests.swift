import AppKit
import Foundation
import OpenRouterWidgetCore
import SwiftUI
import XCTest

@MainActor
final class VisualSnapshotTests: XCTestCase {
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    private func fixtureData(_ name: String) throws -> Data {
        let url = Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "Fixtures"
        )
        return try Data(contentsOf: XCTUnwrap(url, "Missing fixture \(name).json"))
    }

    private func makeRichSnapshot() throws -> UsageSnapshot {
        let key = try decoder.decode(KeyInfoResponse.self, from: fixtureData("key")).data
        let credits = Credits(totalCredits: 30.00, totalUsage: 8.91) // 30 - 8.91 = $21.09
        let accountSpend = AccountSpend(today: 0.00, week: 1.25, month: 5.53)

        // Build 30 days of realistic activity items relative to today
        let calendar = Calendar.current
        let now = Date()
        var activity: [ActivityItem] = []

        // Model amounts that sum to $5.88:
        // Gemini 3.8 Flash: $2.82
        // DeepSeek V4 Flash 0731: $2.51
        // GLM 5.3 Flash: $0.45
        // GLM 5.3: $0.07
        // Other (e.g. Claude 3 Haiku $0.02 + Mistral $0.01 = $0.03)
        let sampleDays: [(daysAgo: Int, model: String, provider: String, usage: Double)] = [
            (1, "google/gemini-3.8-flash", "Google", 1.20),
            (2, "deepseek/deepseek-v4-flash-0731", "DeepSeek", 1.10),
            (3, "google/gemini-3.8-flash", "Google", 0.82),
            (5, "deepseek/deepseek-v4-flash-0731", "DeepSeek", 0.91),
            (7, "z-ai/glm-5.3-flash", "Zhipu", 0.35),
            (9, "deepseek/deepseek-v4-flash-0731", "DeepSeek", 0.50),
            (12, "google/gemini-3.8-flash", "Google", 0.80),
            (15, "z-ai/glm-5.3-flash", "Zhipu", 0.10),
            (18, "z-ai/glm-5.3", "Zhipu", 0.07),
            (22, "anthropic/claude-3-haiku", "Anthropic", 0.02),
            (25, "mistralai/mistral-7b-instruct", "Mistral", 0.01)
        ]

        for (idx, sample) in sampleDays.enumerated() {
            guard let date = calendar.date(byAdding: .day, value: -sample.daysAgo, to: now) else { continue }
            let dayLabel = DateHelpers.dayLabel(for: date, timeZone: .current)
            activity.append(
                ActivityItem(
                    date: dayLabel,
                    model: sample.model,
                    modelPermaslug: nil,
                    endpointId: "ep\(idx)",
                    providerName: sample.provider,
                    usage: sample.usage,
                    byokUsageInference: 0,
                    requests: 5,
                    promptTokens: 100,
                    completionTokens: 100,
                    reasoningTokens: 0
                )
            )
        }

        return UsageSnapshot(
            capturedAt: Date().addingTimeInterval(-45), // "just now"
            key: key,
            credits: credits,
            activity: activity,
            accountSpend: accountSpend,
            warnings: []
        )
    }

    private func renderAndSave<V: View>(_ view: V, width: CGFloat = LayoutTokens.popoverWidth, colorScheme: ColorScheme, filename: String) {
        let themedView = view
            .environment(\.colorScheme, colorScheme)
            .preferredColorScheme(colorScheme)
            .background(colorScheme == .dark ? Color(nsColor: .windowBackgroundColor) : Color(nsColor: .windowBackgroundColor))

        let hostingView = NSHostingView(rootView: themedView)
        hostingView.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)

        let targetSize = hostingView.fittingSize
        let size = NSSize(width: width, height: targetSize.height)
        hostingView.frame = NSRect(origin: .zero, size: size)
        hostingView.layoutSubtreeIfNeeded()

        guard let rep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            XCTFail("Failed to create bitmap rep")
            return
        }
        hostingView.cacheDisplay(in: hostingView.bounds, to: rep)

        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            XCTFail("Failed to convert to PNG")
            return
        }

        let outputDir = "/tmp/openrouter_ui_validation"
        try? FileManager.default.createDirectory(atPath: outputDir, withIntermediateDirectories: true)
        let filePath = "\(outputDir)/\(filename).png"
        try? pngData.write(to: URL(fileURLWithPath: filePath))
        print("📸 Saved snapshot: \(filePath) (\(Int(size.width))x\(Int(size.height)))")
    }

    func testRenderRichDataDark() throws {
        let snapshot = try makeRichSnapshot()
        let appState = AppState.preview(snapshot: snapshot)
        let view = MainPopoverView().environmentObject(appState)
        renderAndSave(view, colorScheme: .dark, filename: "01_rich_data_dark")
    }

    func testRenderRichDataLight() throws {
        let snapshot = try makeRichSnapshot()
        let appState = AppState.preview(snapshot: snapshot)
        let view = MainPopoverView().environmentObject(appState)
        renderAndSave(view, colorScheme: .light, filename: "02_rich_data_light")
    }

    func testRenderZeroActivity() throws {
        let key = try decoder.decode(KeyInfoResponse.self, from: fixtureData("key")).data
        let credits = try decoder.decode(CreditsResponse.self, from: fixtureData("credits")).data
        let emptySnapshot = UsageSnapshot(
            capturedAt: Date().addingTimeInterval(-30),
            key: key,
            credits: credits,
            activity: [],
            accountSpend: AccountSpend(today: 0, week: 0, month: 0),
            warnings: []
        )
        let appState = AppState.preview(snapshot: emptySnapshot)
        let view = MainPopoverView().environmentObject(appState)
        renderAndSave(view, colorScheme: .dark, filename: "03_zero_activity_dark")
    }

    func testRenderLongModelNames() throws {
        let key = try decoder.decode(KeyInfoResponse.self, from: fixtureData("key")).data
        let credits = try decoder.decode(CreditsResponse.self, from: fixtureData("credits")).data

        let today = DateHelpers.dayLabel(for: Date().addingTimeInterval(-86400), timeZone: .current)
        let longModels = [
            ActivityItem(
                date: today,
                model: "google/gemini-3.8-flash-preview-ultra-long-slug-identifier-variant",
                modelPermaslug: nil,
                endpointId: "ep1",
                providerName: "Google",
                usage: 12.34,
                byokUsageInference: 0,
                requests: 10,
                promptTokens: 100,
                completionTokens: 100,
                reasoningTokens: 0
            ),
            ActivityItem(
                date: today,
                model: "deepseek/deepseek-v4-flash-0731-thinking-mode-high-precision",
                modelPermaslug: nil,
                endpointId: "ep2",
                providerName: "DeepSeek",
                usage: 5.67,
                byokUsageInference: 0,
                requests: 5,
                promptTokens: 50,
                completionTokens: 50,
                reasoningTokens: 0
            ),
            ActivityItem(
                date: today,
                model: "anthropic/claude-sonnet-4.5-extended-context-window",
                modelPermaslug: nil,
                endpointId: "ep3",
                providerName: "Anthropic",
                usage: 1.89,
                byokUsageInference: 0,
                requests: 2,
                promptTokens: 20,
                completionTokens: 20,
                reasoningTokens: 0
            )
        ]

        let snapshot = UsageSnapshot(
            capturedAt: Date().addingTimeInterval(-300),
            key: key,
            credits: credits,
            activity: longModels,
            accountSpend: AccountSpend(today: 1.20, week: 8.50, month: 19.90),
            warnings: []
        )
        let appState = AppState.preview(snapshot: snapshot)
        let view = MainPopoverView().environmentObject(appState)
        renderAndSave(view, colorScheme: .dark, filename: "04_long_model_names_dark")
    }

    func testRenderRefreshingState() throws {
        let snapshot = try makeRichSnapshot()
        let appState = AppState.preview(snapshot: snapshot, isRefreshing: true)
        let view = MainPopoverView().environmentObject(appState)
        renderAndSave(view, colorScheme: .dark, filename: "05_refreshing_state_dark")
    }

    func testRenderCachedError() throws {
        let snapshot = try makeRichSnapshot()
        let appState = AppState.preview(
            snapshot: snapshot,
            lastRefreshError: "The request timed out. Check your internet connection."
        )
        let view = MainPopoverView().environmentObject(appState)
        renderAndSave(view, colorScheme: .dark, filename: "06_cached_error_dark")
    }

    func testRenderSetupState() {
        let appState = AppState.preview(snapshot: nil, hasStoredKey: false)
        let view = MainPopoverView().environmentObject(appState)
        renderAndSave(view, colorScheme: .dark, filename: "07_setup_state_dark")
    }

    func testRenderManagementRequired() throws {
        // Key is non-management
        let nonMgmtKey = KeyInfo(
            label: "sk-or-v1-inference-only",
            usage: 5.50,
            usageDaily: 0.50,
            usageWeekly: 2.10,
            usageMonthly: 5.50,
            byokUsage: 0,
            byokUsageDaily: 0,
            byokUsageWeekly: 0,
            byokUsageMonthly: 0,
            limit: 25.00,
            limitRemaining: 19.50,
            limitReset: "monthly",
            includeByokInLimit: false,
            isFreeTier: false,
            isManagementKey: false,
            isProvisioningKey: false,
            expiresAt: nil,
            creatorUserId: nil
        )
        let snapshot = UsageSnapshot(
            capturedAt: Date().addingTimeInterval(-60),
            key: nonMgmtKey,
            credits: nil,
            activity: [],
            accountSpend: nil,
            warnings: [.managementKeyRequired]
        )
        let appState = AppState.preview(snapshot: snapshot)
        let view = MainPopoverView().environmentObject(appState)
        renderAndSave(view, colorScheme: .dark, filename: "08_management_required_dark")
    }

    func testRenderSettingsView() throws {
        let snapshot = try makeRichSnapshot()
        let appState = AppState.preview(snapshot: snapshot)
        let view = SettingsView().environmentObject(appState)
        renderAndSave(view, width: 460, colorScheme: .dark, filename: "09_settings_dark")
    }

    func testRenderChartHover() throws {
        let snapshot = try makeRichSnapshot()
        let breakdown = SpendCalculator.breakdown(items: snapshot.activity)
        // Pick a non-zero day from the breakdown
        let activeDay = breakdown.dailySeries.first { $0.amount > 0 }!
        let chart = SpendChartView(
            series: breakdown.dailySeries,
            total: breakdown.last30Days,
            initialHoveredDay: activeDay,
            initialHoverLocationX: 220
        )
        .padding(LayoutTokens.popoverPadding)
        renderAndSave(chart, colorScheme: .dark, filename: "10_chart_hover_tooltip_dark")
    }
}
