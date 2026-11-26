import SwiftUI

// MARK: - BLTabBarItem & BLTabBar

/// Descriptor for a tab destination in `BLTabBar`.
public struct BLTabBarItem<ID: Hashable>: Identifiable, Hashable {
    public let id: ID
    public let label: String
    public let icon: String
    public let badgeCount: Int?

    public init(id: ID, label: String, icon: String, badgeCount: Int? = nil) {
        self.id = id
        self.label = label
        self.icon = icon
        self.badgeCount = badgeCount
    }
}

extension BLTabBarItem: Sendable where ID: Sendable {}

/// Opaque `56pt` bottom tab bar with top hairline and a `28×2` honey active indicator bar.
public struct BLTabBar<ID: Hashable>: View {
    @Environment(\.blTheme) private var theme

    private let items: [BLTabBarItem<ID>]
    @Binding private var selection: ID

    public init(items: [BLTabBarItem<ID>], selection: Binding<ID>) {
        self.items = items
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                let isActive = item.id == selection
                Button {
                    selection = item.id
                } label: {
                    ZStack(alignment: .top) {
                        if isActive {
                            Rectangle()
                                .fill(theme.accent)
                                .frame(width: 28, height: 2)
                        }

                        VStack(spacing: 3) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: item.icon)
                                    .font(.system(size: 20, weight: isActive ? .semibold : .regular))
                                    .frame(width: 26, height: 24)

                                if let count = item.badgeCount, count > 0 {
                                    Text("\(count)")
                                        .font(BLFont.ui(size: 10, weight: .bold, tabularNumerals: true))
                                        .foregroundStyle(theme.textOnAccent)
                                        .padding(.horizontal, 4)
                                        .frame(minWidth: 16, minHeight: 16, maxHeight: 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .fill(theme.accent)
                                        )
                                        .offset(x: 10, y: -4)
                                }
                            }

                            Text(item.label)
                                .font(BLFont.ui(size: 11, weight: .semibold))
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .foregroundStyle(isActive ? theme.textPrimary : theme.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: BLSpacing.tabBarHeight)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .padding(.horizontal, BLSpacing.space2)
        .frame(height: BLSpacing.tabBarHeight)
        .background(theme.bgApp)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.borderHairline)
                .frame(height: BLSpacing.borderWidth)
        }
    }
}

// MARK: - BLSheetContainer

