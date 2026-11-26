import BlythesLifeCore
import BlythesLifeDesignSystem
import BlythesLifeShared
import SwiftUI

/// Half-folded iPhone Duo nightstand / tabletop view.
/// Always renders in OLED true-black Night mode with an upright readable timer above the horizontal crease
/// and oversized sleepy-thumb (`60pt+`) controls on the flat bottom deck.
@MainActor
public struct TabletopNightstandView: View {
    @Environment(\.blTheme) private var theme
    @Environment(\.duoLayout) private var duoLayout

    private let store: BlythesLifeStore
    private let hingeRect: CGRect
    private let onOpenLog: (BLEventKind) -> Void

    public init(
        store: BlythesLifeStore,
        hingeRect: CGRect,
        onOpenLog: @escaping (BLEventKind) -> Void
    ) {
        self.store = store
        self.hingeRect = hingeRect
        self.onOpenLog = onOpenLog
    }

    public var body: some View {
        GeometryReader { proxy in
            let localFrame = proxy.frame(in: .named(BLRootCoordinateSpace.name))
            let totalWidth = max(0, proxy.size.width)
            let totalHeight = max(0, proxy.size.height)
            let gutterHeight = max(14, min(hingeRect.height, totalHeight * 0.16))
            let rawTop = hingeRect.minY - localFrame.minY
            let topHeight: CGFloat = {
                if rawTop >= 180 && (rawTop + gutterHeight) <= (totalHeight - 180) {
                    return rawTop
                }
                return max(0, floor((totalHeight - gutterHeight) * 0.5))
            }()
            let bottomHeight = max(0, totalHeight - topHeight - gutterHeight)

            VStack(spacing: 0) {
                uprightDisplayPane
                    .frame(width: totalWidth, height: topHeight, alignment: .center)
                    .clipped()

                BLHingeGutter(axis: .horizontal)
                    .frame(width: totalWidth, height: gutterHeight)

                bottomDeckPane
                    .frame(width: totalWidth, height: bottomHeight, alignment: .center)
                    .clipped()
            }
            .frame(width: totalWidth, height: totalHeight, alignment: .top)
            .background(theme.bgApp)
        }
        .background(theme.bgApp.ignoresSafeArea())
        .blTheme(.night)
    }

    // MARK: - Top Half (Angled Upright Display)

