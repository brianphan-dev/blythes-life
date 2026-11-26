import BlythesLifeCore
import BlythesLifeDesignSystem
import SwiftUI

/// Coordinate space name attached at `BlythesLifeRootView` so hinge rects map accurately into nested panes.
enum BLRootCoordinateSpace {
    static let name = "BlythesLifeRootCoordinateSpace"
}

/// Adaptive split container that keeps every control, card, and scan photo off the physical iPhone Duo crease,
/// provides a generous two-column workspace on iPad, and collapses cleanly on compact iPhone / folded Duo.
@MainActor
public struct HingeSplitContainer<Leading: View, Trailing: View, Compact: View>: View {
    @Environment(\.duoLayout) private var duoLayout
    @Environment(\.blTheme) private var theme

    private let padLeadingRatio: CGFloat
    private let leading: Leading
    private let trailing: Trailing
    private let compact: Compact

    public init(
        padLeadingRatio: CGFloat = 0.48,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing,
        @ViewBuilder compact: () -> Compact
    ) {
        self.padLeadingRatio = min(max(padLeadingRatio, 0.3), 0.7)
        self.leading = leading()
        self.trailing = trailing()
        self.compact = compact()
    }

    public var body: some View {
        switch duoLayout.posture {
        case .duoUnfolded(let hingeRect, let axis):
            unfoldedSplit(hingeRect: hingeRect, axis: axis)

        case .iPadRegular:
            GeometryReader { proxy in
                let totalWidth = max(0, proxy.size.width)
                let dividerWidth = BLSpacing.borderWidth
                let usableWidth = max(0, totalWidth - dividerWidth)
                let leadingWidth = floor(usableWidth * padLeadingRatio)
                let trailingWidth = max(0, usableWidth - leadingWidth)

                HStack(spacing: 0) {
                    leading
                        .frame(width: leadingWidth, height: proxy.size.height, alignment: .topLeading)
                        .clipped()

                    Rectangle()
                        .fill(theme.borderHairline)
                        .frame(width: dividerWidth, height: proxy.size.height)

                    trailing
                        .frame(width: trailingWidth, height: proxy.size.height, alignment: .topLeading)
                        .clipped()
                }
                .frame(width: totalWidth, height: proxy.size.height, alignment: .topLeading)
            }

        case .compactPhone, .duoFolded, .duoTabletop:
            compact
        }
    }

    private func unfoldedSplit(hingeRect: CGRect, axis: HingeAxis) -> some View {
        GeometryReader { proxy in
            let localFrame = proxy.frame(in: .named(BLRootCoordinateSpace.name))
            let totalWidth = max(0, proxy.size.width)
            let totalHeight = max(0, proxy.size.height)

            switch axis {
            case .vertical:
                let gutterWidth = max(12, min(hingeRect.width, totalWidth * 0.25))
                let rawLeading = hingeRect.minX - localFrame.minX
                let leadingWidth: CGFloat = {
                    if rawLeading >= 80 && (rawLeading + gutterWidth) <= (totalWidth - 80) {
                        return rawLeading
                    }
                    return max(0, floor((totalWidth - gutterWidth) / 2))
                }()
                let trailingWidth = max(0, totalWidth - leadingWidth - gutterWidth)

                HStack(spacing: 0) {
                    leading
                        .frame(width: leadingWidth, height: totalHeight, alignment: .topLeading)
                        .clipped()

                    BLHingeGutter(axis: .vertical)
                        .frame(width: gutterWidth, height: totalHeight)

                    trailing
                        .frame(width: trailingWidth, height: totalHeight, alignment: .topLeading)
                        .clipped()
                }
                .frame(width: totalWidth, height: totalHeight, alignment: .topLeading)

            case .horizontal:
                let gutterHeight = max(12, min(hingeRect.height, totalHeight * 0.25))
                let rawTop = hingeRect.minY - localFrame.minY
                let topHeight: CGFloat = {
                    if rawTop >= 80 && (rawTop + gutterHeight) <= (totalHeight - 80) {
                        return rawTop
                    }
                    return max(0, floor((totalHeight - gutterHeight) / 2))
                }()
                let bottomHeight = max(0, totalHeight - topHeight - gutterHeight)

                VStack(spacing: 0) {
                    leading
                        .frame(width: totalWidth, height: topHeight, alignment: .topLeading)
                        .clipped()

                    BLHingeGutter(axis: .horizontal)
                        .frame(width: totalWidth, height: gutterHeight)

                    trailing
                        .frame(width: totalWidth, height: bottomHeight, alignment: .topLeading)
                        .clipped()
                }
                .frame(width: totalWidth, height: totalHeight, alignment: .topLeading)
            }
        }
    }
}

public extension HingeSplitContainer where Compact == AnyView {
    /// Convenience initializer that automatically stacks `leading` above `trailing` in compact postures.
    init(
        padLeadingRatio: CGFloat = 0.48,
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder trailing: () -> Trailing
    ) {
        let leadingView = leading()
        let trailingView = trailing()
        self.init(
            padLeadingRatio: padLeadingRatio,
            leading: { leadingView },
            trailing: { trailingView },
            compact: {
                AnyView(
                    VStack(spacing: 0) {
                        leadingView
                        trailingView
                    }
                )
            }
        )
    }
}

/// Hairline-centered hinge safe-zone gutter ensuring no interactive element straddles the physical fold.
struct BLHingeGutter: View {
    @Environment(\.blTheme) private var theme
    let axis: HingeAxis

    var body: some View {
        ZStack {
            theme.bgApp
            switch axis {
            case .vertical:
                Rectangle()
                    .fill(theme.borderHairline)
                    .frame(width: BLSpacing.borderWidth)
            case .horizontal:
                Rectangle()
                    .fill(theme.borderHairline)
                    .frame(height: BLSpacing.borderWidth)
            }
        }
        .accessibilityHidden(true)
    }
}

/// Crisp wrapping flow layout for preset chips and legends (`8pt` spacing by default).
struct BLFlowLayout: Layout {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat

    init(horizontalSpacing: CGFloat = BLSpacing.space2, verticalSpacing: CGFloat = BLSpacing.space2) {
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let layout = computeRows(maxWidth: maxWidth, subviews: subviews)
        return layout.size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let layout = computeRows(maxWidth: bounds.width, subviews: subviews)
        for (index, subview) in subviews.enumerated() where index < layout.origins.count {
            let origin = layout.origins[index]
            subview.place(
                at: CGPoint(x: bounds.minX + origin.x, y: bounds.minY + origin.y),
                proposal: .unspecified
            )
        }
    }

    private func computeRows(
        maxWidth: CGFloat,
        subviews: Subviews
    ) -> (size: CGSize, origins: [CGPoint]) {
        var origins: [CGPoint] = []
        origins.reserveCapacity(subviews.count)

        var cursorX: CGFloat = 0
        var cursorY: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if cursorX > 0 && cursorX + size.width > maxWidth {
                cursorX = 0
                cursorY += rowHeight + verticalSpacing
                rowHeight = 0
            }
            origins.append(CGPoint(x: cursorX, y: cursorY))
            cursorX += size.width + horizontalSpacing
            rowHeight = max(rowHeight, size.height)
            maxRowWidth = max(maxRowWidth, cursorX - horizontalSpacing)
        }

        let totalHeight = subviews.isEmpty ? 0 : cursorY + rowHeight
        let resolvedWidth = maxWidth.isFinite ? max(maxRowWidth, min(maxWidth, maxRowWidth)) : maxRowWidth
        return (CGSize(width: resolvedWidth, height: totalHeight), origins)
    }
}
