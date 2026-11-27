import SwiftUI

// MARK: - BLEventIcon

/// Event SF Symbol inside a tinted rounded square (`22pt`, `32pt`, or `44pt`).
public struct BLEventIcon: View {
    public enum Size: Sendable, Hashable {
        case sm
        case md
        case lg

        var dimension: CGFloat {
            switch self {
            case .sm: 22
            case .md: 32
            case .lg: 44
            }
        }

        var radius: CGFloat {
            switch self {
            case .sm: BLRadius.xs
            case .md: BLRadius.sm
            case .lg: BLRadius.md
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .sm: 11
            case .md: 15
            case .lg: 20
            }
        }
    }

    @Environment(\.blTheme) private var theme

    private let kind: BLEventKind
    private let size: Size

    public init(kind: BLEventKind, size: Size = .md) {
        self.kind = kind
        self.size = size
    }

    public var body: some View {
        let triplet = theme.event(kind)
        ZStack {
            RoundedRectangle(cornerRadius: size.radius, style: .continuous)
                .fill(triplet.tint)

            Image(systemName: kind.symbolName)
                .font(.system(size: size.iconSize, weight: .medium))
                .foregroundStyle(triplet.ink)
        }
        .frame(width: size.dimension, height: size.dimension)
        .accessibilityHidden(true)
    }
}

// MARK: - BLQuickTile

/// One-tap event quick-log tile (`.sm` 60pt compact stacked, `.md` 56pt horizontal, `.lg` 108pt card).
/// Floods with its event tint and solid border at `.96` scale on press.
public struct BLQuickTile: View {
    public enum Size: Sendable, Hashable {
        case sm
        case md
        case lg
    }

    @Environment(\.blTheme) private var theme

    private let kind: BLEventKind
    private let label: String?
    private let sub: String?
    private let size: Size
    private let action: () -> Void

    public init(
        kind: BLEventKind,
        label: String? = nil,
        sub: String? = nil,
        size: Size = .md,
        action: @escaping () -> Void
    ) {
        self.kind = kind
        self.label = label
        self.sub = sub
        self.size = size
        self.action = action
    }

    private var resolvedLabel: String {
        if let label { return label }
        return size == .sm ? kind.compactLabel : kind.displayLabel
    }

