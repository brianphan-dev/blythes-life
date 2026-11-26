import BlythesLifeCore
import BlythesLifeDesignSystem
import BlythesLifeShared
import Foundation
import SwiftUI

#if os(iOS) && canImport(ActivityKit)
import ActivityKit

// MARK: - Lock Screen Live Activity Attributes

/// ActivityKit attributes driving Blythe's Lock Screen & Dynamic Island sleep/wake banner.
public struct BlytheSleepActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var isAsleep: Bool
        public var startedAt: Date
        public var targetAt: Date?
        public var label: String
        public var caption: String
        public var progress: Double
        public var isOver: Bool

        public init(
            isAsleep: Bool,
            startedAt: Date,
            targetAt: Date? = nil,
            label: String,
            caption: String,
            progress: Double,
            isOver: Bool = false
        ) {
            self.isAsleep = isAsleep
            self.startedAt = startedAt
            self.targetAt = targetAt
            self.label = label
            self.caption = caption
            self.progress = progress
            self.isOver = isOver
        }
    }

    public var childName: String
    public var profileId: UUID

    public init(childName: String, profileId: UUID) {
        self.childName = childName
        self.profileId = profileId
    }
}

/// Lock Screen Live Activity banner styled strictly with `BlythesLifeDesignSystem` tokens.
@MainActor
public struct BlytheSleepLiveActivityBannerView: View {
    @Environment(\.blTheme) private var theme

    public let attributes: BlytheSleepActivityAttributes
    public let state: BlytheSleepActivityAttributes.ContentState

    public init(
        attributes: BlytheSleepActivityAttributes,
        state: BlytheSleepActivityAttributes.ContentState
    ) {
        self.attributes = attributes
        self.state = state
    }

    private var clampedProgress: Double {
        min(1.0, max(0.0, state.progress))
    }

    private var fillColor: Color {
        if state.isOver { return theme.warn.solid }
        return state.isAsleep ? theme.sleep.solid : theme.accent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: BLSpacing.space2) {
            HStack(spacing: BLSpacing.space2) {
                BLEventIcon(kind: .sleep, size: .sm)

                Text("\(attributes.childName) · \(state.label)")
                    .blMicroLabel(color: theme.textSecondary)
                    .lineLimit(1)

                Spacer()

                Image(systemName: state.isAsleep ? BLSymbol.moon : BLSymbol.sun)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(state.isAsleep ? theme.sleep.ink : theme.accentText)
            }

            HStack(alignment: .firstTextBaseline) {
                Text(state.startedAt, style: .timer)
                    .font(BLFont.display(size: 32, weight: .medium, tabularNumerals: true))
                    .foregroundStyle(theme.textPrimary)
                    .monospacedDigit()

                Spacer()

                if let targetAt = state.targetAt {
                    Text(FormattingHelpers.formatClock(targetAt))
                        .font(BLFont.ui(size: 14, weight: .semibold, tabularNumerals: true))
                        .foregroundStyle(theme.textPrimary)
                }
            }

            GeometryReader { geo in
                let width = max(0, geo.size.width - 1)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(state.isAsleep ? theme.sleep.solid.opacity(0.25) : theme.bgRaised)
                        .frame(width: width, height: 5)

                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(fillColor)
                        .frame(width: width * clampedProgress, height: 5)

                    Rectangle()
                        .fill(theme.textPrimary)
                        .frame(width: 2, height: 11)
                        .position(x: max(1, geo.size.width - 1), y: 5.5)
                }
            }
            .frame(height: 11)

            Text(state.caption)
                .blTextRole(.caption)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(1)
        }
        .padding(BLSpacing.space4)
        .background(state.isAsleep ? theme.sleep.tint : theme.bgSurface)
    }
}