/// Bottom sheet surface with `24pt` top-only corners, `36×4` grabber, serif header, scrollable body, and sticky footer.
public struct BLSheetContainer<Icon: View, Content: View, Footer: View>: View {
    @Environment(\.blTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let isPresented: Bool
    private let title: String
    private let showScrim: Bool
    private let onClose: () -> Void
    private let icon: Icon
    private let content: Content
    private let footer: Footer

    public init(
        isPresented: Bool = true,
        title: String,
        showScrim: Bool = true,
        onClose: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.isPresented = isPresented
        self.title = title
        self.showScrim = showScrim
        self.onClose = onClose
        self.icon = icon()
        self.content = content()
        self.footer = footer()
    }

    public var body: some View {
        let topShape = UnevenRoundedRectangle(
            topLeadingRadius: BLRadius.xl,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 0,
            topTrailingRadius: BLRadius.xl,
            style: .continuous
        )

        ZStack(alignment: .bottom) {
            if showScrim && isPresented {
                theme.scrim
                    .ignoresSafeArea()
                    .onTapGesture(perform: onClose)
                    .transition(.opacity)
            }

            if isPresented {
                VStack(spacing: 0) {
                    // Grabber
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(theme.borderStrong)
                        .frame(width: 36, height: 4)
                        .padding(.top, BLSpacing.space2)

                    // Header
                    HStack(spacing: 10) {
                        icon
                        Text(title)
                            .blTextRole(.title)
                            .foregroundStyle(theme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        BLIconButton(icon: BLSymbol.close, label: "Close", action: onClose)
                    }
                    .padding(.top, BLSpacing.space2)
                    .padding(.leading, BLSpacing.space5)
                    .padding(.trailing, 10)
                    .padding(.bottom, 6)

                    // Scrollable body
                    ScrollView {
                        VStack(alignment: .leading, spacing: BLSpacing.space5) {
                            content
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, BLSpacing.space2)
                        .padding(.horizontal, BLSpacing.space5)
                        .padding(.bottom, BLSpacing.space5)
                    }
                    .scrollIndicators(.hidden)

                    // Sticky footer
                    if Footer.self != EmptyView.self {
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(theme.borderHairline)
                                .frame(height: BLSpacing.borderWidth)
                            footer
                                .padding(.top, BLSpacing.space3)
                                .padding(.horizontal, BLSpacing.space5)
                                .padding(.bottom, BLSpacing.space5)
                        }
                    }
                }
                .foregroundStyle(theme.textPrimary)
                .background(topShape.fill(theme.bgRaised))
                .clipShape(topShape)
                .overlay(
                    topShape.strokeBorder(
                        theme.nightFloatOutline ?? theme.borderHairline,
                        lineWidth: BLSpacing.borderWidth
                    )
                )
                .shadow(
                    color: theme.sheetShadowColor,
                    radius: 16,
                    x: 0,
                    y: -8
                )
                .transition(reduceMotion ? .opacity : .move(edge: .bottom))
            }
        }
        .animation(BLMotion.easeSheet(reducedMotion: reduceMotion), value: isPresented)
    }
}

extension BLSheetContainer where Icon == EmptyView {
    public init(
        isPresented: Bool = true,
        title: String,
        showScrim: Bool = true,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.init(
            isPresented: isPresented,
            title: title,
            showScrim: showScrim,
            onClose: onClose,
            icon: { EmptyView() },
            content: content,
            footer: footer
        )
    }
}

extension BLSheetContainer where Footer == EmptyView {
    public init(
        isPresented: Bool = true,
        title: String,
        showScrim: Bool = true,
        onClose: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            isPresented: isPresented,
            title: title,
            showScrim: showScrim,
            onClose: onClose,
            icon: icon,
            content: content,
            footer: { EmptyView() }
        )
    }
}

extension BLSheetContainer where Icon == EmptyView, Footer == EmptyView {
    public init(
        isPresented: Bool = true,
        title: String,
        showScrim: Bool = true,
        onClose: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.init(
            isPresented: isPresented,
            title: title,
            showScrim: showScrim,
            onClose: onClose,
            icon: { EmptyView() },
            content: content,
            footer: { EmptyView() }
        )
    }
}

// MARK: - BLToast

/// Reversible confirmation toast with honey Undo action, floating shadow in Day and 1px outline in Night.
public struct BLToast: View {
    @Environment(\.blTheme) private var theme

    private let message: String
    private let icon: String?
    private let actionLabel: String?
    private let onAction: (() -> Void)?

    public init(
        message: String,
        icon: String? = BLSymbol.check,
        actionLabel: String? = nil,
        onAction: (() -> Void)? = nil
    ) {
        self.message = message
        self.icon = icon
        self.actionLabel = actionLabel
        self.onAction = onAction
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
        HStack(spacing: 10) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(theme.toastFg)
            }

            Text(message)
                .blTextRole(.callout)
                .foregroundStyle(theme.toastFg)
                .frame(maxWidth: .infinity, alignment: .leading)

            if let actionLabel, let onAction {
                Button(action: onAction) {
                    Text(actionLabel)
                        .font(BLFont.ui(size: 15, weight: .semibold))
                        .foregroundStyle(theme.toastAction)
                        .padding(.horizontal, BLSpacing.space3)
                        .frame(height: 40)
                        .contentShape(RoundedRectangle(cornerRadius: BLRadius.sm, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
        .padding(.leading, BLSpacing.space4)
        .padding(.trailing, 6)
        .frame(minHeight: 52)
        .background(shape.fill(theme.toastBg))
        .overlay(
            shape.strokeBorder(
                theme.nightFloatOutline ?? .clear,
                lineWidth: BLSpacing.borderWidth
            )
        )
        .shadow(color: theme.floatShadowPrimaryColor, radius: 10, x: 0, y: 6)
        .shadow(color: theme.floatShadowSecondaryColor, radius: 1, x: 0, y: 1)
    }
}
