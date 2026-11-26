import BlythesLifeCore
import BlythesLifeDesignSystem
import BlythesLifeShared
import SwiftUI

/// Primary navigation destinations across iPhone tab bar, iPhone Duo, and iPad sidebar.
public enum BlythesLifeTab: String, CaseIterable, Identifiable, Sendable, Hashable {
    case today
    case rhythm
    case sheets
    case settings

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .today: "Today"
        case .rhythm: "Rhythm"
        case .sheets: "Sheets"
        case .settings: "Settings"
        }
    }

    public var symbolName: String {
        switch self {
        case .today: BLSymbol.sun
        case .rhythm: BLSymbol.calendar
        case .sheets: BLSymbol.scan
        case .settings: BLSymbol.settings
        }
    }
}

/// Root universal SwiftUI entry point for Blythe's Life across iPhone, iPhone Duo (Folded, Unfolded, Tabletop), and iPad.
@MainActor
public struct BlythesLifeRootView: View {
    @Environment(\.scenePhase) private var scenePhase

    @State private var store: BlythesLifeStore
    @State private var selectedTab: BlythesLifeTab = .today
    @State private var activeSheet: LogSheetRequest?
    @State private var reviewingSheet: ScannedSheetRecord?
    @State private var splitVisibility: NavigationSplitViewVisibility = .all

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    #endif
    #if canImport(UIKit)
    @State private var hardwareSnapshot = DuoHardwareSnapshot()
    #endif

    public init(store: BlythesLifeStore? = nil) {
        self._store = State(initialValue: store ?? BlythesLifeStore())
    }

    public var body: some View {
        GeometryReader { proxy in
            let duoLayout = resolveDuoLayout(for: proxy.size)
            let effectiveColorMode: BLColorMode = duoLayout.shouldForceNightMode
                ? .night
                : store.colorModePreference.blColorMode

            BlythesLifeRootShell(
                store: store,
                duoLayout: duoLayout,
                selectedTab: $selectedTab,
                activeSheet: $activeSheet,
                reviewingSheet: $reviewingSheet,
                splitVisibility: $splitVisibility
            )
            .frame(width: proxy.size.width, height: proxy.size.height)
            .coordinateSpace(name: BLRootCoordinateSpace.name)
            .environment(\.duoLayout, duoLayout)
            .blTheme(effectiveColorMode)
        }
        #if canImport(UIKit)
        .background {
            DuoHardwareObserverView { snapshot in
                hardwareSnapshot = snapshot
            }
            .allowsHitTesting(false)
        }
        #endif
        .task {
            store.startClock()
            await store.resumeLiveSession()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
            }
            store.stopClock()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { @MainActor in
                    await store.resumeLiveSession()
                }
            }
        }
        .onDisappear {
            store.stopClock()
        }
        #if os(iOS) && canImport(ActivityKit)
        .onChange(of: store.activeNapStart) { _, _ in
            Task { @MainActor in
                await BlytheLiveActivityCoordinator.sync(with: store)
            }
        }
        #endif
    }

    private func resolveDuoLayout(for size: CGSize) -> DuoLayoutState {
        #if os(iOS)
        DuoPostureResolver.resolve(
            containerSize: size,
            horizontalSizeClass: horizontalSizeClass,
            hingeStatus: hardwareSnapshot.hingeStatus,
            hingeAngle: hardwareSnapshot.hingeAngleRadians,
            divisionRect: hardwareSnapshot.divisionRect,
            override: store.postureOverride
        )
        #else
        let sizeClass: LayoutSizeClass = size.width >= 760 ? .regular : .compact
        return DuoPostureResolver.resolve(
            containerSize: size,
            horizontalSizeClass: sizeClass,
            hingeStatus: nil,
            hingeAngle: nil,
            divisionRect: nil,
            override: store.postureOverride
        )
        #endif
    }
}

// MARK: - Themed Root Shell

@MainActor
private struct BlythesLifeRootShell: View {
    @Environment(\.blTheme) private var theme
    @Environment(\.blColorMode) private var colorMode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let store: BlythesLifeStore
    let duoLayout: DuoLayoutState
    @Binding var selectedTab: BlythesLifeTab
    @Binding var activeSheet: LogSheetRequest?
    @Binding var reviewingSheet: ScannedSheetRecord?
    @Binding var splitVisibility: NavigationSplitViewVisibility

