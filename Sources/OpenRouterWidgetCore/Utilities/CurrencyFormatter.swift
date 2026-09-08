import Foundation

/// Formats monetary amounts consistently across the widget.
public enum CurrencyFormatter {
    private static let usd: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter
    }()

    /// `$42.18`. Falls back to a plain decimal string when formatting fails.
    public static func string(from amount: Double) -> String {
        guard let formatted = usd.string(from: NSNumber(value: amount)) else {
            return String(format: "$%.2f", amount)
        }
        return formatted
    }

    /// Compact form used in the menu-bar title: `$42.18` / `$0.99` / `$1,234.56`.
    public static func compact(from amount: Double) -> String {
        string(from: amount)
    }
}
