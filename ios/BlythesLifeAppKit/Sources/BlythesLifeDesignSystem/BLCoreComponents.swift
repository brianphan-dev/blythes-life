import SwiftUI

// MARK: - BLButton

/// Primary, ink, secondary, ghost, and danger action button with `.97` press scale.
public struct BLButton: View {
    public enum Variant: Sendable, Hashable {
        case primary
        case ink
        case secondary
        case ghost
        case danger
    }

    public enum Size: Sendable, Hashable {
        case sm
        case md
        case lg

        var height: CGFloat {
            switch self {
            case .sm: 36
            case .md: 48
            case .lg: BLHitTarget.sleepy
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .sm: 14
            case .md: 20
            case .lg: 24
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .sm: 15
            case .md: 17
            case .lg: 19
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .sm: 14
            case .md: 17
            case .lg: 19
            }
        }

        var spacing: CGFloat {
            self == .sm ? 6 : 8
        }

        var radius: CGFloat {
            self == .sm ? BLRadius.sm : BLRadius.md
        }
    }

    private let title: String?
    private let accessibilityLabelText: String?
    private let variant: Variant
    private let size: Size
    private let isBlock: Bool
    private let icon: String?
    private let action: () -> Void

    public init(
        _ title: String,
        variant: Variant = .primary,
        size: Size = .md,
        isBlock: Bool = false,
        icon: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.accessibilityLabelText = nil
        self.variant = variant
        self.size = size
        self.isBlock = isBlock
        self.icon = icon
        self.action = action
    }

    /// Icon-only button initializer (e.g. destructive trash button beside a commit CTA).
    public init(
        icon: String,
        accessibilityLabel: String,
        variant: Variant = .danger,
        size: Size = .lg,
        isBlock: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = nil
        self.accessibilityLabelText = accessibilityLabel
        self.variant = variant
        self.size = size
        self.isBlock = isBlock
        self.icon = icon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: size.spacing) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: size.iconSize, weight: .semibold))
                }
                if let title {
                    Text(title)
                        .font(BLFont.ui(size: size.fontSize, weight: .semibold))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: isBlock ? .infinity : nil)
            .frame(minWidth: title == nil ? size.height : nil)
        }
        .buttonStyle(
            BLButtonStyle(
                variant: variant,
                size: size,
                isIconOnly: title == nil
            )
        )
        .accessibilityLabel(accessibilityLabelText ?? title ?? "")
    }
}

private struct BLButtonStyle: ButtonStyle {
    let variant: BLButton.Variant
    let size: BLButton.Size
    let isIconOnly: Bool

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(
            configuration: configuration,
            variant: variant,
            size: size,
            isIconOnly: isIconOnly
        )
    }

    private struct StyledBody: View {
        @Environment(\.blTheme) private var theme
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        let configuration: Configuration
        let variant: BLButton.Variant
        let size: BLButton.Size
        let isIconOnly: Bool

        private var backgroundColor: Color {
            switch variant {
            case .primary:
                configuration.isPressed ? theme.accentPressed : theme.accent
            case .ink:
                configuration.isPressed ? theme.textPrimary.opacity(0.86) : theme.textPrimary
            case .secondary:
                configuration.isPressed ? theme.bgSunken : theme.bgSurface
            case .ghost:
                configuration.isPressed ? theme.accentSoft : .clear
            case .danger:
                configuration.isPressed ? theme.danger.tint.opacity(0.82) : theme.danger.tint
            }
        }

        private var foregroundColor: Color {
            switch variant {
            case .primary: theme.textOnAccent
            case .ink: theme.bgApp
            case .secondary: theme.textPrimary
            case .ghost: theme.accentText
            case .danger: theme.danger.ink
            }
        }

        private var borderColor: Color {
            variant == .secondary ? theme.borderStrong : .clear
        }

        private var horizontalPadding: CGFloat {
            if isIconOnly { return 0 }
            if variant == .ghost { return BLSpacing.space3 }
            return size.horizontalPadding
        }

        var body: some View {
            configuration.label
                .padding(.horizontal, horizontalPadding)
                .frame(height: size.height)
                .foregroundStyle(foregroundColor)
                .background(
                    RoundedRectangle(cornerRadius: size.radius, style: .continuous)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: size.radius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: BLSpacing.borderWidth)
                )
                .contentShape(RoundedRectangle(cornerRadius: size.radius, style: .continuous))
                .opacity(isEnabled ? 1.0 : 0.4)
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(
                    BLMotion.easeOut(duration: BLMotion.fast, reducedMotion: reduceMotion),
                    value: configuration.isPressed
                )
        }
    }
}