    public var body: some View {
        Button(action: action) {
            switch size {
            case .sm:
                VStack(spacing: 3) {
                    BLEventIcon(kind: kind, size: .md)
                    Text(resolvedLabel)
                        .font(BLFont.ui(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 60)
                .padding(.top, 5)
                .padding(.horizontal, 2)
                .padding(.bottom, 4)

            case .md:
                HStack(spacing: 10) {
                    BLEventIcon(kind: kind, size: .md)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(resolvedLabel)
                            .font(BLFont.ui(size: 15, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                        if let sub, !sub.isEmpty {
                            Text(sub)
                                .blTextRole(.caption)
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: BLHitTarget.comfy)
                .padding(.vertical, BLSpacing.space2)
                .padding(.horizontal, 10)

            case .lg:
                VStack(alignment: .leading, spacing: BLSpacing.space2) {
                    BLEventIcon(kind: kind, size: .lg)
                    Spacer(minLength: BLSpacing.space2)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(resolvedLabel)
                            .font(BLFont.ui(size: 17, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)
                        if let sub, !sub.isEmpty {
                            Text(sub)
                                .blTextRole(.caption)
                                .foregroundStyle(theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 108, alignment: .leading)
                .padding(14)
            }
        }
        .buttonStyle(BLQuickTileStyle(kind: kind))
    }
}

private struct BLQuickTileStyle: ButtonStyle {
    let kind: BLEventKind

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, kind: kind)
    }

    private struct StyledBody: View {
        @Environment(\.blTheme) private var theme
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        let configuration: Configuration
        let kind: BLEventKind

        var body: some View {
            let triplet = theme.event(kind)
            let shape = RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
            configuration.label
                .background(
                    shape.fill(configuration.isPressed ? triplet.tint : theme.bgSurface)
                )
                .overlay(
                    shape.strokeBorder(
                        configuration.isPressed ? triplet.solid : theme.borderHairline,
                        lineWidth: BLSpacing.borderWidth
                    )
                )
                .contentShape(shape)
                .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                .animation(
                    BLMotion.easeOut(duration: BLMotion.fast, reducedMotion: reduceMotion),
                    value: configuration.isPressed
                )
        }
    }
}

// MARK: - BLGlanceStat

/// Tappable summary stat card with 28pt tabular display-serif value and optional SweetSpot progress bar and footer caption.
public struct BLGlanceStat: View {
    @Environment(\.blTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let kind: BLEventKind?
    private let label: String
    private let value: String
    private let sub: String?
    private let progress: Double?
    private let isOver: Bool
    private let footer: String?
    private let footerHighlight: String?
    private let action: (() -> Void)?

    public init(
        kind: BLEventKind? = nil,
        label: String,
        value: String,
        sub: String? = nil,
        progress: Double? = nil,
        isOver: Bool = false,
        footer: String? = nil,
        footerHighlight: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.kind = kind
        self.label = label
        self.value = value
        self.sub = sub
        self.progress = progress
        self.isOver = isOver
        self.footer = footer
        self.footerHighlight = footerHighlight
        self.action = action
    }

    private var progressFillColor: Color {
        if isOver { return theme.warn.solid }
        return kind.map { theme.event($0).solid } ?? theme.accent
    }

    public var body: some View {
        let content = VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if let kind {
                    BLEventIcon(kind: kind, size: .sm)
                }
                Text(label)
                    .blMicroLabel()
                    .lineLimit(1)
            }

            Text(value)
                .font(BLFont.display(size: 28, weight: .medium, tabularNumerals: true))
                .tracking(BLFont.displayTrackingRatio * 28)
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let sub, !sub.isEmpty {
                Text(sub)
                    .blTextRole(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            if let progress {
                let clamped = progress.isFinite ? min(max(progress, 0.0), 1.0) : 0.0
                GeometryReader { geo in
                    let width = max(0, geo.size.width)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(theme.bgSunken)
                            .frame(width: width, height: 3)

                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(progressFillColor)
                            .frame(width: width * clamped, height: 3)
                            .animation(
                                BLMotion.easeOut(duration: BLMotion.base, reducedMotion: reduceMotion),
                                value: clamped
                            )
                    }
                }
                .frame(height: 3)
                .padding(.top, 6)
                .accessibilityHidden(true)
            }

            if let footer, !footer.isEmpty {
                footerText(footer)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .truncationMode(.tail)
                    .padding(.top, progress == nil ? 4 : 3)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, BLSpacing.space3)
        .padding(.horizontal, 14)

        if let action {
            Button(action: action) {
                content
            }
            .buttonStyle(BLGlanceStatStyle())
        } else {
            let shape = RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
            content
                .background(shape.fill(theme.bgSurface))
                .overlay(shape.strokeBorder(theme.borderHairline, lineWidth: BLSpacing.borderWidth))
        }
    }

    private func footerText(_ footer: String) -> Text {
        let baseFont = BLFont.ui(size: 12, weight: .medium, tabularNumerals: true)
        let highlightFont = BLFont.ui(size: 12, weight: .semibold, tabularNumerals: true)
        let highlightColor = isOver ? theme.warn.ink : theme.textPrimary

        guard let highlight = footerHighlight, !highlight.isEmpty else {
            return Text(footer)
                .font(baseFont)
                .foregroundColor(theme.textSecondary)
        }

        if let range = footer.range(of: highlight) {
            let leading = String(footer[..<range.lowerBound])
            let match = String(footer[range])
            let trailing = String(footer[range.upperBound...])
            return Text(leading)
                .font(baseFont)
                .foregroundColor(theme.textSecondary)
                + Text(match)
                    .font(highlightFont)
                    .foregroundColor(highlightColor)
                + Text(trailing)
                    .font(baseFont)
                    .foregroundColor(theme.textSecondary)
        }

        return Text(footer + " ")
            .font(baseFont)
            .foregroundColor(theme.textSecondary)
            + Text(highlight)
                .font(highlightFont)
                .foregroundColor(highlightColor)
    }
}

private struct BLGlanceStatStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration)
    }

    private struct StyledBody: View {
        @Environment(\.blTheme) private var theme
        let configuration: Configuration

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
            configuration.label
                .background(
                    shape.fill(configuration.isPressed ? theme.bgSunken : theme.bgSurface)
                )
                .overlay(
                    shape.strokeBorder(theme.borderHairline, lineWidth: BLSpacing.borderWidth)
                )
                .contentShape(shape)
        }
    }
}

// MARK: - BLEventRow

/// Timeline event row with fixed `62pt` tabular clock column, event icon, details, and hairline divider.
public struct BLEventRow<Trailing: View>: View {
    @Environment(\.blTheme) private var theme

    private let kind: BLEventKind
    private let time: String
    private let title: String
    private let detail: String?
    private let sourceIcon: String?
    private let showDivider: Bool
    private let onTap: (() -> Void)?
    private let trailing: Trailing

    public init(
        kind: BLEventKind,
        time: String,
        title: String,
        detail: String? = nil,
        sourceIcon: String? = nil,
        showDivider: Bool = true,
        onTap: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.kind = kind
        self.time = time
        self.title = title
        self.detail = detail
        self.sourceIcon = sourceIcon
        self.showDivider = showDivider
        self.onTap = onTap
        self.trailing = trailing()
    }

    public var body: some View {
        let rowContent = HStack(alignment: .center, spacing: 10) {
            Text(time)
                .font(BLFont.ui(size: 13, weight: .medium, tabularNumerals: true))
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
                .frame(width: 62, alignment: .leading)

            BLEventIcon(kind: kind, size: .md)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(BLFont.ui(size: 16, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                if let detail, !detail.isEmpty {
                    Text(detail)
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: BLSpacing.space2) {
                trailing
                if let sourceIcon {
                    Image(systemName: sourceIcon)
                        .font(.system(size: 14, weight: .regular))
                        .foregroundStyle(theme.textTertiary)
                }
            }
        }
        .padding(.vertical, BLSpacing.space2)
        .frame(minHeight: BLHitTarget.comfy)
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

extension BLEventRow where Trailing == EmptyView {
    public init(
        kind: BLEventKind,
        time: String,
        title: String,
        detail: String? = nil,
        sourceIcon: String? = nil,
        showDivider: Bool = true,
        onTap: (() -> Void)? = nil
    ) {
        self.init(
            kind: kind,
            time: time,
            title: title,
            detail: detail,
            sourceIcon: sourceIcon,
            showDivider: showDivider,
            onTap: onTap,
            trailing: { EmptyView() }
        )
    }
}

// MARK: - BLNapCard

/// Hero awake / sleeping timer & sweet-spot predictor card for the top of Today.
public struct BLNapCard: View {
    @Environment(\.blTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let isAsleep: Bool
    private let label: String
    private let elapsed: String
    private let progress: Double
    private let isOver: Bool
    private let caption: String
    private let captionHighlight: String?
    private let actionLabel: String?
    private let onAction: (() -> Void)?
    private let secondaryLabel: String?
    private let onSecondary: (() -> Void)?

    public init(
        isAsleep: Bool,
        label: String,
        elapsed: String,
        progress: Double,
        isOver: Bool = false,
        caption: String,
        captionHighlight: String? = nil,
        actionLabel: String? = nil,
        onAction: (() -> Void)? = nil,
        secondaryLabel: String? = nil,
        onSecondary: (() -> Void)? = nil
    ) {
        self.isAsleep = isAsleep
        self.label = label
        self.elapsed = elapsed
        self.progress = progress
        self.isOver = isOver
        self.caption = caption
        self.captionHighlight = captionHighlight
        self.actionLabel = actionLabel
        self.onAction = onAction
        self.secondaryLabel = secondaryLabel
        self.onSecondary = onSecondary
    }

    private var clampedProgress: Double {
        min(1.0, max(0.0, progress))
    }

    private var fillColor: Color {
        if isOver { return theme.warn.solid }
        return isAsleep ? theme.sleep.solid : theme.accent
    }

    private var railColor: Color {
        isAsleep ? theme.sleep.solid.opacity(0.25) : theme.bgSunken
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: BLRadius.lg, style: .continuous)
        VStack(alignment: .leading, spacing: BLSpacing.space3) {
            // Top micro label + sun/moon indicator
            HStack {
                Text(label)
                    .blMicroLabel()
                Spacer()
                Image(systemName: isAsleep ? BLSymbol.moon : BLSymbol.sun)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(theme.textSecondary)
            }

            // Elapsed numeral with stepped-down UI units (e.g. 2h 22m)
            elapsedText
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            // Progress rail with end sweet-spot / nap-cap tick
            GeometryReader { geo in
                let width = max(0, geo.size.width - 1)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(railColor)
                        .frame(width: width, height: 6)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(fillColor)
                        .frame(width: width * clampedProgress, height: 6)

                    Rectangle()
                        .fill(theme.textPrimary)
                        .frame(width: 2, height: 14)
                        .position(x: max(1, geo.size.width - 1), y: 7)
                }
            }
            .frame(height: 14)

            // Caption with optional bold primary-ink highlight
            if !caption.isEmpty {
                captionText
            }

            // Primary hero button (60pt sleepy hit target)
            if let actionLabel, let onAction {
                BLButton(
                    actionLabel,
                    variant: isAsleep ? .ink : .primary,
                    size: .lg,
                    isBlock: true,
                    icon: isAsleep ? BLSymbol.sun : BLSymbol.moon,
                    action: onAction
                )
            }

            // Secondary quiet action (e.g. "Add a past sleep" / "Change start time")
            if let secondaryLabel, let onSecondary {
                Button(action: onSecondary) {
                    Text(secondaryLabel)
                        .font(BLFont.ui(size: 15, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: BLHitTarget.min)
                        .contentShape(RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous))
                }
                .buttonStyle(BLNapSecondaryButtonStyle())
                .padding(.top, -4)
                .padding(.bottom, -8)
            }
        }
        .padding(BLSpacing.space4)
        .background(
            shape.fill(isAsleep ? theme.sleep.tint : theme.bgSurface)
        )
        .overlay(
            shape.strokeBorder(
                isAsleep ? theme.sleep.solid : theme.borderHairline,
                lineWidth: BLSpacing.borderWidth
            )
        )
        .animation(
            BLMotion.easeOut(duration: BLMotion.base, reducedMotion: reduceMotion),
            value: isAsleep
        )
    }

    private var elapsedText: Text {
        let tokens = Self.parseElapsedTokens(elapsed)
        var combined = Text("")
        for (index, token) in tokens.enumerated() {
            if token.isDigits {
                let prefix = index > 0 ? " " : ""
                combined = combined
                    + Text(prefix + token.value)
                        .font(BLFont.display(size: 56, weight: .regular, tabularNumerals: true))
                        .foregroundColor(theme.textPrimary)
            } else {
                combined = combined
                    + Text(token.value)
                        .font(BLFont.ui(size: 23.5, weight: .medium))
                        .foregroundColor(theme.textSecondary)
            }
        }
        return combined
    }

    private var captionText: Text {
        let baseFont = BLFont.ui(size: 15, weight: .medium)
        let highlightFont = BLFont.ui(size: 15, weight: .semibold)

        guard let highlight = captionHighlight, !highlight.isEmpty else {
            return Text(caption)
                .font(baseFont)
                .foregroundColor(theme.textSecondary)
        }

        if let range = caption.range(of: highlight) {
            let leading = String(caption[..<range.lowerBound])
            let match = String(caption[range])
            let trailing = String(caption[range.upperBound...])
            return Text(leading)
                .font(baseFont)
                .foregroundColor(theme.textSecondary)
                + Text(match)
                    .font(highlightFont)
                    .foregroundColor(theme.textPrimary)
                + Text(trailing)
                    .font(baseFont)
                    .foregroundColor(theme.textSecondary)
        }

        return Text(caption + " ")
            .font(baseFont)
            .foregroundColor(theme.textSecondary)
            + Text(highlight)
                .font(highlightFont)
                .foregroundColor(theme.textPrimary)
    }

    private struct ElapsedToken {
        let value: String
        let isDigits: Bool
    }

    private static func parseElapsedTokens(_ raw: String) -> [ElapsedToken] {
        var result: [ElapsedToken] = []
        var current = ""
        var currentIsDigit: Bool?

        for ch in raw {
            let isDigit = ch.isNumber
            if let existing = currentIsDigit, existing == isDigit {
                current.append(ch)
            } else {
                let trimmed = current.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty, let existing = currentIsDigit {
                    result.append(ElapsedToken(value: trimmed, isDigits: existing))
                }
                current = String(ch)
                currentIsDigit = isDigit
            }
        }
        let trimmed = current.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty, let existing = currentIsDigit {
            result.append(ElapsedToken(value: trimmed, isDigits: existing))
        }
        if result.isEmpty {
            return [ElapsedToken(value: raw, isDigits: true)]
        }
        return result
    }
}

private struct BLNapSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration)
    }

    private struct StyledBody: View {
        @Environment(\.blTheme) private var theme
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        let configuration: Configuration

        var body: some View {
            configuration.label
                .background(
                    RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
                        .fill(configuration.isPressed ? theme.accentSoft : .clear)
                )
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(
                    BLMotion.easeOut(duration: BLMotion.fast, reducedMotion: reduceMotion),
                    value: configuration.isPressed
                )
        }
    }
}

// MARK: - BLNursingTimer

/// Live two-sided nursing timer with giant `mm:ss` total and two `112pt` Left/Right side cards.
public struct BLNursingTimer: View {
    @Environment(\.blTheme) private var theme

    private let leftSeconds: Int
    private let rightSeconds: Int
    private let activeSide: String?
    private let lastSide: String?
    private let onTapSide: (String) -> Void

    public init(
        leftSeconds: Int,
        rightSeconds: Int,
        activeSide: String?,
        lastSide: String? = nil,
        onTapSide: @escaping (String) -> Void
    ) {
        self.leftSeconds = leftSeconds
        self.rightSeconds = rightSeconds
        self.activeSide = activeSide
        self.lastSide = lastSide
        self.onTapSide = onTapSide
    }

    public var body: some View {
        VStack(spacing: 14) {
            Text(Self.formatMMSS(leftSeconds + rightSeconds))
                .blTextRole(.timer)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            HStack(spacing: BLSpacing.space2) {
                sideCard(id: "left", label: "Left", seconds: leftSeconds)
                sideCard(id: "right", label: "Right", seconds: rightSeconds)
            }
        }
    }

    private func sideCard(id: String, label: String, seconds: Int) -> some View {
        let isActive = activeSide == id
        let stateText: String = {
            if isActive { return "Pause" }
            if activeSide != nil { return "Switch" }
            if seconds > 0 { return "Resume" }
            return "Start"
        }()

        return Button {
            onTapSide(id)
        } label: {
            VStack(alignment: .leading, spacing: BLSpacing.space1) {
                HStack(spacing: BLSpacing.space2) {
                    Text(label)
                        .blMicroLabel()
                    Spacer(minLength: 4)
                    if lastSide == id && activeSide == nil && leftSeconds == 0 && rightSeconds == 0 {
                        BLBadge("Last", tone: .neutral)
                    }
                }
                .frame(minHeight: 22)

                Text(Self.formatMMSS(seconds))
                    .blTextRole(.display)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: BLSpacing.space2)

                HStack(spacing: 6) {
                    Image(systemName: isActive ? BLSymbol.pause : BLSymbol.play)
                        .font(.system(size: 13, weight: .semibold))
                    Text(stateText)
                        .font(BLFont.ui(size: 15, weight: .semibold))
                }
                .foregroundStyle(isActive ? theme.feeding.ink : theme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .padding(14)
        }
        .buttonStyle(BLNursingSideStyle(isActive: isActive))
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private static func formatMMSS(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let mins = clamped / 60
        let secs = clamped % 60
        return "\(mins):" + (secs < 10 ? "0\(secs)" : "\(secs)")
    }
}

private struct BLNursingSideStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, isActive: isActive)
    }

    private struct StyledBody: View {
        @Environment(\.blTheme) private var theme
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        let configuration: Configuration
        let isActive: Bool

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: BLRadius.lg, style: .continuous)
            configuration.label
                .background(
                    shape.fill(isActive ? theme.feeding.tint : theme.bgSurface)
                )
                .overlay(
                    shape.strokeBorder(
                        isActive ? theme.feeding.solid : theme.borderStrong,
                        lineWidth: isActive ? 2 : BLSpacing.borderWidth
                    )
                )
                .contentShape(shape)
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(
                    BLMotion.easeOut(duration: BLMotion.fast, reducedMotion: reduceMotion),
                    value: configuration.isPressed
                )
        }
    }
}