    private var tabItems: [BLTabBarItem<BlythesLifeTab>] {
        let pendingCount = store.pendingReviewCount
        return [
            BLTabBarItem(id: .today, label: "Today", icon: BLSymbol.sun),
            BLTabBarItem(id: .rhythm, label: "Rhythm", icon: BLSymbol.calendar),
            BLTabBarItem(
                id: .sheets,
                label: "Sheets",
                icon: BLSymbol.scan,
                badgeCount: pendingCount > 0 ? pendingCount : nil
            ),
            BLTabBarItem(id: .settings, label: "Settings", icon: BLSymbol.settings)
        ]
    }

    var body: some View {
        ZStack {
            theme.bgApp.ignoresSafeArea()

            if store.sessionStage != .ready {
                OnboardingView(store: store)
            } else {
                // Primary posture chrome
                switch duoLayout.posture {
                case .duoTabletop(let hingeRect):
                    TabletopNightstandView(
                        store: store,
                        hingeRect: hingeRect,
                        onOpenLog: openLogSheet
                    )

                case .iPadRegular:
                    iPadWorkspace

                case .compactPhone, .duoFolded, .duoUnfolded:
                    tabbedWorkspace
                }

                // Full-screen Scan Review & Confirm overlay
                if let sheet = reviewingSheet {
                    ScanReviewView(
                        sheet: sheet,
                        store: store,
                        onCancel: {
                            withAnimation(BLMotion.easeOut(duration: BLMotion.base, reducedMotion: reduceMotion)) {
                                reviewingSheet = nil
                            }
                        },
                        onComplete: {
                            withAnimation(BLMotion.easeOut(duration: BLMotion.base, reducedMotion: reduceMotion)) {
                                reviewingSheet = nil
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(20)
                }

                // Daily-care LogSheet overlay
                if let request = activeSheet {
                    ZStack(alignment: .bottom) {
                        if duoLayout.usesSplitLayout {
                            theme.scrim
                                .ignoresSafeArea()
                                .onTapGesture { activeSheet = nil }
                        }
                        LogSheetView(
                            store: store,
                            request: request,
                            showScrim: !duoLayout.usesSplitLayout,
                            onClose: { activeSheet = nil }
                        )
                        .id(request.id)
                        .frame(maxWidth: duoLayout.usesSplitLayout ? 540 : .infinity)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    .zIndex(30)
                }
            }

            // Floating Undo confirmation toast (active across onboarding and main workspace)
            if let toast = store.toast {
                VStack {
                    Spacer()
                    BLToast(
                        message: toast.message,
                        icon: BLSymbol.check,
                        actionLabel: toast.canUndo ? "Undo" : nil,
                        onAction: toast.canUndo ? { store.undoLastToast() } : nil
                    )
                    .frame(maxWidth: 440)
                    .padding(.horizontal, BLSpacing.screenGutter)
                    .padding(.bottom, toastBottomInset)
                }
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
                .zIndex(40)
            }
        }
        .onChange(of: store.sessionStage) { _, newStage in
            if newStage != .ready {
                activeSheet = nil
                reviewingSheet = nil
                selectedTab = .today
            }
        }
        .animation(
            BLMotion.easeOut(duration: BLMotion.base, reducedMotion: reduceMotion),
            value: store.toast?.id
        )
    }

    // MARK: - iPhone & iPhone Duo Tabbed Chrome

    private var tabbedWorkspace: some View {
        VStack(spacing: 0) {
            activeDestinationView
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            bottomNavigationBar
        }
    }

    @ViewBuilder
    private var bottomNavigationBar: some View {
        if case .duoUnfolded(let hingeRect, .vertical) = duoLayout.posture {
            // Split the 4 tabs cleanly around the vertical hinge (2 left, 2 right) so no tab crosses the crease.
            let leftTabs = Array(tabItems.prefix(2))
            let rightTabs = Array(tabItems.suffix(2))
            let gutterWidth = max(12, min(hingeRect.width, 48))

            HStack(spacing: 0) {
                BLTabBar(items: leftTabs, selection: $selectedTab)
                BLHingeGutter(axis: .vertical)
                    .frame(width: gutterWidth, height: BLSpacing.tabBarHeight)
                    .overlay(alignment: .top) {
                        Rectangle()
                            .fill(theme.borderHairline)
                            .frame(height: BLSpacing.borderWidth)
                    }
                BLTabBar(items: rightTabs, selection: $selectedTab)
            }
            .frame(height: BLSpacing.tabBarHeight)
            .background(theme.bgApp)
        } else {
            BLTabBar(items: tabItems, selection: $selectedTab)
        }
    }

    // MARK: - iPad NavigationSplitView Chrome

    private var iPadWorkspace: some View {
        NavigationSplitView(columnVisibility: $splitVisibility) {
            iPadSidebar
                .navigationSplitViewColumnWidth(min: 228, ideal: 256, max: 288)
                #if os(iOS)
                .toolbar(.hidden, for: .navigationBar)
                #endif
        } detail: {
            activeDestinationView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(theme.bgApp)
                #if os(iOS)
                .toolbar(.hidden, for: .navigationBar)
                #endif
        }
        .navigationSplitViewStyle(.balanced)
        .background(theme.bgApp)
    }

    private var iPadSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Wordmark header (Newsreader display — no drawn logo)
            VStack(alignment: .leading, spacing: 2) {
                Text(store.headerDateTitle)
                    .blMicroLabel()
                Text("Blythe's Life")
                    .font(BLFont.display(size: 26, weight: .medium, tabularNumerals: false))
                    .tracking(BLFont.displayTrackingRatio * 26)
                    .foregroundStyle(theme.textPrimary)
            }
            .padding(.top, BLSpacing.space5)
            .padding(.horizontal, BLSpacing.space4)
            .padding(.bottom, BLSpacing.space4)

            Rectangle()
                .fill(theme.borderHairline)
                .frame(height: BLSpacing.borderWidth)

            // 4 primary destinations
            VStack(spacing: BLSpacing.space1) {
                ForEach(BlythesLifeTab.allCases) { tab in
                    let isSelected = selectedTab == tab
                    let pendingCount = tab == .sheets ? store.pendingReviewCount : 0

                    Button {
                        selectedTab = tab
                    } label: {
                        HStack(spacing: BLSpacing.space3) {
                            Image(systemName: tab.symbolName)
                                .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                                .foregroundStyle(isSelected ? theme.accentText : theme.textSecondary)
                                .frame(width: 22)

                            Text(tab.title)
                                .font(BLFont.ui(size: 16, weight: isSelected ? .semibold : .medium))
                                .foregroundStyle(theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if pendingCount > 0 {
                                BLBadge("\(pendingCount)", tone: .accent)
                            }
                        }
                        .padding(.horizontal, BLSpacing.space3)
                        .frame(height: BLHitTarget.min)
                        .background(
                            RoundedRectangle(cornerRadius: BLRadius.sm, style: .continuous)
                                .fill(isSelected ? theme.accentSoft : .clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: BLRadius.sm, style: .continuous)
                                .strokeBorder(
                                    isSelected ? theme.accentBorder : .clear,
                                    lineWidth: BLSpacing.borderWidth
                                )
                        )
                        .contentShape(RoundedRectangle(cornerRadius: BLRadius.sm, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.top, BLSpacing.space3)
            .padding(.horizontal, BLSpacing.space3)

            Spacer()

            Rectangle()
                .fill(theme.borderHairline)
                .frame(height: BLSpacing.borderWidth)

            // Sync status indicator + Day/Night toggle
            HStack(spacing: BLSpacing.space3) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(syncStatusTitle)
                        .blMicroLabel(color: syncStatusColor)
                    Text(store.profile.displayName + (store.profileAgeLabel.isEmpty ? "" : " · \(store.profileAgeLabel)"))
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                BLIconButton(
                    icon: colorMode == .night ? BLSymbol.sun : BLSymbol.moon,
                    label: "Toggle night mode",
                    variant: .outline
                ) {
                    store.toggleTheme()
                }
            }
            .padding(BLSpacing.space4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.bgSurface)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(theme.borderHairline)
                .frame(width: BLSpacing.borderWidth)
        }
    }

    // MARK: - Active Tab Content

    @ViewBuilder
    private var activeDestinationView: some View {
        switch selectedTab {
        case .today:
            TodayView(
                store: store,
                onOpenLog: openLogSheet,
                onEditEvent: openEditSheet,
                onOpenReview: openReviewSheet
            )
        case .rhythm:
            RhythmView(
                store: store,
                onEditEvent: openEditSheet
            )
        case .sheets:
            SheetsView(
                store: store,
                onOpenReview: openReviewSheet
            )
        case .settings:
            SettingsView(store: store)
        }
    }

    // MARK: - Navigation Actions & Layout Metrics

    private func openLogSheet(_ kind: BLEventKind) {
        store.dismissToast()
        activeSheet = LogSheetRequest(kind: kind, editingEvent: nil)
    }

    private func openEditSheet(_ event: EventDTO) {
        store.dismissToast()
        activeSheet = LogSheetRequest(kind: event.blEventKind, editingEvent: event)
    }

    private func openReviewSheet(_ sheet: ScannedSheetRecord) {
        store.dismissToast()
        reviewingSheet = sheet
    }

    private var toastBottomInset: CGFloat {
        if store.sessionStage != .ready {
            return BLSpacing.space5
        }
        if duoLayout.isTabletop || duoLayout.isPad {
            return BLSpacing.space5
        }
        if selectedTab == .today && !duoLayout.usesSplitLayout {
            // Sit cleanly above the 4×2 quick-log dock + 56pt tab bar
            return 214
        }
        return BLSpacing.tabBarHeight + BLSpacing.space4
    }

    private var syncStatusTitle: String {
        if store.isDemoPreview {
            return "Sample preview"
        }
        switch store.syncStatus {
        case .localOnly:
            return "Local preview"
        case .synced:
            return "Updated on every device"
        case .syncing:
            return "Updating…"
        case .offline(let pendingCount):
            return "Offline · \(pendingCount) waiting"
        case .error:
            return "Needs a look"
        }
    }

    private var syncStatusColor: Color {
        if store.isDemoPreview {
            return theme.textSecondary
        }
        switch store.syncStatus {
        case .synced:
            return theme.ok.ink
        case .offline, .error:
            return theme.warn.ink
        case .localOnly, .syncing:
            return theme.textSecondary
        }
    }
}

// MARK: - Internal Model-to-DesignSystem Mappings

extension AppColorModePreference {
    var blColorMode: BLColorMode {
        switch self {
        case .day: .day
        case .night: .night
        }
    }
}

extension EventDTO {
    var blEventKind: BLEventKind {
        switch metadata {
        case .sleep:
            .sleep
        case .feeding(let meta):
            meta.method == .breast ? .nursing : .feeding
        case .pump:
            .pump
        case .diaper:
            .diaper
        case .meal:
            .meal
        case .bath:
            .bath
        case .medicine:
            .medicine
        case .note:
            .note
        }
    }
}

extension ScanReviewDraftItem {
    var blEventKind: BLEventKind {
        switch metadata {
        case .sleep:
            .sleep
        case .feeding(let meta):
            meta.method == .breast ? .nursing : .feeding
        case .pump:
            .pump
        case .diaper:
            .diaper
        case .meal:
            .meal
        case .bath:
            .bath
        case .medicine:
            .medicine
        case .note:
            .note
        }
    }

    var blBadgeTone: BLBadge.Tone {
        if isSuggestion {
            return .neutral
        }
        switch matchAction {
        case .create: return .accent
        case .skipDuplicate: return .neutral
        case .updateExisting: return .ok
        }
    }
}

extension EventSource {
    var blSourceIcon: String? {
        switch self {
        case .manual:
            nil
        case .paperScan:
            BLSymbol.scan
        case .importHuckleberry:
            BLSymbol.importFile
        case .controlCenter:
            BLSymbol.bolt
        }
    }
}