// MARK: - BLIconButton

/// Square icon-only button (`44pt` or `56pt`) with `.94` press scale.
public struct BLIconButton: View {
    public enum Variant: Sendable, Hashable {
        case plain
        case outline
        case filled
    }

    public enum Size: Sendable, Hashable {
        case md
        case lg

        var dimension: CGFloat {
            switch self {
            case .md: BLHitTarget.min
            case .lg: BLHitTarget.comfy
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .md: 18
            case .lg: 22
            }
        }
    }

    private let icon: String
    private let label: String
    private let variant: Variant
    private let size: Size
    private let action: () -> Void

    public init(
        icon: String,
        label: String,
        variant: Variant = .plain,
        size: Size = .md,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.variant = variant
        self.size = size
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size.iconSize, weight: .medium))
                .frame(width: size.dimension, height: size.dimension)
        }
        .buttonStyle(BLIconButtonStyle(variant: variant, size: size))
        .accessibilityLabel(label)
    }
}

private struct BLIconButtonStyle: ButtonStyle {
    let variant: BLIconButton.Variant
    let size: BLIconButton.Size

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, variant: variant, size: size)
    }

    private struct StyledBody: View {
        @Environment(\.blTheme) private var theme
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        let configuration: Configuration
        let variant: BLIconButton.Variant
        let size: BLIconButton.Size

        private var backgroundColor: Color {
            switch variant {
            case .plain:
                configuration.isPressed ? theme.bgSunken : .clear
            case .outline:
                configuration.isPressed ? theme.bgSunken : theme.bgSurface
            case .filled:
                configuration.isPressed ? theme.accentPressed : theme.accent
            }
        }

        private var foregroundColor: Color {
            variant == .filled ? theme.textOnAccent : theme.textPrimary
        }

        private var borderColor: Color {
            variant == .outline ? theme.borderStrong : .clear
        }

        var body: some View {
            configuration.label
                .foregroundStyle(foregroundColor)
                .background(
                    RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: BLSpacing.borderWidth)
                )
                .contentShape(RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous))
                .opacity(isEnabled ? 1.0 : 0.4)
                .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
                .animation(
                    BLMotion.easeOut(duration: BLMotion.fast, reducedMotion: reduceMotion),
                    value: configuration.isPressed
                )
        }
    }
}

// MARK: - BLChip

/// Selectable preset or filter chip with crisp honey double-border selection and `.96` press scale.
public struct BLChip: View {
    public enum Size: Sendable, Hashable {
        case md
        case lg

        var height: CGFloat {
            switch self {
            case .md: BLHitTarget.min
            case .lg: 52
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .md: 14
            case .lg: 18
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .md: 15
            case .lg: 17
            }
        }
    }

    private let title: String
    private let isSelected: Bool
    private let size: Size
    private let icon: String?
    private let isBlock: Bool
    private let action: () -> Void

