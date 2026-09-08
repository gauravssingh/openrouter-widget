import AppKit
import SwiftUI

/// The primary popover: balance hero, spend rows, 30-day chart, top models,
/// refresh status, settings, quit.
public struct MainPopoverView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings

    public init() {}

    public var body: some View {
        Group {
            if !appState.hasStoredKey {
                SetupView()
            } else {
                content
            }
        }
        .frame(width: 340)
        .task {
            appState.start()
        }
    }

    @ViewBuilder
    private var content: some View {
        if let snapshot = appState.snapshot {
            populatedContent(snapshot)
        } else if appState.isRefreshing {
            loadingState
        } else {
            errorState
        }
    }

    // MARK: - Populated

    private func populatedContent(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            BalanceView(
                amount: appState.balance?.amount ?? 0,
                label: appState.balance?.label ?? "Available credits",
                detail: balanceDetail(snapshot),
                isAccountCredits: appState.balance?.isAccountCredits ?? false,
                managementRequired: appState.managementPermissionsWarning != nil
                    && appState.balance?.isAccountCredits != true
            )
            .padding(.top, 2)

            summaryRows(snapshot)

            Divider()

            if let breakdown = appState.spendBreakdown {
                SpendChartView(series: breakdown.dailySeries, total: breakdown.last30Days)

                ModelSpendView(models: breakdown.topModels)
            } else {
                activityUnavailableNote
            }

            Spacer(minLength: 4)

            Divider()

            footer
        }
        .padding(16)
    }

    /// Secondary context under the hero number, e.g.
    /// "used $79.41 of $100.50" — keeps the semantics of the balance
    /// explicit and trustworthy.
    private func balanceDetail(_ snapshot: UsageSnapshot) -> String? {
        if let credits = snapshot.credits {
            return "used \(CurrencyFormatter.string(from: credits.totalUsage)) of \(CurrencyFormatter.string(from: credits.totalCredits))"
        }
        if let reset = snapshot.key.limitReset, !reset.isEmpty, snapshot.key.limit != nil {
            return "resets \(reset)"
        }
        return nil
    }

    private func summaryRows(_ snapshot: UsageSnapshot) -> some View {
        let key = snapshot.key
        let breakdown = appState.spendBreakdown
        // Week/month come from local-timezone activity computation when a
        // management key provides it; otherwise fall back to the key's own
        // UTC-period figures, clearly labeled.
        let footnote: String? = breakdown != nil ? nil : "Key usage · UTC periods"

        return UsageSummaryView(
            today: key.totalDailyUsage,
            week: breakdown?.week ?? key.totalWeeklyUsage,
            month: breakdown?.month ?? key.totalMonthlyUsage,
            footnote: footnote
        )
    }

    private var activityUnavailableNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Account data unavailable")
                .font(.subheadline.weight(.semibold))
            Text("Your OpenRouter key does not have the required permissions. A management key is needed for spend history and top models.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button("Open Settings…") {
                openSettings()
            }
            .buttonStyle(.borderless)
            .font(.callout)
            .accessibilityLabel("Open settings")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Loading / error

    private var loadingState: some View {
        VStack(spacing: 10) {
            ProgressView()
            Text("Loading your OpenRouter usage…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
    }

    private var errorState: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Unable to refresh", systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(appState.lastRefreshError ?? "An unknown error occurred.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Retry") {
                    Task { await appState.refresh() }
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("r")
                if appState.isRefreshing {
                    ProgressView().controlSize(.small)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Footer

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let warning = snapshotWarning {
                Label(warning.message, systemImage: "exclamationmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            statusRow

            settingsRow

            Divider()

            Button("Quit OpenRouter Widget") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.caption)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Quit OpenRouter Widget")
        }
    }

    private var statusRow: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    Text(statusText)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .help(statusTooltip)
                    Spacer()
                    refreshButton
                }

                if let error = appState.lastRefreshError, appState.snapshot != nil {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityHidden(true)
                        Text("Unable to refresh")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Retry") {
                            Task { await appState.refresh() }
                        }
                        .buttonStyle(.borderless)
                        .font(.caption.weight(.medium))
                        .accessibilityLabel("Retry refresh")
                    }
                    .help(error)
                }
            }
        }
    }

    private var statusText: String {
        if appState.isRefreshing { return "Refreshing…" }
        if let updated = appState.updatedAgoText { return updated }
        return "Never updated"
    }

    private var statusTooltip: String {
        if let error = appState.lastRefreshError, appState.snapshot != nil {
            return error
        }
        return statusText
    }

    private var refreshButton: some View {
        RefreshButton(isRefreshing: appState.isRefreshing) {
            Task { await appState.refresh() }
        }
    }

    private var settingsRow: some View {
        Button {
            openSettings()
        } label: {
            HStack {
                Text("Settings")
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, -8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
            .background {
                if settingsRowHovering {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.primary.opacity(0.06))
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { settingsRowHovering = $0 }
        .accessibilityLabel("Open settings")
    }

    @State private var settingsRowHovering = false

    private var snapshotWarning: UsageWarning? {
        guard let snapshot = appState.snapshot else { return nil }
        // Surface only actionable data warnings, not management-required
        // (already shown in the content area).
        return snapshot.warnings.first { warning in
            switch warning {
            case .managementKeyRequired: return false
            case .creditsUnavailable, .activityUnavailable: return true
            }
        }
    }
}

/// Subtle circular refresh control with a clear hover state and a spinner
/// while a refresh is in flight. Its footprint never changes, so the
/// popover layout stays stable.
private struct RefreshButton: View {
    let isRefreshing: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Group {
                if isRefreshing {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Image(systemName: "arrow.clockwise")
                        .font(.callout.weight(.medium))
                }
            }
            .frame(width: 24, height: 24)
            .background {
                if hovering {
                    Circle().fill(Color.primary.opacity(0.08))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isRefreshing)
        .keyboardShortcut("r")
        .accessibilityLabel("Refresh usage")
        .help("Refresh usage (⌘R)")
        .onHover { hovering = $0 }
    }
}
