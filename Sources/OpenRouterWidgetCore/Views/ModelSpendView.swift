import SwiftUI

/// "Top models" — spend by model over the 30-day window, descending.
/// Model names own the flexible column; monetary values are protected from
/// being pushed off-screen by long names (layoutPriority + fixed trailing
/// edge). Full model slugs are available via tooltip.
public struct ModelSpendView: View {
    private let models: [ModelSpend]

    public init(models: [ModelSpend]) {
        self.models = models
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Top models")
                .font(.subheadline.weight(.semibold))

            if models.isEmpty {
                Text("No usage yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(models) { model in
                    row(model)
                }
            }
        }
    }

    private func row(_ model: ModelSpend) -> some View {
        let isOther = model.model == "_other"
        return HStack(alignment: .firstTextBaseline) {
            Text(model.displayName)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(isOther ? Color.secondary : Color.primary)
                .help(isOther ? "All other models" : model.model)
                .accessibilityLabel(
                    "\(model.displayName) spend \(CurrencyFormatter.string(from: model.amount))"
                )
            Spacer()
            Text(CurrencyFormatter.string(from: model.amount))
                .monospacedDigit()
                .fontWeight(.medium)
                .foregroundStyle(isOther ? Color.secondary : Color.primary)
                // The amount always wins space over a long model name.
                .layoutPriority(1)
        }
        .font(.callout)
        .accessibilityElement(children: .ignore)
    }
}