// MARK: - BLPumpTimer

/// Live independent dual-side pump timer with giant `mm:ss` union session total, two `112pt` Left/Right side cards, and a full-width start/pause control.
public struct BLPumpTimer: View {
    @Environment(\.blTheme) private var theme

    private let sessionSeconds: Int
    private let leftSeconds: Int
    private let rightSeconds: Int
    private let isLeftRunning: Bool
    private let isRightRunning: Bool
    private let onTapSide: (String) -> Void
    private let onToggleBoth: () -> Void

    public init(
        sessionSeconds: Int,
        leftSeconds: Int,
        rightSeconds: Int,
        isLeftRunning: Bool,
        isRightRunning: Bool,
        onTapSide: @escaping (String) -> Void,
        onToggleBoth: @escaping () -> Void
    ) {
        self.sessionSeconds = sessionSeconds
        self.leftSeconds = leftSeconds
        self.rightSeconds = rightSeconds
        self.isLeftRunning = isLeftRunning
        self.isRightRunning = isRightRunning
        self.onTapSide = onTapSide
        self.onToggleBoth = onToggleBoth
    }

    public var body: some View {
        VStack(spacing: 14) {
            Text(Self.formatMMSS(sessionSeconds))
                .blTextRole(.timer)
                .foregroundStyle(theme.textPrimary)
                .frame(maxWidth: .infinity, alignment: .center)

            VStack(spacing: BLSpacing.space3) {
                HStack(spacing: BLSpacing.space2) {
                    sideCard(id: "left", label: "Left", seconds: leftSeconds, isRunning: isLeftRunning)
                    sideCard(id: "right", label: "Right", seconds: rightSeconds, isRunning: isRightRunning)
                }

                toggleBothButton
            }
        }
    }

