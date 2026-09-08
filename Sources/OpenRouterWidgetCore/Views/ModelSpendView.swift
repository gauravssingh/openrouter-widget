import SwiftUI

/// "Top models" — spend by model over the 30-day window, descending.
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
                Text("No model usage recorded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(models) { model in
                    HStack(alignment: .firstTextBaseline) {
                        Text(model.displayName)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(model.model == "_other" ? .secondary : .primary)
                            .help(model.model == "_other" ? "All other models" : model.model)
                        Spacer()
                        Text(CurrencyFormatter.string(from: model.amount))
                            .monospacedDigit()
                            .foregroundStyle(model.model == "_other" ? .secondary : .primary)
                    }
                    .font(.callout)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(
                        "\(model.displayName) spend \(CurrencyFormatter.string(from: model.amount))"
                    )
                }
            }
        }
    }
}
