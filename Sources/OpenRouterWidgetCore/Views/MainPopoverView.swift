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

            Divider()

            summaryRows(snapshot)

            Divider()

            if let breakdown = appState.spendBreakdown {
                SpendChartView(series: breakdown.dailySeries, total: breakdown.last30Days)
                    .padding(.vertical, 2)

                ModelSpendView(models: breakdown.topModels)
            } else {
                activityUnavailableNote(snapshot)
            }

            Spacer(minLength: 4)

            Divider()

            footer
            
            HStack {
                Button {
                    openSettings()
                } label: {
                    Text("Settings…")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Open settings")

                Spacer()

                Button("Quit OpenRouter Widget") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderless)
            }
            .font(.callout)
            .foregroundStyle(.secondary)
        }
        .padding(16)
    }

    /// Secondary context under the hero number, e.g.
    /// "Used $79.41 of $100.50" — keeps the semantics of the balance
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
        let footnote: String? = {
            if breakdown != nil {
                return nil
            }
            return "Key usage · UTC periods"
        }()

        return UsageSummaryView(
            today: key.totalDailyUsage,
            week: breakdown?.week ?? key.totalWeeklyUsage,
            month: breakdown?.month ?? key.totalMonthlyUsage,
            footnote: footnote
        )
    }

    private func activityUnavailableNote(_ snapshot: UsageSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(
                "Spend history and top models require a management key.",
                systemImage: "lock"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
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
        TimelineView(.periodic(from: .now, by: 30)) { _ in
            VStack(alignment: .leading, spacing: 8) {
                if let warning = snapshotWarning {
                    Label(warning.message, systemImage: "exclamationmark.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(alignment: .center) {
                    if let updated = appState.updatedAgoText {
                        HStack(spacing: 4) {
                            Text(updated)
                            if appState.lastRefreshError != nil {
                                Text("·")
                                    .foregroundStyle(.tertiary)
                                Text("Could not refresh")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .help(appState.lastRefreshError ?? updated)
                    }
                    Spacer()
                    Button {
                        Task { await appState.refresh() }
                    } label: {
                        if appState.isRefreshing {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.borderless)
                    .keyboardShortcut("r")
                    .disabled(appState.isRefreshing)
                    .accessibilityLabel("Refresh now")
                    .help("Refresh now (⌘R)")
                }
            }
        }
    }

    private var snapshotWarning: UsageWarning? {
        guard let snapshot = appState.snapshot else { return nil }
        // Surface only actionable data warnings, not management-required
        // (already shown in the balance area).
        return snapshot.warnings.first { warning in
            switch warning {
            case .managementKeyRequired: return false
            case .creditsUnavailable, .activityUnavailable: return true
            }
        }
    }
}