    private var toggleBothButton: some View {
        let isAnyRunning = isLeftRunning || isRightRunning
        let isBothRunning = isLeftRunning && isRightRunning
        let title: String = {
            if isBothRunning { return "Pause both" }
            if isAnyRunning { return "Pause" }
            if sessionSeconds > 0 { return "Resume both" }
            return "Start both"
        }()

        return BLButton(
            title,
            variant: isAnyRunning ? .secondary : .primary,
            size: .md,
            isBlock: true,
            icon: isAnyRunning ? BLSymbol.pause : BLSymbol.play,
            action: onToggleBoth
        )
    }

    private func sideCard(id: String, label: String, seconds: Int, isRunning: Bool) -> some View {
        let pumpColors = theme.event(.pump)
        let stateText: String = {
            if isRunning { return "Pause" }
            if seconds > 0 { return "Resume" }
            return "Start"
        }()

        return Button {
            onTapSide(id)
        } label: {
            VStack(alignment: .leading, spacing: BLSpacing.space1) {
                HStack(spacing: BLSpacing.space2) {
                    Text(label)
                        .blMicroLabel()
                    Spacer(minLength: 4)
                }
                .frame(minHeight: 22)

                Text(Self.formatMMSS(seconds))
                    .blTextRole(.display)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer(minLength: BLSpacing.space2)

                HStack(spacing: 6) {
                    Image(systemName: isRunning ? BLSymbol.pause : BLSymbol.play)
                        .font(.system(size: 13, weight: .semibold))
                    Text(stateText)
                        .font(BLFont.ui(size: 15, weight: .semibold))
                }
                .foregroundStyle(isRunning ? pumpColors.ink : theme.textSecondary)
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .padding(14)
        }
        .buttonStyle(BLPumpSideStyle(isRunning: isRunning))
        .accessibilityAddTraits(isRunning ? .isSelected : [])
    }

    private static func formatMMSS(_ seconds: Int) -> String {
        let clamped = max(0, seconds)
        let mins = clamped / 60
        let secs = clamped % 60
        return "\(mins):" + (secs < 10 ? "0\(secs)" : "\(secs)")
    }
}

private struct BLPumpSideStyle: ButtonStyle {
    let isRunning: Bool

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, isRunning: isRunning)
    }

    private struct StyledBody: View {
        @Environment(\.blTheme) private var theme
        @Environment(\.accessibilityReduceMotion) private var reduceMotion
        let configuration: Configuration
        let isRunning: Bool

        var body: some View {
            let pumpColors = theme.event(.pump)
            let shape = RoundedRectangle(cornerRadius: BLRadius.lg, style: .continuous)
            configuration.label
                .background(
                    shape.fill(isRunning ? pumpColors.tint : theme.bgSurface)
                )
                .overlay(
                    shape.strokeBorder(
                        isRunning ? pumpColors.solid : theme.borderStrong,
                        lineWidth: isRunning ? 2 : BLSpacing.borderWidth
                    )
                )
                .contentShape(shape)
                .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
                .animation(
                    BLMotion.easeOut(duration: BLMotion.fast, reducedMotion: reduceMotion),
                    value: configuration.isPressed
                )
                .animation(
                    BLMotion.easeOut(duration: BLMotion.fast, reducedMotion: reduceMotion),
                    value: isRunning
                )
        }
    }
}

