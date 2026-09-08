import AppKit
import SwiftUI

/// The primary popover: balance hero, spend rows, 30-day chart, top models,
/// refresh status, settings, quit.
public struct MainPopoverView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.openSettings) private var openSettings

    @State private var settingsRowHovering = false
    @State private var quitRowHovering = false

    public init() {}

    public var body: some View {
        Group {
            if !appState.hasStoredKey {
                SetupView()
            } else {
                content
            }
        }
        .frame(width: LayoutTokens.popoverWidth)
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
        VStack(alignment: .leading, spacing: LayoutTokens.sectionSpacing) {
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

            footer
        }
        .padding(LayoutTokens.popoverPadding)
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
        // Exact account-wide local-period spend from analytics when the key
        // provides it; otherwise the honest per-key fallbacks with a caption.
        if let account = snapshot.accountSpend {
            return AnyView(
                UsageSummaryView(today: account.today, week: account.week, month: account.month, footnote: nil)
            )
        }

        let breakdown = appState.spendBreakdown
        let footnote: String? = breakdown != nil ? nil : "Key usage · UTC periods"

        return AnyView(
            UsageSummaryView(
                today: key.totalDailyUsage,
                week: breakdown?.week ?? key.totalWeeklyUsage,
                month: breakdown?.month ?? key.totalMonthlyUsage,
                footnote: footnote
            )
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
                openSettingsWindow()
            }
            .buttonStyle(.borderless)
            .font(.callout)
            .accessibilityLabel("Open settings")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Loading / error

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView()
                .controlSize(.regular)
            Text("Loading your OpenRouter usage…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(32)
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
                .keyboardShortcut("r", modifiers: .command)
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
                .padding(.top, 2)

            quitRow
        }
    }

    private var statusRow: some View {
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            HStack(alignment: .center) {
                if appState.isRefreshing {
                    Text("Refreshing…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if let error = appState.lastRefreshError, appState.snapshot != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        Text("\(appState.updatedAgoText ?? "Updated") · Unable to refresh")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .help(error)
                    .accessibilityLabel("\(appState.updatedAgoText ?? "Updated"), unable to refresh: \(error)")
                } else if let updated = appState.updatedAgoText {
                    Text(updated)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .help(updated)
                } else {
                    Text("Never updated")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }

                Spacer()

                RefreshButton(isRefreshing: appState.isRefreshing) {
                    Task { await appState.refresh() }
                }
            }
        }
    }

    private var settingsRow: some View {
        Button {
            openSettingsWindow()
        } label: {
            HStack {
                Text("Settings")
                    .font(.callout)
                    .foregroundStyle(.primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 5)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
            .background {
                if settingsRowHovering {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.06))
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -6)
        .onHover { settingsRowHovering = $0 }
        .accessibilityLabel("Open settings")
    }

    private var quitRow: some View {
        Button {
            NSApp.terminate(nil)
        } label: {
            HStack {
                Text("Quit OpenRouter Widget")
                    .font(.caption)
                    .foregroundStyle(quitRowHovering ? .primary : .secondary)
                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 6)
            .contentShape(Rectangle())
            .background {
                if quitRowHovering {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.primary.opacity(0.06))
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, -6)
        .onHover { quitRowHovering = $0 }
        .accessibilityLabel("Quit OpenRouter Widget")
    }

    /// Opens the Settings window reliably. Accessory (menu-bar-only) apps
    /// are never automatically active, and SwiftUI's `openSettings` opens
    /// the window *behind* other apps unless the process is activated first.
    private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openSettings()
        // Belt-and-braces for OS builds where the SwiftUI action is a no-op
        // in accessory apps: nudge the underlying responder chain.
        DispatchQueue.main.async {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    private var snapshotWarning: UsageWarning? {
        guard let snapshot = appState.snapshot else { return nil }
        // Surface only actionable data warnings, not management-required
        // (already shown in the content area).
        return snapshot.warnings.first { warning in
            switch warning {
            case .managementKeyRequired: return false
            case .creditsUnavailable, .activityUnavailable, .spendUnavailable: return true
            }
        }
    }
}

/// Subtle circular refresh control with a clear hover state and a smooth
/// rotation while a refresh is in flight. Its footprint never changes, so the
/// popover layout stays stable.
private struct RefreshButton: View {
    let isRefreshing: Bool
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.clockwise")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(hovering ? .primary : .secondary)
                .rotationEffect(isRefreshing ? .degrees(360) : .zero)
                .animation(
                    isRefreshing
                        ? .linear(duration: 0.85).repeatForever(autoreverses: false)
                        : .default,
                    value: isRefreshing
                )
                .frame(width: 24, height: 24)
                .background {
                    if hovering {
                        Circle().fill(Color.primary.opacity(0.08))
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(isRefreshing)
        .keyboardShortcut("r", modifiers: .command)
        .accessibilityLabel("Refresh usage")
        .help("Refresh usage (⌘R)")
        .onHover { hovering = $0 }
    }
}
