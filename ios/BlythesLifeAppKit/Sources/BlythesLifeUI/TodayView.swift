import BlythesLifeCore
import BlythesLifeDesignSystem
import BlythesLifeShared
import SwiftUI

/// Primary Today screen with hero NapCard, live Nursing banner, GlanceStats, pending Grandma's sheet banner,
/// Today timeline, and adaptive Quick-Log grid (bottom 4×2 dock on iPhone/Duo Folded; left-pane 2×4 cards on Duo Unfolded & iPad).
@MainActor
public struct TodayView: View {
    private struct PendingRequestAction: Equatable {
        let id: UUID
        let approving: Bool
    }

    private static let quickKinds: [BLEventKind] = [
        .feeding, .nursing, .pump, .diaper,
        .meal, .bath, .medicine, .note
    ]

    @Environment(\.blTheme) private var theme
    @Environment(\.blColorMode) private var colorMode
    @Environment(\.duoLayout) private var duoLayout

    private let store: BlythesLifeStore
    private let onOpenLog: (BLEventKind) -> Void
    private let onEditEvent: (EventDTO) -> Void
    private let onOpenReview: (ScannedSheetRecord) -> Void

    @State private var pendingRequestAction: PendingRequestAction?

    public init(
        store: BlythesLifeStore,
        onOpenLog: @escaping (BLEventKind) -> Void,
        onEditEvent: @escaping (EventDTO) -> Void,
        onOpenReview: @escaping (ScannedSheetRecord) -> Void
    ) {
        self.store = store
        self.onOpenLog = onOpenLog
        self.onEditEvent = onEditEvent
        self.onOpenReview = onOpenReview
    }

    public var body: some View {
        HingeSplitContainer(
            padLeadingRatio: 0.48,
            leading: {
                splitLeadingPane
            },
            trailing: {
                splitTrailingPane
            },
            compact: {
                compactLayout
            }
        )
        .background(theme.bgApp)
    }

    // MARK: - Compact Layout (iPhone & iPhone Duo Folded)

    private var compactLayout: some View {
        VStack(spacing: 0) {
            headerView

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    heroAndSummaryStack
                    timelineSectionHeader
                    timelineList
                }
                .padding(.horizontal, BLSpacing.screenGutter)
                .padding(.bottom, BLSpacing.space5)
            }
            .scrollIndicators(.hidden)