    public init(
        _ title: String,
        isSelected: Bool,
        size: Size = .md,
        icon: String? = nil,
        isBlock: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isSelected = isSelected
        self.size = size
        self.icon = icon
        self.isBlock = isBlock
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                }
                Text(title)
                    .font(BLFont.ui(size: size.fontSize, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: isBlock ? .infinity : nil)
        }
        .buttonStyle(BLChipStyle(isSelected: isSelected, size: size, isBlock: isBlock))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct BLChipStyle: ButtonStyle {
    let isSelected: Bool
    let size: BLChip.Size
    let isBlock: Bool

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, isSelected: isSelected, size: size, isBlock: isBlock)
    }

    private struct StyledBody: View {
        @Environment(\.blTheme) private var theme
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        let configuration: Configuration
        let isSelected: Bool
        let size: BLChip.Size
        let isBlock: Bool

        private var backgroundColor: Color {
            if isSelected { return theme.accentSoft }
            return configuration.isPressed ? theme.bgSunken : theme.bgSurface
        }

        var body: some View {
            configuration.label
                .padding(.horizontal, isBlock ? BLSpacing.space2 : size.horizontalPadding)
                .frame(height: size.height)
                .foregroundStyle(theme.textPrimary)
                .background(
                    RoundedRectangle(cornerRadius: BLRadius.sm, style: .continuous)
                        .fill(backgroundColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BLRadius.sm, style: .continuous)
                        .strokeBorder(
                            isSelected ? theme.accentBorder : theme.borderStrong,
                            lineWidth: isSelected ? 2 : BLSpacing.borderWidth
                        )
                )
                .contentShape(RoundedRectangle(cornerRadius: BLRadius.sm, style: .continuous))
                .opacity(isEnabled ? 1.0 : 0.4)
                .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                .animation(
                    BLMotion.easeOut(duration: BLMotion.fast, reducedMotion: reduceMotion),
                    value: configuration.isPressed
                )
        }
    }
}

// MARK: - BLBadge

/// Compact 22pt uppercase status or event-tinted badge with 6pt corners.
public struct BLBadge: View {
    public enum Tone: Sendable, Hashable {
        case neutral
        case accent
        case warn
        case ok
        case danger
        case event(BLEventKind)
    }

    @Environment(\.blTheme) private var theme

    private let text: String
    private let tone: Tone
    private let icon: String?

    public init(_ text: String, tone: Tone = .neutral, icon: String? = nil) {
        self.text = text
        self.tone = tone
        self.icon = icon
    }

    private var colors: (background: Color, foreground: Color) {
        switch tone {
        case .neutral: (theme.bgSunken, theme.textSecondary)
        case .accent: (theme.accentSoft, theme.accentText)
        case .warn: (theme.warn.tint, theme.warn.ink)
        case .ok: (theme.ok.tint, theme.ok.ink)
        case .danger: (theme.danger.tint, theme.danger.ink)
        case .event(let kind):
            (theme.event(kind).tint, theme.event(kind).ink)
        }
    }

    public var body: some View {
        HStack(spacing: BLSpacing.space1) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
            }
            Text(text)
                .font(BLFont.ui(size: 11, weight: .semibold))
                .tracking(0.44)
                .textCase(.uppercase)
                .lineLimit(1)
        }
        .foregroundStyle(colors.foreground)
        .padding(.horizontal, 7)
        .frame(height: 22)
        .background(
            RoundedRectangle(cornerRadius: BLRadius.xs, style: .continuous)
                .fill(colors.background)
        )
    }
}

// MARK: - BLCard

/// Flat paper surface card with 1px hairline border, 12pt corners, and zero shadow.
public struct BLCard<Content: View>: View {
    public enum Tone: Sendable, Hashable {
        case surface
        case sunken
        case accent
    }

    @Environment(\.blTheme) private var theme

    private let tone: Tone
    private let isFlush: Bool
    private let onTap: (() -> Void)?
    private let content: Content

    public init(
        tone: Tone = .surface,
        isFlush: Bool = false,
        onTap: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.tone = tone
        self.isFlush = isFlush
        self.onTap = onTap
        self.content = content()
    }

    private var backgroundColor: Color {
        switch tone {
        case .surface: theme.bgSurface
        case .sunken: theme.bgSunken
        case .accent: theme.accentSoft
        }
    }

