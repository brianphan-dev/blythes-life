import SwiftUI

// MARK: - Spacing & Layout

/// Canonical 4pt spacing scale and layout constants from `tokens/spacing.css`.
public enum BLSpacing {
    public static let space1: CGFloat = 4
    public static let space2: CGFloat = 8
    public static let space3: CGFloat = 12
    public static let space4: CGFloat = 16
    public static let space5: CGFloat = 20
    public static let space6: CGFloat = 24
    public static let space8: CGFloat = 32
    public static let space10: CGFloat = 40
    public static let space12: CGFloat = 48

    public static let screenGutter: CGFloat = 16
    public static let tabBarHeight: CGFloat = 56
    public static let borderWidth: CGFloat = 1
}

// MARK: - Corner Radii

/// Crisp corner radii from `tokens/spacing.css` (no pills; even switches are squared).
public enum BLRadius {
    /// Badges, checkboxes, small event icons (6pt).
    public static let xs: CGFloat = 6
    /// Chips, small buttons, medium event icons (8pt).
    public static let sm: CGFloat = 8
    /// Cards, tiles, buttons, inputs, toasts (12pt).
    public static let md: CGFloat = 12
    /// Hero NapCard, NursingTimer side cards (16pt).
    public static let lg: CGFloat = 16
    /// Sheet top corners only (24pt).
    public static let xl: CGFloat = 24
}

// MARK: - Hit Targets

/// Touch target sizing tokens from `tokens/spacing.css`.
public enum BLHitTarget {
    /// Minimum tappable height (44pt).
    public static let min: CGFloat = 44
    /// Quick tiles and large icon buttons (56pt).
    public static let comfy: CGFloat = 56
    /// Primary commit buttons and nap hero button (60pt).
    public static let sleepy: CGFloat = 60
}

// MARK: - Motion

/// Quiet, non-bouncy motion tokens from `tokens/motion.css`, honoring Reduce Motion.
public enum BLMotion {
    /// Press states and fast color transitions (120ms).
    public static let fast: Double = 0.12
    /// Switches, toasts, and NapCard theme transitions (200ms).
    public static let base: Double = 0.20
    /// Sheet slide transitions (360ms).
    public static let sheet: Double = 0.36

    /// Standard ease-out curve `cubic-bezier(0.2, 0.7, 0.3, 1.0)`.
    public static func easeOut(
        duration: Double = BLMotion.fast,
        reducedMotion: Bool = false
    ) -> Animation? {
        reducedMotion ? nil : .timingCurve(0.2, 0.7, 0.3, 1.0, duration: duration)
    }

    /// Sheet presentation curve `cubic-bezier(0.2, 0.85, 0.25, 1.0)`.
    public static func easeSheet(reducedMotion: Bool = false) -> Animation? {
        reducedMotion ? nil : .timingCurve(0.2, 0.85, 0.25, 1.0, duration: sheet)
    }
}

// MARK: - Event Kinds

/// The nine canonical daily-log event kinds with display names and SF Symbol mappings.
public enum BLEventKind: String, CaseIterable, Sendable, Hashable, Identifiable {
    case sleep
    case feeding
    case nursing
    case pump
    case diaper
    case meal
    case bath
    case medicine
    case note

    public var id: String { rawValue }

    /// Full sentence-case label matching `EVENT_TYPES` in the design system.
    public var displayLabel: String {
        switch self {
        case .sleep: "Sleep"
        case .feeding: "Bottle"
        case .nursing: "Nursing"
        case .pump: "Pump"
        case .diaper: "Diaper"
        case .meal: "Meal"
        case .bath: "Bath"
        case .medicine: "Meds & care"
        case .note: "Note"
        }
    }

    /// Short label for compact quick-log tiles (e.g. "Meds" on Today dock).
    public var compactLabel: String {
        switch self {
        case .medicine: "Meds"
        default: displayLabel
        }
    }

    /// Standard SF Symbol name available on iOS 18+ and macOS 14+.
    public var symbolName: String {
        switch self {
        case .sleep: "moon"
        case .feeding: "waterbottle"
        case .nursing: "figure.and.child.holdinghands"
        case .pump: "flask"
        case .diaper: "humidity"
        case .meal: "fork.knife"
        case .bath: "bathtub"
        case .medicine: "pill"
        case .note: "note.text"
        }
    }
}

// MARK: - Standard UI Symbols

/// Standard SF Symbols matching the design system's bare UI chrome iconography.
public enum BLSymbol {
    public static let sun = "sun.max"
    public static let moon = "moon"
    public static let calendar = "calendar"
    public static let scan = "doc.text.viewfinder"
    public static let settings = "gearshape"
    public static let check = "checkmark"
    public static let close = "xmark"
    public static let chevronRight = "chevron.right"
    public static let warning = "exclamationmark.triangle"
    public static let clock = "clock"
    public static let photo = "photo"
    public static let trash = "trash"
    public static let play = "play"
    public static let pause = "pause"
    public static let importFile = "arrow.down.circle"
    public static let exportFile = "square.and.arrow.up"
    public static let document = "doc.text"
    public static let bolt = "bolt"
    public static let members = "person.2"
    public static let inviteKey = "key"
}