            compactQuickDock
        }
        .background(theme.bgApp)
    }

    private var compactQuickDock: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: BLSpacing.space2), count: 4)
        return LazyVGrid(columns: columns, spacing: BLSpacing.space2) {
            ForEach(Self.quickKinds) { kind in
                BLQuickTile(kind: kind, label: kind.compactLabel, size: .sm) {
                    onOpenLog(kind)
                }
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, BLSpacing.screenGutter)
        .background(theme.bgApp)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(theme.borderHairline)
                .frame(height: BLSpacing.borderWidth)
        }
    }

    // MARK: - Split Layout (iPhone Duo Unfolded & iPad)

    private var splitLeadingPane: some View {
        let twoColumns = Array(repeating: GridItem(.flexible(), spacing: BLSpacing.space2), count: 2)

        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerView
                    .padding(.horizontal, -BLSpacing.screenGutter)

                heroAndSummaryStack

                HStack {
                    Text("Quick log")
                        .blMicroLabel()
                    Spacer()
                }
                .padding(.top, BLSpacing.space5)
                .padding(.bottom, BLSpacing.space2)

                LazyVGrid(columns: twoColumns, spacing: BLSpacing.space2) {
                    ForEach(Self.quickKinds) { kind in
                        BLQuickTile(
                            kind: kind,
                            label: kind.displayLabel,
                            sub: splitTileSubtitle(for: kind),
                            size: .lg
                        ) {
                            onOpenLog(kind)
                        }
                    }
                }
            }
            .padding(.horizontal, BLSpacing.screenGutter)
            .padding(.bottom, BLSpacing.space6)
        }
        .scrollIndicators(.hidden)
        .background(theme.bgApp)
    }

    private var splitTrailingPane: some View {
        let count = store.todayEvents.count
        let entryNoun = count == 1 ? "entry" : "entries"

        return VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .blMicroLabel()
                Spacer()
                Text(count == 0 ? "0 entries" : "\(count) \(entryNoun) · tap to edit")
                    .blMicroLabel()
            }
            .padding(.horizontal, BLSpacing.screenGutter)
            .padding(.top, BLSpacing.space4)
            .padding(.bottom, BLSpacing.space3)

            ScrollView {
                timelineList
                    .padding(.horizontal, BLSpacing.screenGutter)
                    .padding(.bottom, BLSpacing.space6)
            }
            .scrollIndicators(.hidden)
        }
        .background(theme.bgApp)
    }

    // MARK: - Shared Sections

    private var headerView: some View {
        HStack(alignment: .bottom, spacing: BLSpacing.space2) {
            VStack(alignment: .leading, spacing: 2) {
                Text(store.headerDateTitle)
                    .blMicroLabel()

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(store.profile.displayName)
                        .blTextRole(.display)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)

                    if !store.profileAgeLabel.isEmpty {
                        Text(store.profileAgeLabel)
                            .blTextRole(.callout)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if store.isDemoPreview {
                BLBadge("Sample", tone: .neutral)
                    .padding(.bottom, 10)
            }

            #if DEBUG
            if store.postureOverride != .automatic {
                BLBadge(store.postureOverride.shortTitle, tone: .accent)
                    .padding(.bottom, 10)
            }
            #endif

            BLIconButton(
                icon: colorMode == .night ? BLSymbol.sun : BLSymbol.moon,
                label: "Toggle night mode",
                variant: .outline
            ) {
                store.toggleTheme()
            }
        }
        .padding(.top, 6)
        .padding(.horizontal, BLSpacing.screenGutter)
        .padding(.bottom, BLSpacing.space3)
    }

    @ViewBuilder
    private var heroAndSummaryStack: some View {
        let nap = store.napCardState
        let feed = store.feedSweetSpot
        let meal = store.mealSweetSpot
        let lastDiaper = store.lastDiaperGlance

        BLNapCard(
            isAsleep: nap.isAsleep,
            label: nap.label,
            elapsed: nap.elapsedText,
            progress: nap.progress,
            isOver: nap.isOver,
            caption: nap.fullCaption,
            captionHighlight: nap.highlightedClockTime,
            actionLabel: nap.primaryActionLabel,
            onAction: { store.toggleNap() },
            secondaryLabel: nap.secondaryActionLabel,
            onSecondary: { onOpenLog(.sleep) }
        )

        if store.shouldSuggestSwitchActiveSleepToNight {
            lateNapSwitchBanner
                .padding(.top, BLSpacing.space2)
        }

        if let nursing = store.activeNursing {
            activeNursingBanner(session: nursing)
                .padding(.top, BLSpacing.space2)
        }

        if let pump = store.activePump {
            activePumpBanner(session: pump)
                .padding(.top, BLSpacing.space2)
        }

        HStack(alignment: .top, spacing: BLSpacing.space2) {
            BLGlanceStat(
                kind: feed.isNursing ? .nursing : .feeding,
                label: feed.title,
                value: feed.primaryValue,
                sub: feed.subtitle,
                progress: feed.progress,
                isOver: feed.isOver,
                footer: feed.fullSweetSpotCaption,
                footerHighlight: feed.highlightedClockTime
            ) {
                onOpenLog(feed.isNursing ? .nursing : .feeding)
            }

            BLGlanceStat(
                kind: .meal,
                label: meal.title,
                value: meal.primaryValue,
                sub: meal.subtitle,
                progress: meal.progress,
                isOver: meal.isOver,
                footer: meal.fullSweetSpotCaption,
                footerHighlight: meal.highlightedClockTime
            ) {
                onOpenLog(.meal)
            }
        }
        .padding(.top, BLSpacing.space2)

        BLCard(isFlush: true, onTap: { onOpenLog(.diaper) }) {
            HStack(spacing: BLSpacing.space3) {
                BLEventIcon(kind: .diaper, size: .sm)

                VStack(alignment: .leading, spacing: 1) {
                    Text(lastDiaper.title)
                        .blMicroLabel()
                    Text(lastDiaper.subtitle)
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(lastDiaper.elapsedText)
                    .font(BLFont.display(size: 20, weight: .medium, tabularNumerals: true))
                    .foregroundStyle(theme.textPrimary)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
        }
        .padding(.top, BLSpacing.space2)

        if let pendingSheet = store.pendingReviewSheet {
            pendingSheetBanner(sheet: pendingSheet)
                .padding(.top, BLSpacing.space2)
        }

        if store.isCurrentUserHouseholdOwner,
           let pendingReq = store.pendingHouseholdJoinRequests.first
        {
            pendingJoinRequestBanner(request: pendingReq)
                .padding(.top, BLSpacing.space2)
        }
    }

    private var lateNapSwitchBanner: some View {
        BLCard(tone: .accent, isFlush: true) {
            HStack(alignment: .center, spacing: BLSpacing.space3) {
                BLEventIcon(kind: .sleep, size: .sm)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Running long for a late nap")
                        .font(BLFont.ui(size: 15, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)

                    Text("Count this stretch as night sleep?")
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                BLButton("Switch to night", variant: .primary, size: .sm) {
                    store.switchActiveSleepType(.night)
                }
            }
            .padding(.vertical, BLSpacing.space3)
            .padding(.horizontal, 14)
        }
    }

    private func activeNursingBanner(session: ActiveNursingSession) -> some View {
        let elapsed = session.elapsedSeconds(asOf: store.now)
        let stateDescription: String = switch session.activeSide {
        case .left: "Left side running"
        case .right: "Right side running"
        case .both: "Running"
        case .none: "Paused"
        }

        return BLCard(tone: .accent, isFlush: true, onTap: { onOpenLog(.nursing) }) {
            HStack(spacing: BLSpacing.space3) {
                BLEventIcon(kind: .nursing, size: .md)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Nursing · \(FormattingHelpers.formatMMSS(seconds: Int(elapsed.total)))")
                        .font(BLFont.ui(size: 16, weight: .semibold, tabularNumerals: true))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Text("\(stateDescription) · tap to switch or finish")
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: BLSymbol.chevronRight)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.vertical, BLSpacing.space3)
            .padding(.horizontal, 14)
        }
    }

    private func activePumpBanner(session: ActivePumpSession) -> some View {
        let elapsed = session.elapsedSeconds(asOf: store.now)
        let stateDescription = session.isRunning ? "Running" : "Paused"

        return BLCard(tone: .accent, isFlush: true, onTap: { onOpenLog(.pump) }) {
            HStack(spacing: BLSpacing.space3) {
                BLEventIcon(kind: .pump, size: .md)

                VStack(alignment: .leading, spacing: 1) {
                    Text("Pump · \(FormattingHelpers.formatMMSS(seconds: Int(elapsed)))")
                        .font(BLFont.ui(size: 16, weight: .semibold, tabularNumerals: true))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Text("\(stateDescription) · \(FormattingHelpers.formatSide(session.side)) · tap to finish")
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: BLSymbol.chevronRight)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.vertical, BLSpacing.space3)
            .padding(.horizontal, 14)
        }
    }

    private func pendingSheetBanner(sheet: ScannedSheetRecord) -> some View {
        let newCount = sheet.newDraftCount
        let noun = newCount == 1 ? "entry" : "entries"

        return BLCard(tone: .accent, isFlush: true, onTap: { onOpenReview(sheet) }) {
            HStack(spacing: BLSpacing.space3) {
                Image(systemName: BLSymbol.scan)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(theme.textPrimary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: 1) {
                    Text(sheet.title)
                        .font(BLFont.ui(size: 16, weight: .semibold))
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    Text("\(newCount) new \(noun) to review")
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: BLSymbol.chevronRight)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.textSecondary)
            }
            .padding(.vertical, BLSpacing.space3)
            .padding(.horizontal, 14)
        }
    }

    private func pendingJoinRequestBanner(request: HouseholdJoinRequestDTO) -> some View {
        let isBusy = pendingRequestAction?.id == request.id
        let isApproving = isBusy && (pendingRequestAction?.approving == true)
        let isDeclining = isBusy && (pendingRequestAction?.approving == false)

        return BLCard(tone: .accent, isFlush: true) {
            VStack(alignment: .leading, spacing: BLSpacing.space3) {
                HStack(spacing: BLSpacing.space3) {
                    Image(systemName: BLSymbol.members)
                        .font(.system(size: 19, weight: .medium))
                        .foregroundStyle(theme.textPrimary)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("\(request.displayName) wants to join")
                            .font(BLFont.ui(size: 16, weight: .semibold))
                            .foregroundStyle(theme.textPrimary)
                            .lineLimit(1)

                        Text("Used a one-time invite · tap to accept")
                            .blTextRole(.caption)
                            .foregroundStyle(theme.textSecondary)
                            .lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack(spacing: BLSpacing.space2) {
                    BLButton(
                        isApproving ? "Accepting…" : "Accept",
                        variant: .primary,
                        size: .sm
                    ) {
                        handleJoinRequest(request.id, approve: true)
                    }
                    .disabled(isBusy)

                    BLButton(
                        isDeclining ? "Declining…" : "Decline",
                        variant: .secondary,
                        size: .sm
                    ) {
                        handleJoinRequest(request.id, approve: false)
                    }
                    .disabled(isBusy)
                }
            }
            .padding(.vertical, BLSpacing.space3)
            .padding(.horizontal, 14)
        }
    }

    private func handleJoinRequest(_ requestId: UUID, approve: Bool) {
        guard pendingRequestAction == nil else { return }
        pendingRequestAction = PendingRequestAction(id: requestId, approving: approve)
        Task { @MainActor in
            defer { pendingRequestAction = nil }
            do {
                if approve {
                    try await store.approveJoinRequestAsync(requestId: requestId)
                } else {
                    try await store.declineJoinRequestAsync(requestId: requestId)
                }
            } catch {
                store.showInfoToast(error.localizedDescription)
            }
        }
    }

    private var timelineSectionHeader: some View {
        let count = store.todayEvents.count
        let entryNoun = count == 1 ? "entry" : "entries"
        return HStack(alignment: .firstTextBaseline) {
            Text("Today")
                .blMicroLabel()
            Spacer()
            Text(count == 0 ? "0 entries" : "\(count) \(entryNoun) · tap to edit")
                .blMicroLabel()
        }
        .padding(.top, BLSpacing.space5)
        .padding(.bottom, BLSpacing.space2)
    }

    private var timelineList: some View {
        let events = store.todayEvents
        return VStack(spacing: 0) {
            Rectangle()
                .fill(theme.borderHairline)
                .frame(height: BLSpacing.borderWidth)

            if events.isEmpty {
                Text("No entries logged yet today")
                    .blTextRole(.callout)
                    .foregroundStyle(theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, BLSpacing.space4)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(events) { event in
                        BLEventRow(
                            kind: event.blEventKind,
                            time: FormattingHelpers.formatClock(
                                store.displayTimestamp(for: event),
                                timeZone: store.profileTimeZone
                            ),
                            title: store.eventTitle(for: event),
                            detail: store.eventDetail(for: event),
                            sourceIcon: event.source.blSourceIcon,
                            showDivider: true
                        ) {
                            onEditEvent(event)
                        }
                    }
                }
            }
        }
    }

    private func splitTileSubtitle(for kind: BLEventKind) -> String? {
        switch kind {
        case .nursing:
            if let session = store.activeNursing {
                let elapsed = session.elapsedSeconds(asOf: store.now)
                return FormattingHelpers.formatMMSS(seconds: Int(elapsed.total))
            }
            return store.lastNursingSideInfo.map { "Last: \($0.side == .left ? "Left" : "Right")" }
        case .pump:
            if let session = store.activePump {
                return FormattingHelpers.formatMMSS(seconds: Int(session.elapsedSeconds(asOf: store.now)))
            }
            return nil
        default:
            return nil
        }
    }
}