    private var borderColor: Color {
        switch tone {
        case .surface: theme.borderHairline
        case .sunken: .clear
        case .accent: theme.accentBorder
        }
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
        let cardBody = content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(isFlush ? 0 : BLSpacing.space4)
            .foregroundStyle(theme.textPrimary)
            .background(shape.fill(backgroundColor))
            .clipShape(shape)
            .overlay(shape.strokeBorder(borderColor, lineWidth: BLSpacing.borderWidth))

        if let onTap {
            Button(action: onTap) {
                cardBody
            }
            .buttonStyle(BLCardButtonStyle())
        } else {
            cardBody
        }
    }
}

private struct BLCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration)
    }

    private struct StyledBody: View {
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        let configuration: Configuration

        var body: some View {
            configuration.label
                .contentShape(RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous))
                .scaleEffect(configuration.isPressed ? 0.985 : 1.0)
                .animation(
                    BLMotion.easeOut(duration: BLMotion.fast, reducedMotion: reduceMotion),
                    value: configuration.isPressed
                )
        }
    }
}

// MARK: - BLListRow

/// Hairline-separated settings and sheet list row (`52pt` min height).
public struct BLListRow<Trailing: View>: View {
    @Environment(\.blTheme) private var theme

    private let icon: String?
    private let label: String
    private let detail: String?
    private let value: String?
    private let showsChevron: Bool
    private let isDanger: Bool
    private let showDivider: Bool
    private let onTap: (() -> Void)?
    private let trailing: Trailing

    public init(
        icon: String? = nil,
        label: String,
        detail: String? = nil,
        value: String? = nil,
        showsChevron: Bool = false,
        isDanger: Bool = false,
        showDivider: Bool = true,
        onTap: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.icon = icon
        self.label = label
        self.detail = detail
        self.value = value
        self.showsChevron = showsChevron
        self.isDanger = isDanger
        self.showDivider = showDivider
        self.onTap = onTap
        self.trailing = trailing()
    }

    public var body: some View {
        let rowContent = HStack(spacing: BLSpacing.space3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(isDanger ? theme.danger.ink : theme.textPrimary)
                    .frame(width: 22)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .blTextRole(.body)
                    .foregroundStyle(isDanger ? theme.danger.ink : theme.textPrimary)
                if let detail, !detail.isEmpty {
                    Text(detail)
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let value, !value.isEmpty {
                Text(value)
                    .font(BLFont.ui(size: 17, weight: .regular, tabularNumerals: true))
                    .foregroundStyle(theme.textSecondary)
            }

            trailing

            if showsChevron {
                Image(systemName: BLSymbol.chevronRight)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.textTertiary)
            }
        }
        .padding(.vertical, BLSpacing.space2)
        .padding(.horizontal, BLSpacing.space4)
        .frame(minHeight: 52)
        .overlay(alignment: .bottom) {
            if showDivider {
                Rectangle()
                    .fill(theme.borderHairline)
                    .frame(height: BLSpacing.borderWidth)
            }
        }

        if let onTap {
            Button(action: onTap) {
                rowContent
            }
            .buttonStyle(BLRowPressStyle())
        } else {
            rowContent
        }
    }
}

extension BLListRow where Trailing == EmptyView {
    public init(
        icon: String? = nil,
        label: String,
        detail: String? = nil,
        value: String? = nil,
        showsChevron: Bool = false,
        isDanger: Bool = false,
        showDivider: Bool = true,
        onTap: (() -> Void)? = nil
    ) {
        self.init(
            icon: icon,
            label: label,
            detail: detail,
            value: value,
            showsChevron: showsChevron,
            isDanger: isDanger,
            showDivider: showDivider,
            onTap: onTap,
            trailing: { EmptyView() }
        )
    }
}

/// Shared flat sunken-fill row press style for `BLListRow` and `BLEventRow`.
struct BLRowPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration)
    }

    private struct StyledBody: View {
        @Environment(\.blTheme) private var theme
        let configuration: Configuration

        var body: some View {
            configuration.label
                .background(configuration.isPressed ? theme.bgSunken : .clear)
                .contentShape(Rectangle())
        }
    }
}