/// Safe ActivityKit bridge synchronizing a running nap with Lock Screen Live Activities.
@MainActor
public enum BlytheLiveActivityCoordinator {
    public static func sync(with store: BlythesLifeStore) async {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let napState = store.napCardState
        let existing = Activity<BlytheSleepActivityAttributes>.activities.first

        guard let napStart = store.activeNapStart else {
            if let existing {
                let endedState = BlytheSleepActivityAttributes.ContentState(
                    isAsleep: false,
                    startedAt: store.now,
                    targetAt: napState.prediction?.recommendedStart,
                    label: napState.label,
                    caption: napState.fullCaption,
                    progress: napState.progress,
                    isOver: napState.isOver
                )
                await existing.end(
                    ActivityContent(state: endedState, staleDate: nil),
                    dismissalPolicy: .immediate
                )
            }
            return
        }

        let capSeconds = TimeInterval(store.profile.scheduleConfig.napCapMinutes * 60)
        let contentState = BlytheSleepActivityAttributes.ContentState(
            isAsleep: true,
            startedAt: napStart,
            targetAt: napStart.addingTimeInterval(capSeconds),
            label: napState.label,
            caption: napState.fullCaption,
            progress: napState.progress,
            isOver: napState.isOver
        )
        let content = ActivityContent(state: contentState, staleDate: nil)

        if let existing {
            await existing.update(content)
        } else {
            let attributes = BlytheSleepActivityAttributes(
                childName: store.profile.displayName,
                profileId: store.profile.id
            )
            _ = try? Activity.request(attributes: attributes, content: content, pushType: nil)
        }
    }
}
#endif

// MARK: - App Intents (Control Center, Siri, Shortcuts)

#if canImport(AppIntents)
import AppIntents

/// Starts or ends Blythe's live nap timer from Control Center, Action Button, Siri, or Shortcuts.
public struct ToggleNapAppIntent: AppIntent {
    public static let title: LocalizedStringResource = "Toggle Blythe's nap"
    public static let description = IntentDescription(
        "Starts a nap timer or wakes Blythe up from an active nap."
    )
    public static let openAppWhenRun: Bool = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let store = BlythesLifeStore(initialNow: Date())
        let endedEvent = store.toggleNap()

        #if os(iOS) && canImport(ActivityKit)
        await BlytheLiveActivityCoordinator.sync(with: store)
        #endif

        if let endedEvent {
            let title = store.eventTitle(for: endedEvent)
            return .result(dialog: IntentDialog("\(title) saved."))
        }
        return .result(dialog: IntentDialog("Nap timer started on every device."))
    }
}

/// AppEnum mapping diaper sizes cleanly into Siri / Shortcuts / Control Center parameters.
public enum DiaperAmountOption: String, AppEnum, Sendable {
    case none
    case small
    case medium
    case large

    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Diaper size")

    public static let caseDisplayRepresentations: [DiaperAmountOption: DisplayRepresentation] = [
        .none: DisplayRepresentation(title: "None"),
        .small: DisplayRepresentation(title: "Small"),
        .medium: DisplayRepresentation(title: "Medium"),
        .large: DisplayRepresentation(title: "Large")
    ]

    public var diaperSize: DiaperSize? {
        switch self {
        case .none: nil
        case .small: .small
        case .medium: .medium
        case .large: .large
        }
    }
}

/// One-tap diaper logging intent for Control Center, Siri, and Shortcuts.
public struct QuickLogDiaperAppIntent: AppIntent {
    public static let title: LocalizedStringResource = "Log diaper"
    public static let description = IntentDescription(
        "Logs a diaper change for Blythe."
    )
    public static let openAppWhenRun: Bool = false

    @Parameter(title: "Pee", default: .medium)
    public var pee: DiaperAmountOption

    @Parameter(title: "Poop", default: DiaperAmountOption.none)
    public var poop: DiaperAmountOption

    @Parameter(title: "Rash", default: false)
    public var rash: Bool

    public init() {}

    public init(
        pee: DiaperAmountOption = .medium,
        poop: DiaperAmountOption = .none,
        rash: Bool = false
    ) {
        self.pee = pee
        self.poop = poop
        self.rash = rash
    }

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let now = Date()
        let store = BlythesLifeStore(initialNow: now)
        let event = store.logDiaper(
            startedAt: now,
            pee: pee.diaperSize,
            poop: poop.diaperSize,
            rash: rash
        )
        let detail = store.eventDetail(for: event)
        return .result(dialog: IntentDialog("Diaper logged · \(detail)."))
    }
}

/// Registered App Shortcuts surfacing Toggle Nap and Log Diaper in Siri and Spotlight.
public struct BlythesLifeAppShortcuts: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ToggleNapAppIntent(),
            phrases: [
                "Toggle nap in \(.applicationName)",
                "Start a nap in \(.applicationName)"
            ],
            shortTitle: "Toggle nap",
            systemImageName: "moon"
        )
        AppShortcut(
            intent: QuickLogDiaperAppIntent(),
            phrases: [
                "Log a diaper in \(.applicationName)",
                "Log diaper in \(.applicationName)"
            ],
            shortTitle: "Log diaper",
            systemImageName: "humidity"
        )
    }
}
#endif
