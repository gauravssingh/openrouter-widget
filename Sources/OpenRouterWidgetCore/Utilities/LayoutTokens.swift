import Foundation

/// Shared layout tokens for consistent popover metrics.
/// Kept minimal to avoid unnecessary design-system abstractions.
public enum LayoutTokens {
    /// Standard width of the popover menu-bar window.
    public static let popoverWidth: CGFloat = 340
    /// Outer padding around popover content.
    public static let popoverPadding: CGFloat = 16
    /// Vertical spacing between major visual groups.
    public static let sectionSpacing: CGFloat = 14
    /// Vertical spacing between rows within a section (period spend, models).
    public static let rowSpacing: CGFloat = 6
    /// Height of the 30-day spend bar chart area.
    public static let chartHeight: CGFloat = 68
}