// MARK: - BLDraftCard

/// Paper-log scan review entry card with include checkbox, selection outline, and amber ambiguity resolution bar.
public struct BLDraftCard: View {
    @Environment(\.blTheme) private var theme

    private let kind: BLEventKind
    private let time: String
    private let title: String
    private let detail: String?
    private let badgeText: String
    private let badgeTone: BLBadge.Tone
    private let isIncluded: Bool
    private let onToggle: (Bool) -> Void
    private let isSelected: Bool
    private let onSelect: (() -> Void)?
    private let ambiguityQuestion: String?
    private let resolutionOptions: [String]
    private let onResolve: ((String) -> Void)?

    public init(
        kind: BLEventKind,
        time: String,
        title: String,
        detail: String? = nil,
        badgeText: String,
        badgeTone: BLBadge.Tone = .accent,
        isIncluded: Bool,
        onToggle: @escaping (Bool) -> Void,
        isSelected: Bool = false,
        onSelect: (() -> Void)? = nil,
        ambiguityQuestion: String? = nil,
        resolutionOptions: [String] = [],
        onResolve: ((String) -> Void)? = nil
    ) {
        self.kind = kind
        self.time = time
        self.title = title
        self.detail = detail
        self.badgeText = badgeText
        self.badgeTone = badgeTone
        self.isIncluded = isIncluded
        self.onToggle = onToggle
        self.isSelected = isSelected
        self.onSelect = onSelect
        self.ambiguityQuestion = ambiguityQuestion
        self.resolutionOptions = resolutionOptions
        self.onResolve = onResolve
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Button {
                    onToggle(!isIncluded)
                } label: {
                    BLCheckboxSquare(isChecked: isIncluded)
                        .frame(width: BLHitTarget.min, height: BLHitTarget.min)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Include this entry")
                .accessibilityValue(isIncluded ? "Included" : "Skipped")

                HStack(alignment: .top, spacing: 10) {
                    BLEventIcon(kind: kind, size: .md)
                        .padding(.top, 6)
                        .opacity(isIncluded ? 1.0 : 0.5)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(time)
                            .font(BLFont.ui(size: 13, weight: .medium, tabularNumerals: true))
                            .foregroundStyle(theme.textSecondary)

                        Text(title)
                            .font(BLFont.ui(size: 16, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)

                        if let detail, !detail.isEmpty {
                            Text(detail)
                                .blTextRole(.caption)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                    .padding(.vertical, BLSpacing.space1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(isIncluded ? 1.0 : 0.5)

                    BLBadge(badgeText, tone: badgeTone)
                        .padding(.top, 11)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelect?()
                }
            }
            .padding(.top, BLSpacing.space2)
            .padding(.leading, BLSpacing.space1)
            .padding(.trailing, BLSpacing.space3)
            .padding(.bottom, BLSpacing.space2)

            if let question = ambiguityQuestion, !question.isEmpty, isIncluded {
                ambiguityBar(question: question)
            }
        }
        .background(shape.fill(theme.bgSurface))
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                isSelected ? theme.accentBorder : theme.borderHairline,
                lineWidth: isSelected ? 2 : BLSpacing.borderWidth
            )
        )
    }

    private func ambiguityBar(question: String) -> some View {
        VStack(alignment: .leading, spacing: BLSpacing.space2) {
            HStack(alignment: .top, spacing: BLSpacing.space2) {
                Image(systemName: BLSymbol.warning)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.warn.ink)
                    .padding(.top, 2)

                Text(question)
                    .font(BLFont.ui(size: 13, weight: .medium))
                    .foregroundStyle(theme.warn.ink)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !resolutionOptions.isEmpty {
                HStack(spacing: BLSpacing.space2) {
                    ForEach(resolutionOptions, id: \.self) { option in
                        BLButton(option, variant: .secondary, size: .sm) {
                            onResolve?(option)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, BLSpacing.space3)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.warn.tint)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.borderHairline)
                .frame(height: BLSpacing.borderWidth)
        }
    }
}
