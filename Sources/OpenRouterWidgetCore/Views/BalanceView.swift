import SwiftUI

/// The hero balance: the most prominent piece of information in the popover.
public struct BalanceView: View {
    private let amount: Double
    private let label: String
    private let detail: String?
    private let isAccountCredits: Bool
    private let managementRequired: Bool

    public init(
        amount: Double,
        label: String,
        detail: String? = nil,
        isAccountCredits: Bool,
        managementRequired: Bool
    ) {
        self.amount = amount
        self.label = label
        self.detail = detail
        self.isAccountCredits = isAccountCredits
        self.managementRequired = managementRequired
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(CurrencyFormatter.string(from: amount))
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(alignment: .firstTextBaseline, spacing: 0) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let detail {
                    Text("  ·  \(detail)")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                }
            }

            if managementRequired {
                Label("Account credits require a management key", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var text = "\(label): \(CurrencyFormatter.string(from: amount))"
        if let detail {
            text += ", \(detail)"
        }
        if managementRequired {
            text += ". Account credits require a management key. The amount shown is the key's remaining spending limit."
        }
        return text
    }
}