    private var uprightDisplayPane: some View {
        let nap = store.napCardState
        let lastFeed = store.lastFeedGlance
        let lastDiaper = store.lastDiaperGlance

        return VStack(spacing: BLSpacing.space4) {
            Spacer(minLength: BLSpacing.space2)

            VStack(alignment: .leading, spacing: BLSpacing.space3) {
                HStack(spacing: BLSpacing.space2) {
                    Text(nap.label)
                        .blMicroLabel(color: theme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                    Text(FormattingHelpers.formatClock(store.now, timeZone: store.profileTimeZone))
                        .font(BLFont.ui(size: 13, weight: .medium, tabularNumerals: true))
                        .foregroundStyle(theme.textTertiary)
                    Image(systemName: nap.isAsleep ? BLSymbol.moon : BLSymbol.sun)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(nap.isAsleep ? theme.sleep.ink : theme.accentText)
                }

                tabletopElapsedText(nap.elapsedText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
                    .frame(maxWidth: .infinity, alignment: .leading)

                tabletopProgressRail(
                    progress: nap.progress,
                    isAsleep: nap.isAsleep,
                    isOver: nap.isOver
                )

                if !nap.fullCaption.isEmpty {
                    tabletopCaptionText(
                        full: nap.fullCaption,
                        highlight: nap.highlightedClockTime
                    )
                    .lineLimit(2)
                }
            }
            .padding(BLSpacing.space4)
            .background(
                RoundedRectangle(cornerRadius: BLRadius.lg, style: .continuous)
                    .fill(nap.isAsleep ? theme.sleep.tint : theme.bgSurface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: BLRadius.lg, style: .continuous)
                    .strokeBorder(
                        nap.isAsleep ? theme.sleep.solid : theme.borderHairline,
                        lineWidth: BLSpacing.borderWidth
                    )
            )

            // Compact status strip: Last feed + Last diaper (plus live nursing badge when active)
            HStack(spacing: BLSpacing.space2) {
                compactStatusCell(
                    kind: lastFeed.isNursing ? .nursing : .feeding,
                    label: "Last feed",
                    value: lastFeed.elapsedText,
                    detail: lastFeed.subtitle
                )
                compactStatusCell(
                    kind: .diaper,
                    label: "Last diaper",
                    value: lastDiaper.elapsedText,
                    detail: lastDiaper.subtitle
                )
            }

            if let nursing = store.activeNursing {
                let elapsed = nursing.elapsedSeconds(asOf: store.now)
                let sideText: String = switch nursing.activeSide {
                case .left: "Left side running"
                case .right: "Right side running"
                case .both: "Running"
                case .none: "Paused"
                }
                HStack(spacing: BLSpacing.space2) {
                    BLEventIcon(kind: .nursing, size: .sm)
                    Text("Nursing · \(FormattingHelpers.formatMMSS(seconds: Int(elapsed.total)))")
                        .font(BLFont.ui(size: 14, weight: .semibold, tabularNumerals: true))
                        .foregroundStyle(theme.textPrimary)
                    Text("· \(sideText)")
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.vertical, BLSpacing.space2)
                .padding(.horizontal, BLSpacing.space3)
                .background(
                    RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
                        .fill(theme.accentSoft)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
                        .strokeBorder(theme.accentBorder, lineWidth: BLSpacing.borderWidth)
                )
            }

            Spacer(minLength: BLSpacing.space2)
        }
        .padding(.horizontal, BLSpacing.screenGutter)
        .frame(maxWidth: 640)
    }

    // MARK: - Bottom Half (Flat Sleepy-Thumb Deck)

    private var bottomDeckPane: some View {
        let nap = store.napCardState

        return VStack(spacing: BLSpacing.space3) {
            Spacer(minLength: BLSpacing.space2)

            // Primary oversized sleepy-thumb sleep/wake toggle (60pt+ height)
            BLButton(
                nap.primaryActionLabel,
                variant: nap.isAsleep ? .ink : .primary,
                size: .lg,
                isBlock: true,
                icon: nap.isAsleep ? BLSymbol.sun : BLSymbol.moon
            ) {
                store.toggleNap()
            }

            // Three oversized 60pt+ sleepy-thumb quick action pads
            HStack(spacing: BLSpacing.space2) {
                TabletopQuickPad(kind: .feeding, label: "Bottle") {
                    onOpenLog(.feeding)
                }
                TabletopQuickPad(
                    kind: .nursing,
                    label: store.activeNursing != nil ? "Nursing · live" : "Nursing"
                ) {
                    onOpenLog(.nursing)
                }
                TabletopQuickPad(kind: .diaper, label: "Diaper") {
                    onOpenLog(.diaper)
                }
            }

            if store.postureOverride == .duoTabletop {
                BLButton("Exit tabletop preview", variant: .ghost, size: .sm) {
                    store.setPostureOverride(.automatic)
                }
                .padding(.top, BLSpacing.space1)
            }

            Spacer(minLength: BLSpacing.space2)
        }
        .padding(.horizontal, BLSpacing.screenGutter)
        .frame(maxWidth: 640)
    }

    // MARK: - Subcomponents

    private func compactStatusCell(
        kind: BLEventKind,
        label: String,
        value: String,
        detail: String
    ) -> some View {
        HStack(spacing: BLSpacing.space2) {
            BLEventIcon(kind: kind, size: .sm)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(label)
                        .blMicroLabel(color: theme.textTertiary)
                        .lineLimit(1)
                    Text(value)
                        .font(BLFont.display(size: 17, weight: .medium, tabularNumerals: true))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                }
                Text(detail)
                    .blTextRole(.caption)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, BLSpacing.space3)
        .background(
            RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
                .fill(theme.bgSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
                .strokeBorder(theme.borderHairline, lineWidth: BLSpacing.borderWidth)
        )
    }

    private func tabletopProgressRail(progress: Double, isAsleep: Bool, isOver: Bool) -> some View {
        let clamped = min(1.0, max(0.0, progress))
        let fill: Color = isOver ? theme.warn.solid : (isAsleep ? theme.sleep.solid : theme.accent)
        let rail: Color = isAsleep ? theme.sleep.solid.opacity(0.25) : theme.bgRaised

        return GeometryReader { geo in
            let width = max(0, geo.size.width - 1)
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(rail)
                    .frame(width: width, height: 6)

                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(fill)
                    .frame(width: width * clamped, height: 6)

                Rectangle()
                    .fill(theme.textPrimary)
                    .frame(width: 2, height: 14)
                    .position(x: max(1, geo.size.width - 1), y: 7)
            }
        }
        .frame(height: 14)
    }

    private func tabletopElapsedText(_ raw: String) -> Text {
        let tokens = parseElapsedTokens(raw)
        var combined = Text("")
        for (index, token) in tokens.enumerated() {
            if token.isDigits {
                let prefix = index > 0 ? " " : ""
                combined = combined
                    + Text(prefix + token.value)
                        .font(BLFont.display(size: 68, weight: .regular, tabularNumerals: true))
                        .foregroundColor(theme.textPrimary)
            } else {
                combined = combined
                    + Text(token.value)
                        .font(BLFont.ui(size: 26, weight: .medium))
                        .foregroundColor(theme.textSecondary)
            }
        }
        return combined
    }

    private func tabletopCaptionText(full: String, highlight: String?) -> Text {
        let baseFont = BLFont.ui(size: 15, weight: .medium)
        let highlightFont = BLFont.ui(size: 15, weight: .semibold)

        guard let highlight, !highlight.isEmpty, let range = full.range(of: highlight) else {
            return Text(full)
                .font(baseFont)
                .foregroundColor(theme.textSecondary)
        }

        let leading = String(full[..<range.lowerBound])
        let match = String(full[range])
        let trailing = String(full[range.upperBound...])
        return Text(leading).font(baseFont).foregroundColor(theme.textSecondary)
            + Text(match).font(highlightFont).foregroundColor(theme.textPrimary)
            + Text(trailing).font(baseFont).foregroundColor(theme.textSecondary)
    }

    private struct ElapsedToken {
        let value: String
        let isDigits: Bool
    }

    private func parseElapsedTokens(_ raw: String) -> [ElapsedToken] {
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
        return result.isEmpty ? [ElapsedToken(value: raw, isDigits: true)] : result
    }
}

/// Oversized (`72pt`) sleepy-thumb quick action pad for the bottom tabletop deck.
private struct TabletopQuickPad: View {
    @Environment(\.blTheme) private var theme

    let kind: BLEventKind
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                BLEventIcon(kind: kind, size: .md)
                Text(label)
                    .font(BLFont.ui(size: 15, weight: .semibold))
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 74)
            .padding(.horizontal, BLSpacing.space2)
        }
        .buttonStyle(TabletopPadButtonStyle(kind: kind))
    }
}

private struct TabletopPadButtonStyle: ButtonStyle {
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
                .background(shape.fill(configuration.isPressed ? triplet.tint : theme.bgSurface))
                .overlay(
                    shape.strokeBorder(
                        configuration.isPressed ? triplet.solid : theme.borderStrong,
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
