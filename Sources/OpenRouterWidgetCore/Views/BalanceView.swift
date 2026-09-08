import SwiftUI

/// The hero balance: the most prominent piece of information in the popover.
public struct BalanceView: View {
    private let amount: Double
    private let label: String
    private let isAccountCredits: Bool
    private let managementRequired: Bool

    public init(amount: Double, label: String, isAccountCredits: Bool, managementRequired: Bool) {
        self.amount = amount
        self.label = label
        self.isAccountCredits = isAccountCredits
        self.managementRequired = managementRequired
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(CurrencyFormatter.string(from: amount))
                .font(.system(.title, design: .rounded, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .accessibilityLabel("\(label): \(CurrencyFormatter.string(from: amount))")

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if managementRequired {
                Label("Account credits require a management key", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
                    .accessibilityLabel(
                        "Account credits require a management key. The amount shown is the key's remaining spending limit."
                    )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
