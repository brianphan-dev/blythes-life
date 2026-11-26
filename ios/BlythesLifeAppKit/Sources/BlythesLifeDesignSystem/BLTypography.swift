import CoreText
import SwiftUI

// MARK: - Font Availability Cache

private enum BLFontAvailability {
    static let availableFamilies: Set<String> = {
        guard let cfNames = CTFontManagerCopyAvailableFontFamilyNames() as? [String] else {
            return []
        }
        return Set(cfNames)
    }()

    static let hasNewsreader: Bool = availableFamilies.contains("Newsreader")
    static let hasIowanOldStyle: Bool = availableFamilies.contains("Iowan Old Style")
    static let hasFigtree: Bool = availableFamilies.contains("Figtree")
}

// MARK: - Font Builders

/// Display serif (`Newsreader` -> `Iowan Old Style` -> system serif) and UI sans (`Figtree` -> system sans) helpers.
public enum BLFont {
    public static let microTrackingRatio: CGFloat = 0.08
    public static let displayTrackingRatio: CGFloat = -0.015

    /// Display serif font used for screen titles, timers, and large numerals.
    public static func display(
        size: CGFloat,
        weight: Font.Weight = .regular,
        tabularNumerals: Bool = true
    ) -> Font {
        let base: Font
        if BLFontAvailability.hasNewsreader {
            base = .custom("Newsreader", size: size).weight(weight)
        } else if BLFontAvailability.hasIowanOldStyle {
            base = .custom("Iowan Old Style", size: size).weight(weight)
        } else {
            base = .system(size: size, weight: weight, design: .serif)
        }
        return tabularNumerals ? base.monospacedDigit() : base
    }

    /// UI sans font used for body text, buttons, labels, and tabular timestamps.
    public static func ui(
        size: CGFloat,
        weight: Font.Weight = .regular,
        tabularNumerals: Bool = false
    ) -> Font {
        let base: Font
        if BLFontAvailability.hasFigtree {
            base = .custom("Figtree", size: size).weight(weight)
        } else {
            base = .system(size: size, weight: weight, design: .default)
        }
        return tabularNumerals ? base.monospacedDigit() : base
    }
}

// MARK: - Semantic Text Roles

/// The eight canonical composite type roles from `tokens/typography.css`.
public enum BLTextRole: Sendable, Hashable {
    /// 56pt regular display serif, 1.0 line height, tabular numerals.
    case timer
    /// 34pt medium display serif, 40pt line height, `-0.015em` tracking.
    case display
    /// 24pt medium display serif, 30pt line height.
    case title
    /// 17pt semibold UI sans, 22pt line height.
    case headline
    /// 17pt regular UI sans, 24pt line height.
    case body
    /// 15pt medium UI sans, 20pt line height.
    case callout
    /// 13pt regular UI sans, 18pt line height.
    case caption
    /// 11pt semibold UI sans, 14pt line height, uppercase + `0.08em` tracking.
    case micro

    public var pointSize: CGFloat {
        switch self {
        case .timer: 56
        case .display: 34
        case .title: 24
        case .headline: 17
        case .body: 17
        case .callout: 15
        case .caption: 13
        case .micro: 11
        }
    }

    public var font: Font {
        switch self {
        case .timer:
            BLFont.display(size: 56, weight: .regular, tabularNumerals: true)
        case .display:
            BLFont.display(size: 34, weight: .medium, tabularNumerals: true)
        case .title:
            BLFont.display(size: 24, weight: .medium, tabularNumerals: false)
        case .headline:
            BLFont.ui(size: 17, weight: .semibold)
        case .body:
            BLFont.ui(size: 17, weight: .regular)
        case .callout:
            BLFont.ui(size: 15, weight: .medium)
        case .caption:
            BLFont.ui(size: 13, weight: .regular)
        case .micro:
            BLFont.ui(size: 11, weight: .semibold)
        }
    }

    public var tracking: CGFloat {
        switch self {
        case .timer:
            -0.02 * 56
        case .display:
            BLFont.displayTrackingRatio * 34
        case .micro:
            BLFont.microTrackingRatio * 11
        default:
            0
        }
    }

    public var lineSpacing: CGFloat {
        switch self {
        case .timer: 0
        case .display: 2
        case .title: 2
        case .headline: 2
        case .body: 3
        case .callout: 2
        case .caption: 2
        case .micro: 1
        }
    }
}

// MARK: - View Modifiers

private struct BLTextRoleModifier: ViewModifier {
    let role: BLTextRole

    func body(content: Content) -> some View {
        content
            .font(role.font)
            .tracking(role.tracking)
            .lineSpacing(role.lineSpacing)
            .textCase(role == .micro ? .uppercase : nil)
    }
}

private struct BLMicroLabelModifier: ViewModifier {
    @Environment(\.blTheme) private var theme
    let color: Color?

    func body(content: Content) -> some View {
        content
            .blTextRole(.micro)
            .foregroundStyle(color ?? theme.textSecondary)
    }
}

extension View {
    /// Applies one of the eight canonical Blythe's Life typographic roles.
    public func blTextRole(_ role: BLTextRole) -> some View {
        modifier(BLTextRoleModifier(role: role))
    }

    /// Styles text as a tracked uppercase paper-form micro label (`.bl-label`).
    public func blMicroLabel(color: Color? = nil) -> some View {
        modifier(BLMicroLabelModifier(color: color))
    }
}
