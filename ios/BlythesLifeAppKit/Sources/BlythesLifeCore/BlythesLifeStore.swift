import BlythesLifeShared
import Foundation
import Observation
#if os(iOS) && canImport(UIKit)
import UIKit
#endif

// MARK: - View Models & Supporting State

/// High-level onboarding and authentication lifecycle stage for the root app shell.
public enum AppSessionStage: String, Codable, Sendable, Equatable {
    case signedOut
    case needsHouseholdSetup
    case ready
}

public enum SyncStatus: Sendable, Equatable {
    case localOnly
    case synced(Date)
    case syncing
    case offline(pendingCount: Int)
    case error(String)
}

public struct ToastState: Identifiable, Sendable, Equatable {
    public var id: UUID
    public var message: String
    public var canUndo: Bool

    public init(id: UUID = UUID(), message: String, canUndo: Bool) {
        self.id = id
        self.message = message
        self.canUndo = canUndo
    }
}

public enum NapCardMode: String, Sendable, Equatable {
    case awake
    case asleep
}

public struct NapCardViewModel: Sendable, Equatable {
    public var mode: NapCardMode
    public var label: String
    public var elapsedText: String
    public var progress: Double
    public var isOver: Bool
    public var captionPrefix: String
    public var highlightedClockTime: String?
    public var captionSuffix: String?
    public var primaryActionLabel: String
    public var secondaryActionLabel: String
    public var prediction: NextNapPrediction?

    public init(
        mode: NapCardMode,
        label: String,
        elapsedText: String,
        progress: Double,
        isOver: Bool,
        captionPrefix: String,
        highlightedClockTime: String?,
        captionSuffix: String?,
        primaryActionLabel: String,
        secondaryActionLabel: String,
        prediction: NextNapPrediction? = nil
    ) {
        self.mode = mode
        self.label = label
        self.elapsedText = elapsedText
        self.progress = progress
        self.isOver = isOver
        self.captionPrefix = captionPrefix
        self.highlightedClockTime = highlightedClockTime
        self.captionSuffix = captionSuffix
        self.primaryActionLabel = primaryActionLabel
        self.secondaryActionLabel = secondaryActionLabel
        self.prediction = prediction
    }

    public var isAsleep: Bool {
        mode == .asleep
    }

    public var fullCaption: String {
        captionPrefix + (highlightedClockTime ?? "") + (captionSuffix ?? "")
    }
}

public struct GlanceSummary: Sendable, Equatable {
    public var title: String
    public var elapsedText: String
    public var subtitle: String
    public var isNursing: Bool
    public var event: EventDTO?

    public init(
        title: String,
        elapsedText: String,
        subtitle: String,
        isNursing: Bool = false,
        event: EventDTO? = nil
    ) {
        self.title = title
        self.elapsedText = elapsedText
        self.subtitle = subtitle
        self.isNursing = isNursing
        self.event = event
    }
}

public struct RhythmSleepSpan: Identifiable, Sendable, Equatable {
    public var id: String
    public var startMinute: Double
    public var endMinute: Double
    public var isLive: Bool
    public var isNap: Bool

    public init(id: String, startMinute: Double, endMinute: Double, isLive: Bool = false, isNap: Bool = true) {
        self.id = id
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.isLive = isLive
        self.isNap = isNap
    }

    public var durationMinutes: Double {
        max(0, endMinute - startMinute)
    }
}

public struct RhythmBottleMark: Identifiable, Sendable, Equatable {
    public var id: String
    public var minute: Double
    public var amountOz: Double
    public var amountMl: Double
    public var substance: FeedingSubstance

    public init(
        id: String,
        minute: Double,
        amountOz: Double,
        amountMl: Double,
        substance: FeedingSubstance
    ) {
        self.id = id
        self.minute = minute
        self.amountOz = amountOz
        self.amountMl = amountMl
        self.substance = substance
    }

    public var isBreastMilk: Bool {
        substance == .breastMilk
    }
}

public struct RhythmNursingSpan: Identifiable, Sendable, Equatable {
    public var id: String
    public var startMinute: Double
    public var durationMinutes: Double

    public init(id: String, startMinute: Double, durationMinutes: Double) {
        self.id = id
        self.startMinute = startMinute
        self.durationMinutes = durationMinutes
    }
}

public struct RhythmDaySummary: Identifiable, Sendable, Equatable {
    public var id: String
    public var date: Date
    public var weekdayShort: String
    public var weekdayInitial: String
    public var dayNumber: Int
    public var headerLabel: String
    public var isToday: Bool
    public var sleepSpans: [RhythmSleepSpan]
    public var bottleMarks: [RhythmBottleMark]
    public var nursingSpans: [RhythmNursingSpan]
    public var mealMinutes: [Double]
    public var diaperMinutes: [Double]

    public init(
        id: String,
        date: Date,
        weekdayShort: String,
        weekdayInitial: String,
        dayNumber: Int,
        headerLabel: String,
        isToday: Bool,
        sleepSpans: [RhythmSleepSpan],
        bottleMarks: [RhythmBottleMark],
        nursingSpans: [RhythmNursingSpan],
        mealMinutes: [Double],
        diaperMinutes: [Double]
    ) {
        self.id = id
        self.date = date
        self.weekdayShort = weekdayShort
        self.weekdayInitial = weekdayInitial
        self.dayNumber = dayNumber
        self.headerLabel = headerLabel
        self.isToday = isToday
        self.sleepSpans = sleepSpans
        self.bottleMarks = bottleMarks
        self.nursingSpans = nursingSpans
        self.mealMinutes = mealMinutes
        self.diaperMinutes = diaperMinutes
    }

    public var totalSleepMinutes: Double {
        sleepSpans.reduce(0) { $0 + $1.durationMinutes }
    }

    public var totalBottleOz: Double {
        let sum = bottleMarks.reduce(0) { $0 + $1.amountOz }
        return (sum * 100.0).rounded() / 100.0
    }

    public var totalBottleMl: Double {
        let sum = bottleMarks.reduce(0) { $0 + $1.amountMl }
        return (sum * 10.0).rounded() / 10.0
    }

    public var bottleCount: Int { bottleMarks.count }
    public var nursingCount: Int { nursingSpans.count }
    public var mealCount: Int { mealMinutes.count }
    public var diaperCount: Int { diaperMinutes.count }
}

// MARK: - BlythesLifeStore

@MainActor
@Observable
public final class BlythesLifeStore {
    public static let defaultBedtimeWakeWindowMinutes: Double = 240.0

    public var profile: ProfileDTO
    public var household: HouseholdDTO
    public var currentUserId: UUID
    public var events: [EventDTO]
    public var activeNapStart: Date?
    public var activeNursing: ActiveNursingSession?
    public var scannedSheets: [ScannedSheetRecord]
    public var preferredUnit: VolumeUnit
    public var colorModePreference: AppColorModePreference
    public var postureOverride: PosturePreviewOverride
    public var now: Date
    public var toast: ToastState?
    public var syncStatus: SyncStatus
    public var sessionStage: AppSessionStage
    public var isDemoPreview: Bool
    public var hasCompletedHouseholdSetup: Bool
    public var isSignedInWithApple: Bool
    public var authEmail: String?
    public var displayName: String?
    public var isProcessingScan: Bool
    public var isAuthenticating: Bool
    public var lastSyncError: String?
    public var apiBaseURLString: String
    public private(set) var outbox: [SyncOutboxItem]
    public private(set) var serverWatermark: Date?

    public var outboxCount: Int { outbox.count }

    /// True when the user is signed into the live backend and not previewing sample data.
    public var isLiveSession: Bool {
        isSignedInWithApple && !isDemoPreview && apiClient != nil
    }

    /// True when a live backend client is configured and the store holds active auth credentials.
    public var hasLiveSession: Bool {
        apiClient != nil && isSignedInWithApple && !isDemoPreview && (accessToken != nil || refreshToken != nil)
    }

    @ObservationIgnored private let storage: any LocalStateStorage
    @ObservationIgnored private let apiClient: (any BackendAPIProviding)?
    @ObservationIgnored private let tokenStore: any AuthTokenStorage
    @ObservationIgnored private var accessToken: String?
    @ObservationIgnored private var refreshToken: String?
    @ObservationIgnored private var inFlightRefreshTask: Task<String, Error>?
    @ObservationIgnored private var undoAction: (@MainActor () -> Void)?
    @ObservationIgnored private var clockTask: Task<Void, Never>?
    @ObservationIgnored private var toastDismissTask: Task<Void, Never>?
    @ObservationIgnored private var sseTask: Task<Void, Never>?
    @ObservationIgnored private var lastPersistError: String?

    public init(
        storage: any LocalStateStorage = FileLocalStateStorage(),
        apiClient: (any BackendAPIProviding)? = URLSessionBackendAPIClient(),
        tokenStore: any AuthTokenStorage = KeychainAuthTokenStorage(),
        accessToken: String? = nil,
        refreshToken: String? = nil,
        seedReferenceDate: Date = SampleSeedData.defaultReferenceDate,
        initialNow: Date? = nil,
        autoStartClock: Bool = false
    ) {
        self.storage = storage
        self.apiClient = apiClient
        self.tokenStore = tokenStore
        self.isProcessingScan = false
        self.isAuthenticating = false
        self.lastSyncError = nil
        self.apiBaseURLString = apiClient?.baseURL.absoluteString
            ?? URLSessionBackendAPIClient.defaultBaseURL.absoluteString
        self.postureOverride = .automatic
        self.toast = nil

        let loadedState: PersistedAppState
        if apiClient != nil {
            if let storedTokens = tokenStore.load() {
                let launchNow = initialNow ?? Date()
                loadedState = (try? storage.load()) ?? SampleSeedData.makeBlankState(referenceDate: launchNow)
                self.accessToken = accessToken ?? storedTokens.accessToken
                self.refreshToken = refreshToken ?? storedTokens.refreshToken
                self.isSignedInWithApple = true
                self.isDemoPreview = false
                self.hasCompletedHouseholdSetup = loadedState.hasCompletedHouseholdSetup
                self.sessionStage = loadedState.hasCompletedHouseholdSetup ? .ready : .needsHouseholdSetup
                self.now = launchNow
                self.syncStatus = loadedState.hasCompletedHouseholdSetup ? .syncing : .localOnly
            } else if let accessToken {
                let launchNow = initialNow ?? seedReferenceDate
                loadedState = (try? storage.load()) ?? SampleSeedData.makeBlankState(referenceDate: launchNow)
                self.accessToken = accessToken
                self.refreshToken = refreshToken
                self.isSignedInWithApple = true
                self.isDemoPreview = false
                self.hasCompletedHouseholdSetup = loadedState.hasCompletedHouseholdSetup
                self.sessionStage = loadedState.hasCompletedHouseholdSetup ? .ready : .needsHouseholdSetup
                self.now = launchNow
                if let watermark = loadedState.serverWatermark {
                    self.syncStatus = .synced(watermark)
                } else if !loadedState.outbox.isEmpty {
                    self.syncStatus = .offline(pendingCount: loadedState.outbox.count)
                } else {
                    self.syncStatus = .localOnly
                }
            } else {
                // Default production fresh install or signed-out launch: never auto-seed demo data.
                let launchNow = initialNow ?? Date()
                var blank = SampleSeedData.makeBlankState(referenceDate: launchNow)
                if let existing = try? storage.load() {
                    blank.preferredUnit = existing.preferredUnit
                    blank.colorMode = existing.colorMode
                }
                loadedState = blank
                self.accessToken = nil
                self.refreshToken = refreshToken
                self.isSignedInWithApple = false
                self.isDemoPreview = false
                self.hasCompletedHouseholdSetup = false
                self.sessionStage = .signedOut
                self.now = launchNow
                self.syncStatus = .localOnly
            }
        } else {
            if let existing = try? storage.load() {
                loadedState = existing
            } else {
                let demo = SampleSeedData.makeDemoState(referenceDate: seedReferenceDate)
                loadedState = demo
                try? storage.save(demo)
            }
            self.accessToken = nil
            self.refreshToken = nil
            self.isSignedInWithApple = loadedState.isSignedInWithApple
            self.isDemoPreview = true
            self.hasCompletedHouseholdSetup = true
            self.sessionStage = .ready
            self.now = initialNow ?? seedReferenceDate
            self.syncStatus = .localOnly
        }

        self.profile = loadedState.profile
        self.household = loadedState.household
        self.currentUserId = loadedState.currentUserId
        self.events = loadedState.events
        self.activeNapStart = loadedState.activeNapStart
        self.activeNursing = loadedState.activeNursingSession
        self.scannedSheets = loadedState.pendingScans
        self.outbox = loadedState.outbox
        self.serverWatermark = loadedState.serverWatermark
        self.preferredUnit = loadedState.preferredUnit
        self.colorModePreference = loadedState.colorMode
        self.authEmail = loadedState.authEmail
        self.displayName = loadedState.displayName

        if autoStartClock {
            startClock()
        }
    }

    /// Creates an in-memory store seeded with realistic demo state for SwiftUI Previews and tests.
    public static func makeDemo(
        referenceDate: Date = SampleSeedData.defaultReferenceDate,
        apiClient: (any BackendAPIProviding)? = nil,
        tokenStore: any AuthTokenStorage = InMemoryAuthTokenStorage(),
        accessToken: String? = nil,
        refreshToken: String? = nil
    ) -> BlythesLifeStore {
        let seed = SampleSeedData.makeDemoState(referenceDate: referenceDate)
        let memory = InMemoryLocalStateStorage(initialState: seed)
        return BlythesLifeStore(
            storage: memory,
            apiClient: apiClient,
            tokenStore: tokenStore,
            accessToken: accessToken,
            refreshToken: refreshToken,
            seedReferenceDate: referenceDate,
            initialNow: referenceDate,
            autoStartClock: false
        )
    }

    // MARK: - Clock Lifecycle

    public func tick(now: Date) {
        self.now = now
    }

    public func startClock(intervalSeconds: TimeInterval = 1.0) {
        stopClock()
        let nanos = UInt64(max(0.1, intervalSeconds) * 1_000_000_000)
        clockTask = Task { [weak self] in
            var lastWall = Date()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: nanos)
                if Task.isCancelled { break }
                let wall = Date()
                let delta = max(0, wall.timeIntervalSince(lastWall))
                lastWall = wall
                guard let self else { break }
                self.now = self.now.addingTimeInterval(delta)
            }
        }
    }

    public func stopClock() {
        clockTask?.cancel()
        clockTask = nil
    }

    // MARK: - Calendar & Formatting Helpers

    public var profileTimeZone: TimeZone {
        TimeZone(identifier: profile.defaultTimezone) ?? .current
    }

    public var profileCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = profileTimeZone
        return calendar
    }

    public var headerDateTitle: String {
        FormattingHelpers.formatHeaderDate(now, timeZone: profileTimeZone)
    }

    public var profileAgeLabel: String {
        FormattingHelpers.formatAge(birthDate: profile.birthDate, asOf: now, timeZone: profileTimeZone)
    }

    public var formattedInviteCode: String {
        FormattingHelpers.formatInviteCode(household.inviteCode)
    }

    public var activeEvents: [EventDTO] {
        events.filter { $0.deletedAt == nil }
    }

    /// Chronological display timestamp for Today timeline sorting & clock label.
    /// Overnight night sleep that started yesterday uses its morning wake `endedAt`.
    public func displayTimestamp(for event: EventDTO) -> Date {
        if case .sleep(let meta) = event.metadata,
           meta.sleepType == .night,
           let endedAt = event.endedAt,
           !profileCalendar.isDate(event.startedAt, inSameDayAs: endedAt)
        {
            return endedAt
        }
        return event.startedAt
    }

    /// 1-indexed daytime nap number for a nap event on its local calendar day.
    public func napNumber(for event: EventDTO) -> Int? {
        guard case .sleep(let meta) = event.metadata, meta.sleepType == .nap else {
            return nil
        }
        let calendar = profileCalendar
        let sameDayNaps = activeEvents
            .filter { candidate in
                guard case .sleep(let cMeta) = candidate.metadata, cMeta.sleepType == .nap else {
                    return false
                }
                guard candidate.endedAt != nil || candidate.id == event.id else {
                    return false
                }
                return calendar.isDate(candidate.startedAt, inSameDayAs: event.startedAt)
            }
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt { return lhs.startedAt < rhs.startedAt }
                return lhs.createdAt < rhs.createdAt
            }
        guard let index = sameDayNaps.firstIndex(where: { $0.id == event.id }) else {
            return nil
        }
        return index + 1
    }

    public func eventTitle(for event: EventDTO) -> String {
        FormattingHelpers.eventTitle(event, napNumber: napNumber(for: event))
    }

    public func eventDetail(for event: EventDTO) -> String {
        FormattingHelpers.eventDetail(event, preferredUnit: preferredUnit, timeZone: profileTimeZone)
    }

    // MARK: - Today Computed Views

    /// Non-deleted completed events belonging to today's local calendar day, sorted newest first.
    /// Open-ended active sleep timers (`endedAt == nil`) are represented by the hero `NapCard` until completed.
    public var todayEvents: [EventDTO] {
        let calendar = profileCalendar
        return activeEvents
            .filter { event in
                if event.eventType == .sleep && event.endedAt == nil {
                    return false
                }
                if case .sleep(let meta) = event.metadata, meta.sleepType == .night, let endedAt = event.endedAt {
                    return calendar.isDate(endedAt, inSameDayAs: now) || calendar.isDate(event.startedAt, inSameDayAs: now)
                }
                return calendar.isDate(event.startedAt, inSameDayAs: now)
            }
            .sorted { lhs, rhs in
                let lt = displayTimestamp(for: lhs)
                let rt = displayTimestamp(for: rhs)
                if lt != rt { return lt > rt }
                return lhs.createdAt > rhs.createdAt
            }
    }

    public var completedNapsToday: [EventDTO] {
        let calendar = profileCalendar
        return activeEvents
            .filter { event in
                guard event.eventType == .sleep,
                      case .sleep(let meta) = event.metadata,
                      meta.sleepType == .nap,
                      let endedAt = event.endedAt,
                      endedAt >= event.startedAt
                else {
                    return false
                }
                return calendar.isDate(event.startedAt, inSameDayAs: now)
            }
            .sorted { $0.startedAt < $1.startedAt }
    }

    public var napCardState: NapCardViewModel {
        let tz = profileTimeZone
        let calendar = profileCalendar
        let completedNaps = completedNapsToday
        let napsDone = completedNaps.count

        // 1. Active live sleep timer
        if let napStart = activeNapStart {
            let elapsedMinutes = max(0, now.timeIntervalSince(napStart) / 60.0)
            let capMinutes = Double(max(1, profile.scheduleConfig.napCapMinutes))
            let remaining = capMinutes - elapsedMinutes
            let capClock = FormattingHelpers.formatClock(
                napStart.addingTimeInterval(capMinutes * 60.0),
                timeZone: tz
            )
            let suffix = remaining < 0
                ? " · \(FormattingHelpers.formatDuration(minutes: -remaining)) over"
                : " · \(FormattingHelpers.formatDuration(minutes: remaining)) left"
            let sleepLabelPrefix = napsDone < profile.scheduleConfig.wakeWindowsMinutes.count
                ? "Nap \(napsDone + 1)"
                : "Sleep"

            return NapCardViewModel(
                mode: .asleep,
                label: "\(sleepLabelPrefix) · since \(FormattingHelpers.formatClock(napStart, timeZone: tz))",
                elapsedText: FormattingHelpers.formatDuration(minutes: elapsedMinutes),
                progress: elapsedMinutes / capMinutes,
                isOver: remaining < 0,
                captionPrefix: "Nap cap ",
                highlightedClockTime: capClock,
                captionSuffix: suffix,
                primaryActionLabel: "Wake up",
                secondaryActionLabel: "Change start time",
                prediction: nil
            )
        }

        // Determine morning wake time and latest completed sleep end today.
        let todaySleepEnds = todayEvents.compactMap { event -> Date? in
            guard event.eventType == .sleep else { return nil }
            return event.endedAt
        }
        guard let lastWake = todaySleepEnds.max() else {
            return NapCardViewModel(
                mode: .awake,
                label: "Awake",
                elapsedText: "—",
                progress: 0,
                isOver: false,
                captionPrefix: "No sleep logged yet today",
                highlightedClockTime: nil,
                captionSuffix: nil,
                primaryActionLabel: "Start nap",
                secondaryActionLabel: "Add a past sleep",
                prediction: nil
            )
        }

        let morningWake = todayEvents
            .filter { event in
                if case .sleep(let meta) = event.metadata {
                    return meta.sleepType == .night
                }
                return false
            }
            .compactMap(\.endedAt)
            .max() ?? lastWake

        let prediction = WakeWindowCalculator.predictNextNap(
            asOf: now,
            wakeUpTime: morningWake,
            completedNapsToday: completedNaps,
            config: profile.scheduleConfig,
            calendar: calendar
        )

        let elapsedMinutes = max(0, now.timeIntervalSince(lastWake) / 60.0)
        let awakeLabel = "Awake · since \(FormattingHelpers.formatClock(lastWake, timeZone: tz))"

        if let prediction {
            let targetMinutes = Double(max(1, prediction.wakeWindowMinutes))
            let remaining = prediction.recommendedStart.timeIntervalSince(now) / 60.0
            let name = prediction.isBackupCatnap ? "Backup catnap" : "Nap \(napsDone + 1)"
            let targetClock = FormattingHelpers.formatClock(prediction.recommendedStart, timeZone: tz)
            let suffix = remaining < 0
                ? " · \(FormattingHelpers.formatDuration(minutes: -remaining)) ago"
                : " · in \(FormattingHelpers.formatDuration(minutes: remaining))"

            return NapCardViewModel(
                mode: .awake,
                label: awakeLabel,
                elapsedText: FormattingHelpers.formatDuration(minutes: elapsedMinutes),
                progress: elapsedMinutes / targetMinutes,
                isOver: remaining < 0,
                captionPrefix: "\(name) sweet spot ",
                highlightedClockTime: targetClock,
                captionSuffix: suffix,
                primaryActionLabel: "Start nap",
                secondaryActionLabel: "Add a past sleep",
                prediction: prediction
            )
        }

        // All daytime naps complete (or past backup catnap cutoff) -> Bedtime sweet spot
        let bedtimeMinutes = Self.defaultBedtimeWakeWindowMinutes
        let bedtimeTarget = lastWake.addingTimeInterval(bedtimeMinutes * 60.0)
        let remaining = bedtimeTarget.timeIntervalSince(now) / 60.0
        let bedtimeClock = FormattingHelpers.formatClock(bedtimeTarget, timeZone: tz)
        let suffix = remaining < 0
            ? " · \(FormattingHelpers.formatDuration(minutes: -remaining)) ago"
            : " · in \(FormattingHelpers.formatDuration(minutes: remaining))"

        return NapCardViewModel(
            mode: .awake,
            label: awakeLabel,
            elapsedText: FormattingHelpers.formatDuration(minutes: elapsedMinutes),
            progress: elapsedMinutes / bedtimeMinutes,
            isOver: remaining < 0,
            captionPrefix: "Bedtime sweet spot ",
            highlightedClockTime: bedtimeClock,
            captionSuffix: suffix,
            primaryActionLabel: "Start night sleep",
            secondaryActionLabel: "Add a past sleep",
            prediction: nil
        )
    }

    public var lastFeedGlance: GlanceSummary {
        guard let feed = todayEvents.first(where: { $0.eventType == .feeding }) else {
            return GlanceSummary(title: "Last feed", elapsedText: "—", subtitle: "None today", isNursing: false, event: nil)
        }
        let isNursing: Bool
        if case .feeding(let meta) = feed.metadata {
            isNursing = meta.method == .breast
        } else {
            isNursing = false
        }
        let elapsedMinutes = max(0, now.timeIntervalSince(feed.startedAt) / 60.0)
        let detail = eventDetail(for: feed)
        return GlanceSummary(
            title: "Last feed",
            elapsedText: FormattingHelpers.formatDuration(minutes: elapsedMinutes),
            subtitle: isNursing ? "Nursed \(detail)" : detail,
            isNursing: isNursing,
            event: feed
        )
    }

    public var lastDiaperGlance: GlanceSummary {
        guard let diaper = todayEvents.first(where: { $0.eventType == .diaper }) else {
            return GlanceSummary(title: "Last diaper", elapsedText: "—", subtitle: "None today", isNursing: false, event: nil)
        }
        let elapsedMinutes = max(0, now.timeIntervalSince(diaper.startedAt) / 60.0)
        return GlanceSummary(
            title: "Last diaper",
            elapsedText: FormattingHelpers.formatDuration(minutes: elapsedMinutes),
            subtitle: eventDetail(for: diaper),
            isNursing: false,
            event: diaper
        )
    }

    public var pendingReviewSheet: ScannedSheetRecord? {
        scannedSheets.first(where: { $0.status == .pendingReview })
    }

    public var pendingReviewCount: Int {
        scannedSheets.filter { $0.status == .pendingReview }.count
    }

    // MARK: - 7-Day Rhythm Aggregation

    public var rhythmWeekDays: [RhythmDaySummary] {
        let calendar = profileCalendar
        let tz = profileTimeZone
        let todayStart = calendar.startOfDay(for: now)
        let nonDeleted = activeEvents
        let openSleepIsNap: Bool = {
            if let open = latestOpenSleepEvent(), case .sleep(let meta) = open.metadata {
                return meta.sleepType == .nap
            }
            return true
        }()

        let weekdayFormatter = DateFormatter()
        weekdayFormatter.locale = Locale(identifier: "en_US_POSIX")
        weekdayFormatter.calendar = calendar
        weekdayFormatter.timeZone = tz
        weekdayFormatter.dateFormat = "EEE"

        let headerFormatter = DateFormatter()
        headerFormatter.locale = Locale(identifier: "en_US_POSIX")
        headerFormatter.calendar = calendar
        headerFormatter.timeZone = tz
        headerFormatter.dateFormat = "EEE, MMM d"

        let isoFormatter = DateFormatter()
        isoFormatter.locale = Locale(identifier: "en_US_POSIX")
        isoFormatter.calendar = calendar
        isoFormatter.timeZone = tz
        isoFormatter.dateFormat = "yyyy-MM-dd"

        var summaries: [RhythmDaySummary] = []

        for offset in -6 ... 0 {
            guard let dayStart = calendar.date(byAdding: .day, value: offset, to: todayStart),
                  let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
            else {
                continue
            }
            let isToday = (offset == 0)

            var sleepSpans: [RhythmSleepSpan] = []
            var bottleMarks: [RhythmBottleMark] = []
            var nursingSpans: [RhythmNursingSpan] = []
            var mealMinutes: [Double] = []
            var diaperMinutes: [Double] = []

            for event in nonDeleted {
                switch event.metadata {
                case .sleep(let meta):
                    // Open-ended active sleep events are rendered once via `activeNapStart` below so they are never double-counted.
                    guard let effectiveEnd = event.endedAt else { continue }
                    guard effectiveEnd > dayStart && event.startedAt < dayEnd else { continue }
                    let clippedStart = max(event.startedAt, dayStart)
                    let clippedEnd = min(effectiveEnd, dayEnd)
                    let startMin = clippedStart.timeIntervalSince(dayStart) / 60.0
                    let endMin = clippedEnd.timeIntervalSince(dayStart) / 60.0
                    if endMin > startMin {
                        sleepSpans.append(
                            RhythmSleepSpan(
                                id: "\(event.id.uuidString)-\(offset)",
                                startMinute: startMin,
                                endMinute: endMin,
                                isLive: false,
                                isNap: meta.sleepType == .nap
                            )
                        )
                    }

                case .feeding(let meta):
                    guard event.startedAt >= dayStart && event.startedAt < dayEnd else { continue }
                    let minute = event.startedAt.timeIntervalSince(dayStart) / 60.0
                    if meta.method == .breast {
                        let duration = meta.durationMinutes
                            ?? event.endedAt.map { max(1, $0.timeIntervalSince(event.startedAt) / 60.0) }
                            ?? max(1, Double((meta.leftDurationSeconds ?? 0) + (meta.rightDurationSeconds ?? 0)) / 60.0)
                        nursingSpans.append(
                            RhythmNursingSpan(
                                id: event.id.uuidString,
                                startMinute: minute,
                                durationMinutes: duration
                            )
                        )
                    } else {
                        let ml = meta.amountMl ?? 0
                        let oz = UnitConversion.mlToOz(ml)
                        bottleMarks.append(
                            RhythmBottleMark(
                                id: event.id.uuidString,
                                minute: minute,
                                amountOz: oz,
                                amountMl: ml,
                                substance: meta.substance
                            )
                        )
                    }

                case .meal:
                    guard event.startedAt >= dayStart && event.startedAt < dayEnd else { continue }
                    mealMinutes.append(event.startedAt.timeIntervalSince(dayStart) / 60.0)

                case .diaper:
                    guard event.startedAt >= dayStart && event.startedAt < dayEnd else { continue }
                    diaperMinutes.append(event.startedAt.timeIntervalSince(dayStart) / 60.0)

                case .pump, .bath, .medicine, .note:
                    break
                }
            }

            // Include live active nap span on today's column
            if isToday, let napStart = activeNapStart, now >= napStart {
                let clippedStart = max(napStart, dayStart)
                let clippedEnd = min(now, dayEnd)
                let startMin = clippedStart.timeIntervalSince(dayStart) / 60.0
                let endMin = clippedEnd.timeIntervalSince(dayStart) / 60.0
                if endMin >= startMin {
                    sleepSpans.append(
                        RhythmSleepSpan(
                            id: "live-nap",
                            startMinute: startMin,
                            endMinute: endMin,
                            isLive: true,
                            isNap: openSleepIsNap
                        )
                    )
                }
            }

            sleepSpans.sort { $0.startMinute < $1.startMinute }
            bottleMarks.sort { $0.minute < $1.minute }
            nursingSpans.sort { $0.startMinute < $1.startMinute }
            mealMinutes.sort()
            diaperMinutes.sort()

            let weekdayShort = weekdayFormatter.string(from: dayStart)
            let initial = weekdayShort.first.map(String.init) ?? ""
            let dayNum = calendar.component(.day, from: dayStart)

            summaries.append(
                RhythmDaySummary(
                    id: isoFormatter.string(from: dayStart),
                    date: dayStart,
                    weekdayShort: weekdayShort,
                    weekdayInitial: initial,
                    dayNumber: dayNum,
                    headerLabel: headerFormatter.string(from: dayStart),
                    isToday: isToday,
                    sleepSpans: sleepSpans,
                    bottleMarks: bottleMarks,
                    nursingSpans: nursingSpans,
                    mealMinutes: mealMinutes,
                    diaperMinutes: diaperMinutes
                )
            )
        }

        return summaries
    }

    public var rhythmWeekRangeTitle: String {
        let days = rhythmWeekDays
        guard let first = days.first, let last = days.last else { return "" }
        return FormattingHelpers.formatWeekRange(start: first.date, end: last.date, timeZone: profileTimeZone)
    }

    // MARK: - Sleep & Nap Actions (Multi-Device Live Sync)

    @discardableResult
    public func toggleNap() -> EventDTO? {
        guard let napStart = activeNapStart else {
            let isNight = shouldClassifySleepAsNight(asOf: now)
            let openSleep = makeEvent(
                type: .sleep,
                startedAt: now,
                endedAt: nil,
                metadata: .sleep(SleepMetadata(sleepType: isNight ? .night : .nap))
            )
            activeNapStart = now
            appendEvents([openSleep])

            showToast("Nap timer started on every device") { [weak self] in
                guard let self else { return }
                self.activeNapStart = nil
                if self.hasLiveSession {
                    if let idx = self.events.firstIndex(where: { $0.id == openSleep.id }) {
                        var softDeleted = self.events[idx]
                        softDeleted.deletedAt = self.now
                        softDeleted.updatedAt = self.now
                        softDeleted.updatedBy = self.currentUserId
                        self.events[idx] = softDeleted
                        self.enqueueEventOutbox(softDeleted, operation: .delete)
                        self.persistState()
                        self.triggerBackgroundFlush()
                    }
                } else {
                    self.removeNewlyCreatedEvents(ids: [openSleep.id])
                }
            }
            return nil
        }

        let end = max(now, napStart)
        let napNumber = completedNapsToday.count + 1

        if let openIndex = latestOpenSleepEventIndex() {
            let previousOpen = events[openIndex]
            let isNight: Bool = {
                if case .sleep(let meta) = previousOpen.metadata {
                    return meta.sleepType == .night
                }
                return shouldClassifySleepAsNight(asOf: napStart)
            }()

            var completed = previousOpen
            completed.startedAt = napStart
            completed.endedAt = end
            completed.updatedAt = now
            completed.updatedBy = currentUserId
            events[openIndex] = completed

            activeNapStart = nil
            enqueueEventOutbox(completed, operation: .upsert)
            persistState()
            triggerBackgroundFlush()

            let savedMessage = isNight ? "Night sleep saved" : "Nap \(napNumber) saved"
            showToast(savedMessage) { [weak self] in
                guard let self else { return }
                if let idx = self.events.firstIndex(where: { $0.id == completed.id }) {
                    var reopened = completed
                    reopened.endedAt = nil
                    reopened.updatedAt = self.now
                    reopened.updatedBy = self.currentUserId
                    self.events[idx] = reopened
                    self.enqueueEventOutbox(reopened, operation: .upsert)
                }
                self.activeNapStart = napStart
                self.persistState()
                self.triggerBackgroundFlush()
            }
            return completed
        }

        // Legacy fallback when `activeNapStart` existed without a backing open-ended event
        let isNight = shouldClassifySleepAsNight(asOf: napStart)
        let sleepEvent = makeEvent(
            type: .sleep,
            startedAt: napStart,
            endedAt: end,
            metadata: .sleep(SleepMetadata(sleepType: isNight ? .night : .nap))
        )

        activeNapStart = nil
        appendEvents([sleepEvent])

        let savedMessage = isNight ? "Night sleep saved" : "Nap \(napNumber) saved"
        showToast(savedMessage) { [weak self] in
            guard let self else { return }
            self.removeNewlyCreatedEvents(ids: [sleepEvent.id])
            self.activeNapStart = napStart
            self.persistState()
        }
        return sleepEvent
    }

    public func updateActiveNapStart(_ newStart: Date) {
        let previous = activeNapStart
        activeNapStart = newStart

        let openEventId: UUID?
        let previousOpenEvent: EventDTO?
        if let idx = latestOpenSleepEventIndex() {
            previousOpenEvent = events[idx]
            openEventId = events[idx].id
            var updated = events[idx]
            updated.startedAt = newStart
            updated.updatedAt = now
            updated.updatedBy = currentUserId
            events[idx] = updated
            enqueueEventOutbox(updated, operation: .upsert)
            triggerBackgroundFlush()
        } else {
            openEventId = nil
            previousOpenEvent = nil
        }

        persistState()
        let clock = FormattingHelpers.formatClock(newStart, timeZone: profileTimeZone)
        showToast("Nap start set to \(clock)") { [weak self] in
            guard let self else { return }
            self.activeNapStart = previous
            if let openEventId,
               let previousOpenEvent,
               let idx = self.events.firstIndex(where: { $0.id == openEventId })
            {
                var reverted = previousOpenEvent
                reverted.updatedAt = self.now
                reverted.updatedBy = self.currentUserId
                self.events[idx] = reverted
                self.enqueueEventOutbox(reverted, operation: .upsert)
                self.triggerBackgroundFlush()
            }
            self.persistState()
        }
    }

    @discardableResult
    public func logPastSleep(
        isNap: Bool,
        start: Date,
        end: Date,
        location: SleepLocation? = nil,
        notes: String? = nil
    ) -> EventDTO? {
        guard end > start else { return nil }
        let event = makeEvent(
            type: .sleep,
            startedAt: start,
            endedAt: end,
            notes: trimmedNonEmpty(notes),
            metadata: .sleep(SleepMetadata(sleepType: isNap ? .nap : .night, location: location))
        )
        let duration = FormattingHelpers.formatDuration(minutes: end.timeIntervalSince(start) / 60.0)
        commitNewEvents([event], toastMessage: "\(isNap ? "Nap" : "Night sleep") logged · \(duration)")
        return event
    }

    // MARK: - Nursing Actions

    public func tapNursingSide(_ side: BreastSide) {
        let targetSide: BreastSide = (side == .right) ? .right : .left
        guard let session = activeNursing else {
            activeNursing = ActiveNursingSession(
                startedAt: now,
                leftAccumulatedSeconds: 0,
                rightAccumulatedSeconds: 0,
                activeSide: targetSide,
                activeSegmentStartedAt: now
            )
            persistState()
            return
        }

        let elapsed = session.elapsedSeconds(asOf: now)
        if session.activeSide == targetSide {
            activeNursing = ActiveNursingSession(
                startedAt: session.startedAt,
                leftAccumulatedSeconds: elapsed.left,
                rightAccumulatedSeconds: elapsed.right,
                activeSide: nil,
                activeSegmentStartedAt: nil
            )
        } else {
            activeNursing = ActiveNursingSession(
                startedAt: session.startedAt,
                leftAccumulatedSeconds: elapsed.left,
                rightAccumulatedSeconds: elapsed.right,
                activeSide: targetSide,
                activeSegmentStartedAt: now
            )
        }
        persistState()
    }

    @discardableResult
    public func finishNursing() -> EventDTO? {
        guard let session = activeNursing else { return nil }
        let elapsed = session.elapsedSeconds(asOf: now)
        let pausedBackup = ActiveNursingSession(
            startedAt: session.startedAt,
            leftAccumulatedSeconds: elapsed.left,
            rightAccumulatedSeconds: elapsed.right,
            activeSide: nil,
            activeSegmentStartedAt: nil
        )

        let both = elapsed.left > 0 && elapsed.right > 0
        let side: BreastSide = both ? .both : (elapsed.left > 0 ? .left : .right)
        let leftMinutes = max(1, Int((elapsed.left / 60.0).rounded()))
        let rightMinutes = max(1, Int((elapsed.right / 60.0).rounded()))
        let totalMinutes = both ? (leftMinutes + rightMinutes) : max(1, Int((elapsed.total / 60.0).rounded()))

        let event = makeEvent(
            type: .feeding,
            startedAt: session.startedAt,
            endedAt: max(now, session.startedAt),
            metadata: .feeding(
                FeedingMetadata(
                    method: .breast,
                    substance: .breastMilk,
                    amountMl: nil,
                    displayUnit: preferredUnit,
                    side: side,
                    durationMinutes: Double(totalMinutes),
                    leftDurationSeconds: Int(elapsed.left.rounded()),
                    rightDurationSeconds: Int(elapsed.right.rounded())
                )
            )
        )

        activeNursing = nil
        appendEvents([event])
        showToast("Nursing logged · \(totalMinutes)m") { [weak self] in
            guard let self else { return }
            self.removeNewlyCreatedEvents(ids: [event.id])
            self.activeNursing = pausedBackup
            self.persistState()
        }
        return event
    }

    public func discardNursing() {
        guard let session = activeNursing else { return }
        let elapsed = session.elapsedSeconds(asOf: now)
        let pausedBackup = ActiveNursingSession(
            startedAt: session.startedAt,
            leftAccumulatedSeconds: elapsed.left,
            rightAccumulatedSeconds: elapsed.right,
            activeSide: nil,
            activeSegmentStartedAt: nil
        )
        activeNursing = nil
        persistState()
        showToast("Nursing timer discarded") { [weak self] in
            guard let self else { return }
            self.activeNursing = pausedBackup
            self.persistState()
        }
    }

    @discardableResult
    public func logManualNursing(
        startedAt: Date,
        minutes: Double,
        side: BreastSide,
        notes: String? = nil
    ) -> EventDTO {
        let clampedMinutes = max(0, minutes)
        let endedAt = startedAt.addingTimeInterval(clampedMinutes * 60.0)
        let event = makeEvent(
            type: .feeding,
            startedAt: startedAt,
            endedAt: endedAt,
            notes: trimmedNonEmpty(notes),
            metadata: .feeding(
                FeedingMetadata(
                    method: .breast,
                    substance: .breastMilk,
                    amountMl: nil,
                    displayUnit: preferredUnit,
                    side: side,
                    durationMinutes: clampedMinutes
                )
            )
        )
        let minText = FormattingHelpers.formatNumber(clampedMinutes, maxFractionDigits: 1)
        commitNewEvents([event], toastMessage: "Nursing logged · \(minText)m")
        return event
    }

    // MARK: - Daily Care Logging Actions

    @discardableResult
    public func logBottle(
        startedAt: Date,
        amount: Double,
        unit: VolumeUnit,
        substance: FeedingSubstance,
        includeVitaminD: Bool = false,
        notes: String? = nil
    ) -> [EventDTO] {
        let amountMl = unit == .oz ? UnitConversion.ozToMl(amount) : amount
        let bottle = makeEvent(
            type: .feeding,
            startedAt: startedAt,
            notes: trimmedNonEmpty(notes),
            metadata: .feeding(
                FeedingMetadata(
                    method: .bottle,
                    substance: substance,
                    amountMl: amountMl,
                    displayUnit: unit
                )
            )
        )

        var batch = [bottle]
        if includeVitaminD {
            let vitD = makeEvent(
                type: .medicine,
                startedAt: startedAt,
                metadata: .medicine(
                    MedicineMetadata(
                        name: "Vitamin D",
                        category: .supplement,
                        dose: 1,
                        unit: .drops
                    )
                )
            )
            batch.append(vitD)
        }

        let amountLabel = FormattingHelpers.formatAmount(amount, unit: unit)
        commitNewEvents(batch, toastMessage: "Bottle logged · \(amountLabel)")
        return batch
    }

    @discardableResult
    public func logPump(
        startedAt: Date,
        amount: Double,
        unit: VolumeUnit,
        side: BreastSide,
        durationMinutes: Double? = nil,
        notes: String? = nil
    ) -> EventDTO {
        let amountMl = unit == .oz ? UnitConversion.ozToMl(amount) : amount
        let event = makeEvent(
            type: .pump,
            startedAt: startedAt,
            notes: trimmedNonEmpty(notes),
            metadata: .pump(
                PumpMetadata(
                    amountMl: amountMl,
                    displayUnit: unit,
                    side: side,
                    durationMinutes: durationMinutes
                )
            )
        )
        let amountLabel = FormattingHelpers.formatAmount(amount, unit: unit)
        commitNewEvents([event], toastMessage: "Pump logged · \(amountLabel)")
        return event
    }

    @discardableResult
    public func logDiaper(
        startedAt: Date,
        pee: DiaperSize?,
        poop: DiaperSize?,
        rash: Bool = false,
        notes: String? = nil
    ) -> EventDTO {
        let event = makeEvent(
            type: .diaper,
            startedAt: startedAt,
            notes: trimmedNonEmpty(notes),
            metadata: .diaper(DiaperMetadata(peeSize: pee, poopSize: poop, rash: rash))
        )
        let detail = eventDetail(for: event)
        commitNewEvents([event], toastMessage: "Diaper logged · \(detail)")
        return event
    }

    @discardableResult
    public func logMeal(
        startedAt: Date,
        slot: MealSlot,
        ate: String? = nil,
        portion: PortionEaten? = nil
    ) -> EventDTO {
        let event = makeEvent(
            type: .meal,
            startedAt: startedAt,
            notes: trimmedNonEmpty(ate),
            metadata: .meal(MealMetadata(mealSlot: slot, portionEaten: portion))
        )
        commitNewEvents([event], toastMessage: "\(eventTitle(for: event)) logged")
        return event
    }

    @discardableResult
    public func logBath(
        startedAt: Date,
        washedHair: Bool,
        notes: String? = nil
    ) -> EventDTO {
        let event = makeEvent(
            type: .bath,
            startedAt: startedAt,
            notes: trimmedNonEmpty(notes),
            metadata: .bath(BathMetadata(washedHair: washedHair))
        )
        commitNewEvents([event], toastMessage: "Bath logged")
        return event
    }

    @discardableResult
    public func logMedicine(
        startedAt: Date,
        name: String,
        category: MedicineCategory,
        dose: Double? = nil,
        unit: DoseUnit? = nil,
        notes: String? = nil
    ) -> EventDTO {
        let cleanName = trimmedNonEmpty(name) ?? "Meds & care"
        let effectiveDose = category == .topical ? nil : dose
        let effectiveUnit = (category == .topical || effectiveDose == nil) ? nil : unit
        let event = makeEvent(
            type: .medicine,
            startedAt: startedAt,
            notes: trimmedNonEmpty(notes),
            metadata: .medicine(
                MedicineMetadata(
                    name: cleanName,
                    category: category,
                    dose: effectiveDose,
                    unit: effectiveUnit
                )
            )
        )
        commitNewEvents([event], toastMessage: "\(cleanName) logged")
        return event
    }

    @discardableResult
    public func logNote(startedAt: Date, text: String) -> EventDTO {
        let event = makeEvent(
            type: .note,
            startedAt: startedAt,
            notes: trimmedNonEmpty(text),
            metadata: .note(NoteMetadata())
        )
        commitNewEvents([event], toastMessage: "Note saved")
        return event
    }

    // MARK: - Edit & Soft-Delete with Undo

    public func updateEvent(_ updated: EventDTO) {
        guard let index = events.firstIndex(where: { $0.id == updated.id }) else { return }
        let previous = events[index]
        var stamped = updated
        stamped.updatedAt = now
        stamped.updatedBy = currentUserId
        events[index] = stamped

        enqueueEventOutbox(stamped, operation: .upsert)
        persistState()
        triggerBackgroundFlush()

        let title = eventTitle(for: stamped)
        showToast("\(title) updated") { [weak self] in
            guard let self, let idx = self.events.firstIndex(where: { $0.id == previous.id }) else { return }
            var restored = previous
            restored.updatedAt = self.now
            restored.updatedBy = self.currentUserId
            self.events[idx] = restored
            self.enqueueEventOutbox(restored, operation: .upsert)
            self.persistState()
            self.triggerBackgroundFlush()
        }
    }

    public func deleteEvent(_ event: EventDTO) {
        guard let index = events.firstIndex(where: { $0.id == event.id }) else { return }
        let previous = events[index]
        let title = eventTitle(for: previous)

        var softDeleted = previous
        softDeleted.deletedAt = now
        softDeleted.updatedAt = now
        softDeleted.updatedBy = currentUserId
        events[index] = softDeleted

        enqueueEventOutbox(softDeleted, operation: .delete)
        persistState()
        triggerBackgroundFlush()

        showToast("\(title) deleted") { [weak self] in
            guard let self, let idx = self.events.firstIndex(where: { $0.id == previous.id }) else { return }
            var restored = previous
            restored.deletedAt = nil
            restored.updatedAt = self.now
            restored.updatedBy = self.currentUserId
            self.events[idx] = restored
            self.enqueueEventOutbox(restored, operation: .upsert)
            self.persistState()
            self.triggerBackgroundFlush()
        }
    }

    // MARK: - Paper Scan Review & Live OCR Pipeline

    public func addScannedSheet(_ sheet: ScannedSheetRecord) {
        scannedSheets.insert(sheet, at: 0)
        persistState()
    }

    /// Compresses a caregiver sheet photo, uploads it to Cloudflare R2 via presigned URL, runs live VLM extraction,
    /// and maps the extracted drafts (including `+ VIT D` companion suggestions & ambiguities) into a reviewable sheet.
    /// Falls back cleanly to a local sheet when offline / not signed in.
    public func processScannedPhotoAsync(
        _ rawData: Data,
        fallbackDrafts: [ScanReviewDraftItem] = []
    ) async throws -> ScannedSheetRecord {
        let compressed = ImageCompressor.compressForScanUpload(rawData)

        guard hasLiveSession, let apiClient else {
            let clock = FormattingHelpers.formatClock(now, timeZone: profileTimeZone)
            let localSheet = ScannedSheetRecord(
                title: "Grandma's sheet, \(clock)",
                subtitle: Self.buildScanSubtitle(from: fallbackDrafts),
                listLabel: "Today, \(clock)",
                scannedAt: now,
                status: .pendingReview,
                drafts: fallbackDrafts,
                previewLines: [],
                imageData: compressed.data,
                confirmedEntryCount: 0,
                scanDate: Self.formatCalendarDateISO(now, timeZone: profileTimeZone)
            )
            addScannedSheet(localSheet)
            return localSheet
        }

        isProcessingScan = true
        defer { isProcessingScan = false }

        let presign = try await performAuthorized { token in
            try await apiClient.presignScan(
                PresignUploadRequest(
                    profileId: self.profile.id,
                    contentType: compressed.contentType,
                    fileSizeBytes: compressed.data.count
                ),
                accessToken: token
            )
        }

        guard let uploadURL = URL(string: presign.uploadUrl) else {
            throw BackendAPIError.invalidURL
        }

        try await apiClient.uploadScanBytes(
            to: uploadURL,
            headers: presign.uploadHeaders,
            data: compressed.data
        )

        let todayISO = Self.formatCalendarDateISO(now, timeZone: profileTimeZone)
        let extractedScan = try await performAuthorized { token in
            try await apiClient.extractScan(
                ExtractPaperScanRequest(
                    scanId: presign.scanId,
                    profileId: self.profile.id,
                    storageKey: presign.storageKey,
                    scanDate: todayISO,
                    timezone: self.profile.defaultTimezone
                ),
                accessToken: token
            )
        }

        let scanTimeZone = TimeZone(identifier: extractedScan.timezone) ?? profileTimeZone
        var mappedDrafts: [ScanReviewDraftItem] = []
        if let extraction = extractedScan.rawExtraction {
            for (index, extractedDraft) in extraction.events.enumerated() {
                let rowDrafts = ScanReviewDraftItem.from(
                    extractedDraft: extractedDraft,
                    rowKey: "row-\(index)",
                    timeZone: scanTimeZone,
                    preferredUnit: preferredUnit
                )
                mappedDrafts.append(contentsOf: rowDrafts)
            }
        }

        let clock = FormattingHelpers.formatClock(now, timeZone: profileTimeZone)
        let record = ScannedSheetRecord(
            id: extractedScan.id,
            title: "Grandma's sheet, \(clock)",
            subtitle: Self.buildScanSubtitle(from: mappedDrafts),
            listLabel: "Today, \(clock)",
            scannedAt: now,
            status: .pendingReview,
            drafts: mappedDrafts,
            previewLines: [],
            imageData: compressed.data,
            confirmedEntryCount: 0,
            scanDate: extractedScan.scanDate,
            sheetNotes: extractedScan.sheetNotes ?? extractedScan.rawExtraction?.sheetNotes
        )

        scannedSheets.removeAll { $0.id == record.id }
        scannedSheets.insert(record, at: 0)
        persistState()
        return record
    }

    @discardableResult
    public func confirmScanReview(sheetId: UUID, drafts: [ScanReviewDraftItem]) -> [EventDTO] {
        confirmScanReviewLocally(sheetId: sheetId, drafts: drafts, enqueueAndFlushOutbox: true)
    }

    /// Optimistically confirms a scanned sheet locally and, when signed in, persists it via `POST /v1/scans/:id/confirm`
    /// so PostgreSQL marks the scan confirmed and broadcasts SSE to all household devices without duplicate pushes.
    @discardableResult
    public func confirmScanReviewAsync(sheetId: UUID, drafts: [ScanReviewDraftItem]) async -> [EventDTO] {
        guard hasLiveSession, let apiClient else {
            return confirmScanReview(sheetId: sheetId, drafts: drafts)
        }

        let existingSheet = scannedSheets.first(where: { $0.id == sheetId })
        let createdEvents = confirmScanReviewLocally(
            sheetId: sheetId,
            drafts: drafts,
            enqueueAndFlushOutbox: false
        )
        guard !createdEvents.isEmpty else {
            return []
        }

        let scanDate = existingSheet?.scanDate
            ?? Self.formatCalendarDateISO(createdEvents.first?.startedAt ?? now, timeZone: profileTimeZone)
        let sheetNotes = existingSheet?.sheetNotes

        let request = ConfirmPaperScanRequest(
            scanId: sheetId,
            profileId: profile.id,
            scanDate: scanDate,
            sheetNotes: sheetNotes,
            events: createdEvents,
            status: .confirmed
        )

        do {
            _ = try await performAuthorized { token in
                try await apiClient.confirmScan(request, accessToken: token)
            }
            lastSyncError = nil
            persistState()
        } catch {
            // Offline fallback: enqueue confirmed events into durable outbox so they still sync when online.
            for event in createdEvents {
                enqueueEventOutbox(event, operation: .upsert)
            }
            lastSyncError = error.localizedDescription
            if isSignedInWithApple {
                syncStatus = .offline(pendingCount: outbox.count)
            }
            persistState()
        }

        return createdEvents
    }

    private func confirmScanReviewLocally(
        sheetId: UUID,
        drafts: [ScanReviewDraftItem],
        enqueueAndFlushOutbox: Bool
    ) -> [EventDTO] {
        let included = drafts.filter(\.isIncluded)
        guard !included.isEmpty, included.allSatisfy({ !$0.hasUnresolvedAmbiguity }) else {
            return []
        }

        var newlyCreatedIds: Set<UUID> = []
        var updatedBackups: [(index: Int, previous: EventDTO)] = []
        var confirmedEvents: [EventDTO] = []

        for draft in included {
            let effectiveStart = draft.effectiveStartedAt
            let adjustedEnd: Date? = {
                guard let endedAt = draft.endedAt else { return nil }
                if effectiveStart != draft.startedAt {
                    let duration = max(0, endedAt.timeIntervalSince(draft.startedAt))
                    return effectiveStart.addingTimeInterval(duration)
                }
                return endedAt
            }()

            if draft.matchAction == .updateExisting,
               let matchedId = draft.matchedEventId,
               let existingIdx = events.firstIndex(where: { $0.id == matchedId })
            {
                let previous = events[existingIdx]
                var updated = previous
                updated.startedAt = effectiveStart
                updated.endedAt = adjustedEnd ?? previous.endedAt
                updated.notes = draft.notes ?? previous.notes
                updated.metadata = draft.metadata
                updated.source = .paperScan
                updated.scanId = sheetId
                updated.updatedAt = now
                updated.updatedBy = currentUserId
                events[existingIdx] = updated
                updatedBackups.append((existingIdx, previous))
                confirmedEvents.append(updated)
            } else {
                let created = makeEvent(
                    type: draft.eventType,
                    startedAt: effectiveStart,
                    endedAt: adjustedEnd,
                    notes: draft.notes,
                    metadata: draft.metadata,
                    source: .paperScan,
                    scanId: sheetId
                )
                events.append(created)
                newlyCreatedIds.insert(created.id)
                confirmedEvents.append(created)
            }
        }

        let sheetIndex = scannedSheets.firstIndex(where: { $0.id == sheetId })
        let previousSheet = sheetIndex.map { scannedSheets[$0] }
        if let sheetIndex {
            scannedSheets[sheetIndex].status = .confirmed
            scannedSheets[sheetIndex].drafts = drafts
            scannedSheets[sheetIndex].confirmedEntryCount = confirmedEvents.count
            scannedSheets[sheetIndex].subtitle = "Entries saved"
        }

        if enqueueAndFlushOutbox {
            for event in confirmedEvents {
                enqueueEventOutbox(event, operation: .upsert)
            }
            persistState()
            triggerBackgroundFlush()
        } else {
            persistState()
        }

        let count = confirmedEvents.count
        let noun = count == 1 ? "entry" : "entries"
        showToast("\(count) \(noun) saved from Grandma's sheet") { [weak self] in
            guard let self else { return }
            if !newlyCreatedIds.isEmpty {
                self.removeNewlyCreatedEvents(ids: newlyCreatedIds)
            }
            for backup in updatedBackups {
                if let idx = self.events.firstIndex(where: { $0.id == backup.previous.id }) {
                    self.events[idx] = backup.previous
                }
            }
            if let sheetIndex, let previousSheet, sheetIndex < self.scannedSheets.count {
                self.scannedSheets[sheetIndex] = previousSheet
            }
            self.persistState()
        }
        return confirmedEvents
    }

    // MARK: - Portability & Import

    @discardableResult
    public func importHuckleberryCSV(_ csv: String) -> Int {
        let parsed = HuckleberryCSVImporter.parse(
            csvString: csv,
            profileId: profile.id,
            userId: currentUserId,
            timezone: profile.defaultTimezone
        )

        var existingExternalIds = Set(activeEvents.compactMap(\.externalId))
        var newlyAdded: [EventDTO] = []
        for event in parsed {
            if let extId = event.externalId {
                guard existingExternalIds.insert(extId).inserted else { continue }
            }
            newlyAdded.append(event)
        }

        guard !newlyAdded.isEmpty else {
            showToast("No new entries found in CSV", undo: nil)
            return 0
        }

        let noun = newlyAdded.count == 1 ? "entry" : "entries"
        commitNewEvents(newlyAdded, toastMessage: "Imported \(newlyAdded.count) \(noun) from Huckleberry")
        return newlyAdded.count
    }

    @discardableResult
    public func importLosslessJSONData(_ data: Data) throws -> Int {
        let bundle = try DataPortabilityService.importLosslessJSON(data)
        let existingIds = Set(events.map(\.id))
        let existingExternalIds = Set(activeEvents.compactMap(\.externalId))

        var newlyAdded: [EventDTO] = []
        for event in bundle.events {
            if existingIds.contains(event.id) { continue }
            if let extId = event.externalId, existingExternalIds.contains(extId) { continue }
            newlyAdded.append(event)
        }

        if !newlyAdded.isEmpty {
            let noun = newlyAdded.count == 1 ? "entry" : "entries"
            commitNewEvents(newlyAdded, toastMessage: "Restored \(newlyAdded.count) \(noun) from backup")
        }
        return newlyAdded.count
    }

    public func exportLosslessJSONData() throws -> Data {
        try DataPortabilityService.exportLosslessJSON(
            household: household,
            profile: profile,
            events: activeEvents,
            exportedAt: now
        )
    }

    public func exportPediatricianCSVString() -> String {
        DataPortabilityService.exportPediatricianCSV(
            events: activeEvents,
            timezone: profile.defaultTimezone,
            preferredUnit: preferredUnit
        )
    }

    // MARK: - Live Auth, Household & Account Actions

    /// Executes an authorized backend call with automatic single-flight `401` refresh-token rotation and one retry.
    public func performAuthorized<T>(_ op: (String) async throws -> T) async throws -> T {
        guard apiClient != nil else {
            throw BackendAPIError.networkError("Backend client is not configured.")
        }

        let initialToken: String
        if let current = accessToken, !current.isEmpty {
            initialToken = current
        } else if refreshToken != nil {
            initialToken = try await refreshAccessTokenIfPossible()
        } else {
            throw BackendAPIError.unauthorized
        }

        do {
            return try await op(initialToken)
        } catch BackendAPIError.unauthorized {
            let refreshedToken = try await refreshAccessTokenIfPossible()
            do {
                return try await op(refreshedToken)
            } catch BackendAPIError.unauthorized {
                handleExpiredSession()
                throw BackendAPIError.unauthorized
            }
        }
    }

    /// Completes Sign in with Apple against `POST /v1/auth/apple`, persists rotated tokens in Keychain,
    /// resolves existing households (preferring multi-member / profiled households), or transitions a brand-new user
    /// to `.needsHouseholdSetup` without auto-creating an orphaned household.
    public func completeAppleSignIn(
        identityToken: String,
        rawNonce: String,
        authorizationCode: String? = nil,
        displayName: String? = nil,
        email: String? = nil
    ) async throws {
        guard let apiClient else {
            throw BackendAPIError.networkError("Backend client is not configured.")
        }

        isAuthenticating = true
        defer { isAuthenticating = false }

        do {
            let deviceId = tokenStore.loadOrCreateDeviceId()
            let request = AppleAuthRequest(
                identityToken: identityToken,
                rawNonce: rawNonce,
                authorizationCode: trimmedNonEmpty(authorizationCode),
                displayName: trimmedNonEmpty(displayName),
                deviceId: deviceId,
                deviceName: Self.currentDeviceName(),
                platform: "ios"
            )

            let session = try await apiClient.signInWithApple(request)
            saveSessionTokens(session, deviceId: deviceId)

            currentUserId = session.user.id
            authEmail = trimmedNonEmpty(session.user.primaryEmail) ?? trimmedNonEmpty(email)
            self.displayName = trimmedNonEmpty(session.user.displayName) ?? trimmedNonEmpty(displayName)
            isSignedInWithApple = true
            isDemoPreview = false
            now = Date()
            lastSyncError = nil

            if !session.households.isEmpty {
                let profiles = try await performAuthorized { token in
                    try await apiClient.listProfiles(accessToken: token)
                }
                let chosenHousehold = Self.selectPreferredHousehold(from: session.households, profiles: profiles)
                    ?? session.households[0]
                household = chosenHousehold

                if let matched = profiles.first(where: { $0.householdId == chosenHousehold.id && $0.deletedAt == nil }) {
                    profile = matched
                } else {
                    profile = try await performAuthorized { token in
                        try await apiClient.createProfile(
                            CreateProfileRequest(
                                householdId: chosenHousehold.id,
                                displayName: "Blythe",
                                defaultTimezone: TimeZone.current.identifier,
                                scheduleConfig: ScheduleConfig()
                            ),
                            accessToken: token
                        )
                    }
                }

                // Clear stale local state before pulling authoritative server history.
                events = []
                scannedSheets = []
                activeNapStart = nil
                activeNursing = nil
                outbox = []
                serverWatermark = nil
                hasCompletedHouseholdSetup = true
                sessionStage = .ready
                persistState()

                await pullFromServer()
                startRealtimeSync()
                showToast("Signed in with Apple", undo: nil)
            } else {
                // Brand-new user: do NOT auto-create a household yet. Let the user choose Create vs Join.
                stopRealtimeSync()
                let blank = SampleSeedData.makeBlankState(referenceDate: now)
                household = blank.household
                profile = blank.profile
                events = []
                scannedSheets = []
                activeNapStart = nil
                activeNursing = nil
                outbox = []
                serverWatermark = nil
                hasCompletedHouseholdSetup = false
                sessionStage = .needsHouseholdSetup
                syncStatus = .localOnly
                persistState()

                showToast("Signed in with Apple", undo: nil)
            }
        } catch {
            lastSyncError = error.localizedDescription
            throw error
        }
    }

    /// Explicitly creates a new household and initial baby profile on Postgres during onboarding,
    /// then transitions the store to `.ready` and starts realtime sync.
    public func createHouseholdAndProfileAsync(
        householdName: String,
        babyName: String,
        birthDate: Date?
    ) async throws {
        guard let apiClient else {
            throw BackendAPIError.networkError("Backend client is not configured.")
        }

        let trimmedBabyName = trimmedNonEmpty(babyName) ?? "Blythe"
        let trimmedHouseholdName = trimmedNonEmpty(householdName) ?? "\(trimmedBabyName)'s household"
        let formattedBirthDate = birthDate.map { Self.formatCalendarDateISO($0, timeZone: TimeZone.current) }

        do {
            let createdHousehold = try await performAuthorized { token in
                try await apiClient.createHousehold(
                    name: trimmedHouseholdName,
                    accessToken: token
                )
            }
            let createdProfile = try await performAuthorized { token in
                try await apiClient.createProfile(
                    CreateProfileRequest(
                        householdId: createdHousehold.id,
                        displayName: trimmedBabyName,
                        birthDate: formattedBirthDate,
                        defaultTimezone: TimeZone.current.identifier,
                        scheduleConfig: ScheduleConfig()
                    ),
                    accessToken: token
                )
            }

            household = createdHousehold
            profile = createdProfile
            events = []
            scannedSheets = []
            activeNapStart = nil
            activeNursing = nil
            outbox = []
            serverWatermark = nil
            isDemoPreview = false
            hasCompletedHouseholdSetup = true
            sessionStage = .ready
            lastSyncError = nil
            now = Date()
            syncStatus = .synced(now)
            persistState()

            startRealtimeSync()
            showToast("Household created", undo: nil)
        } catch {
            lastSyncError = error.localizedDescription
            throw error
        }
    }

    /// Restores and resumes a live backend session on app launch or return to foreground.
    public func resumeLiveSession() async {
        guard let apiClient, !isDemoPreview else { return }

        if accessToken == nil && refreshToken == nil, let stored = tokenStore.load() {
            accessToken = stored.accessToken
            refreshToken = stored.refreshToken
            isSignedInWithApple = true
            if sessionStage == .signedOut {
                sessionStage = hasCompletedHouseholdSetup ? .ready : .needsHouseholdSetup
            }
        }

        guard isSignedInWithApple, !isDemoPreview, (accessToken != nil || refreshToken != nil) else { return }

        if sessionStage == .needsHouseholdSetup {
            do {
                let me = try await performAuthorized { token in
                    try await apiClient.fetchMe(accessToken: token)
                }
                currentUserId = me.user.id
                if let serverEmail = trimmedNonEmpty(me.user.primaryEmail) {
                    authEmail = serverEmail
                }
                if let serverName = trimmedNonEmpty(me.user.displayName) {
                    displayName = serverName
                }

                guard !me.households.isEmpty else {
                    hasCompletedHouseholdSetup = false
                    sessionStage = .needsHouseholdSetup
                    syncStatus = .localOnly
                    persistState()
                    return
                }

                let profiles = try await performAuthorized { token in
                    try await apiClient.listProfiles(accessToken: token)
                }
                let chosenHousehold = Self.selectPreferredHousehold(from: me.households, profiles: profiles)
                    ?? me.households[0]
                household = chosenHousehold

                if let matchedProfile = profiles.first(where: { $0.householdId == chosenHousehold.id && $0.deletedAt == nil }) {
                    profile = matchedProfile
                } else {
                    profile = try await performAuthorized { token in
                        try await apiClient.createProfile(
                            CreateProfileRequest(
                                householdId: chosenHousehold.id,
                                displayName: "Blythe",
                                defaultTimezone: TimeZone.current.identifier,
                                scheduleConfig: ScheduleConfig()
                            ),
                            accessToken: token
                        )
                    }
                }

                events = []
                scannedSheets = []
                activeNapStart = nil
                activeNursing = nil
                outbox = []
                serverWatermark = nil
                hasCompletedHouseholdSetup = true
                sessionStage = .ready
                now = Date()
                lastSyncError = nil
                persistState()

                await flushOutbox()
                await pullFromServer()
                startRealtimeSync()
            } catch BackendAPIError.unauthorized {
                // `performAuthorized` already signed out cleanly on refresh failure.
                return
            } catch {
                lastSyncError = error.localizedDescription
            }
            return
        }

        guard sessionStage == .ready else { return }

        now = Date()
        syncStatus = .syncing

        do {
            let me = try await performAuthorized { token in
                try await apiClient.fetchMe(accessToken: token)
            }
            currentUserId = me.user.id
            if let serverEmail = trimmedNonEmpty(me.user.primaryEmail) {
                authEmail = serverEmail
            }
            if let serverName = trimmedNonEmpty(me.user.displayName) {
                displayName = serverName
            }

            guard !me.households.isEmpty else {
                stopRealtimeSync()
                hasCompletedHouseholdSetup = false
                sessionStage = .needsHouseholdSetup
                syncStatus = .localOnly
                persistState()
                return
            }

            let profiles = try await performAuthorized { token in
                try await apiClient.listProfiles(accessToken: token)
            }

            if let matchingHousehold = me.households.first(where: { $0.id == self.household.id }) {
                household = matchingHousehold
            } else if let chosenHousehold = Self.selectPreferredHousehold(from: me.households, profiles: profiles) {
                household = chosenHousehold
            }

            if let sameProfile = profiles.first(where: {
                $0.id == self.profile.id && $0.householdId == self.household.id && $0.deletedAt == nil
            }) {
                if sameProfile.updatedAt >= profile.updatedAt {
                    profile = sameProfile
                }
            } else if let householdProfile = profiles.first(where: { $0.householdId == self.household.id && $0.deletedAt == nil }) {
                let wasDifferentProfile = (profile.id != householdProfile.id)
                profile = householdProfile
                if wasDifferentProfile {
                    events = []
                    scannedSheets = []
                    activeNapStart = nil
                    activeNursing = nil
                    serverWatermark = nil
                }
            } else {
                let wasDemoProfile = (profile.id == SampleSeedData.profileId)
                profile = try await performAuthorized { token in
                    try await apiClient.createProfile(
                        CreateProfileRequest(
                            householdId: self.household.id,
                            displayName: "Blythe",
                            defaultTimezone: TimeZone.current.identifier,
                            scheduleConfig: ScheduleConfig()
                        ),
                        accessToken: token
                    )
                }
                if wasDemoProfile {
                    events = []
                    scannedSheets = []
                    serverWatermark = nil
                }
            }

            hasCompletedHouseholdSetup = true
            sessionStage = .ready
            persistState()
        } catch BackendAPIError.unauthorized {
            // `performAuthorized` already signed out cleanly on refresh failure.
            return
        } catch {
            // Offline or transient failure: continue to outbox flush / pull / SSE reconnect cleanly.
            lastSyncError = error.localizedDescription
        }

        guard isSignedInWithApple && !isDemoPreview && sessionStage == .ready else { return }
        await flushOutbox()
        await pullFromServer()
        startRealtimeSync()
    }

    /// Alias for `resumeLiveSession()` used on initial app launch.
    public func bootstrapSessionOnLaunch() async {
        await resumeLiveSession()
    }

    /// Joins an existing household using a 6-digit invite code, adopts its profile, pulls shared events, and restarts SSE.
    public func joinHouseholdAsync(inviteCode: String, displayName: String? = nil) async throws {
        guard let apiClient else {
            throw BackendAPIError.networkError("Backend client is not configured.")
        }

        let cleanedCode = inviteCode.filter { !$0.isWhitespace }
        guard !cleanedCode.isEmpty else {
            throw BackendAPIError.httpError(statusCode: 400, message: "Invite code is required.")
        }

        let joined = try await performAuthorized { token in
            try await apiClient.joinHousehold(
                inviteCode: cleanedCode,
                displayName: self.trimmedNonEmpty(displayName) ?? self.displayName,
                accessToken: token
            )
        }
        household = joined

        let profiles = try await performAuthorized { token in
            try await apiClient.listProfiles(accessToken: token)
        }
        if let matchedProfile = profiles.first(where: { $0.householdId == joined.id && $0.deletedAt == nil }) {
            profile = matchedProfile
        } else if let fallbackProfile = profiles.first(where: { $0.deletedAt == nil }) {
            profile = fallbackProfile
        }

        events = []
        scannedSheets = []
        activeNapStart = nil
        activeNursing = nil
        outbox = []
        serverWatermark = nil
        isDemoPreview = false
        hasCompletedHouseholdSetup = true
        sessionStage = .ready
        lastSyncError = nil
        persistState()

        await pullFromServer()
        startRealtimeSync()
        showToast("Joined \(joined.name)", undo: nil)
    }

    /// Updates the baby profile's display name and optional birth date locally and persists via `PATCH /v1/profiles/:id`
    /// when signed in (with durable profile outbox fallback if offline).
    public func updateBabyProfileAsync(
        displayName: String,
        birthDate: Date?
    ) async throws {
        guard let trimmedName = trimmedNonEmpty(displayName) else {
            throw BackendAPIError.httpError(statusCode: 400, message: "Baby name is required.")
        }

        let formattedBirthDate = birthDate.map { Self.formatCalendarDateISO($0, timeZone: TimeZone.current) }
        profile.displayName = trimmedName
        profile.birthDate = formattedBirthDate
        profile.updatedAt = now
        persistState()

        if hasLiveSession, let apiClient {
            let request = UpdateProfileRequest(
                displayName: trimmedName,
                birthDate: formattedBirthDate
            )
            do {
                let updated = try await performAuthorized { token in
                    try await apiClient.updateProfile(
                        profileId: self.profile.id,
                        request: request,
                        accessToken: token
                    )
                }
                profile = updated
                lastSyncError = nil
                persistState()
            } catch BackendAPIError.unauthorized {
                lastSyncError = "Session expired. Sign in again."
                persistState()
                throw BackendAPIError.unauthorized
            } catch {
                // Offline fallback: enqueue profile upsert into durable outbox so it syncs when back online.
                enqueueProfileOutbox(profile)
                lastSyncError = error.localizedDescription
                if isSignedInWithApple {
                    syncStatus = .offline(pendingCount: outbox.count)
                }
                persistState()
            }
        }

        showToast("Profile updated", undo: nil)
    }

    /// Explicitly enters local interactive demo preview mode without touching Keychain auth tokens.
    public func enterDemoPreview() {
        stopRealtimeSync()
        let demo = SampleSeedData.makeDemoState(referenceDate: SampleSeedData.defaultReferenceDate)
        profile = demo.profile
        household = demo.household
        currentUserId = demo.currentUserId
        events = demo.events
        activeNapStart = nil
        activeNursing = nil
        scannedSheets = demo.pendingScans
        outbox = []
        serverWatermark = nil
        preferredUnit = demo.preferredUnit
        authEmail = demo.authEmail
        displayName = demo.displayName
        isDemoPreview = true
        hasCompletedHouseholdSetup = false
        sessionStage = .ready
        syncStatus = .localOnly
        lastSyncError = nil
        now = SampleSeedData.defaultReferenceDate
        dismissToast()
    }

    /// Exits interactive demo preview mode and resets to a clean signed-out blank state.
    public func exitDemoPreview() {
        stopRealtimeSync()
        let currentNow = Date()
        let blank = SampleSeedData.makeBlankState(referenceDate: currentNow)
        profile = blank.profile
        household = blank.household
        currentUserId = blank.currentUserId
        events = []
        activeNapStart = nil
        activeNursing = nil
        scannedSheets = []
        outbox = []
        serverWatermark = nil
        authEmail = nil
        displayName = nil
        isSignedInWithApple = false
        isDemoPreview = false
        hasCompletedHouseholdSetup = false
        sessionStage = .signedOut
        syncStatus = .localOnly
        lastSyncError = nil
        now = currentNow
        dismissToast()
        persistState()
    }

    /// Rotates the active household's 6-digit invite code via `POST /v1/households/:id/invite` when signed in,
    /// falling back to local generation in offline demo mode.
    public func rotateInviteCodeAsync() async {
        if hasLiveSession, let apiClient {
            do {
                let updated = try await performAuthorized { token in
                    try await apiClient.rotateInviteCode(householdId: self.household.id, accessToken: token)
                }
                household = updated
                lastSyncError = nil
                persistState()
                showToast("Invite code updated · \(formattedInviteCode)", undo: nil)
                return
            } catch {
                lastSyncError = error.localizedDescription
                showToast("Could not update invite code", undo: nil)
                return
            }
        }

        let newCode = String(format: "%06d", Int.random(in: 100_000 ... 999_999))
        household.inviteCode = newCode
        persistState()
        showToast("Invite code updated · \(formattedInviteCode)", undo: nil)
    }

    /// Revokes the current device session on the backend (best-effort if offline), clears Keychain tokens, and resets to clean signed-out state.
    public func signOutOnThisDeviceAsync() async {
        let currentAccess = accessToken
        let currentRefresh = refreshToken
        let deviceId = tokenStore.loadOrCreateDeviceId()

        stopRealtimeSync()
        inFlightRefreshTask?.cancel()
        inFlightRefreshTask = nil

        if let apiClient, (currentRefresh != nil || currentAccess != nil) {
            try? await apiClient.logout(
                LogoutRequest(refreshToken: currentRefresh, deviceId: deviceId, revokeAllDevices: false),
                accessToken: currentAccess
            )
        }

        try? tokenStore.clear()
        try? storage.clear()
        accessToken = nil
        refreshToken = nil

        let currentNow = Date()
        let blank = SampleSeedData.makeBlankState(referenceDate: currentNow)
        profile = blank.profile
        household = blank.household
        currentUserId = blank.currentUserId
        events = []
        activeNapStart = nil
        activeNursing = nil
        scannedSheets = []
        outbox = []
        serverWatermark = nil
        isSignedInWithApple = false
        isDemoPreview = false
        hasCompletedHouseholdSetup = false
        sessionStage = .signedOut
        authEmail = nil
        displayName = nil
        syncStatus = .localOnly
        lastSyncError = nil
        now = currentNow
        persistState()
        showToast("Signed out on this device", undo: nil)
    }

    /// Permanently deletes the account via `DELETE /v1/account` (triggering Apple `.p8` token revocation server-side),
    /// clears Keychain tokens, stops SSE, and wipes local state.
    public func deleteAccountAsync() async throws {
        if hasLiveSession, let apiClient {
            try await performAuthorized { token in
                try await apiClient.deleteAccount(accessToken: token)
            }
        }

        stopRealtimeSync()
        inFlightRefreshTask?.cancel()
        inFlightRefreshTask = nil
        try? tokenStore.clear()
        try? storage.clear()

        let currentNow = Date()
        let blank = SampleSeedData.makeBlankState(referenceDate: currentNow)
        accessToken = nil
        refreshToken = nil
        profile = blank.profile
        household = blank.household
        currentUserId = blank.currentUserId
        isSignedInWithApple = false
        isDemoPreview = false
        hasCompletedHouseholdSetup = false
        sessionStage = .signedOut
        authEmail = nil
        displayName = nil
        events = []
        scannedSheets = []
        activeNapStart = nil
        activeNursing = nil
        outbox = []
        serverWatermark = nil
        syncStatus = .localOnly
        lastSyncError = nil
        now = currentNow
        persistState()
        showToast("Account deleted", undo: nil)
    }

    /// Checks live backend health via `GET /health` for Settings diagnostics.
    public func checkBackendHealth() async -> BackendHealthResponse? {
        guard let apiClient else { return nil }
        return try? await apiClient.fetchHealth()
    }

    // MARK: - Settings & Preferences

    public func updateScheduleConfig(_ config: ScheduleConfig) {
        let previous = profile.scheduleConfig
        profile.scheduleConfig = config
        profile.updatedAt = now
        enqueueProfileOutbox(profile)
        persistState()
        triggerBackgroundFlush()

        showToast("Nap schedule updated") { [weak self] in
            guard let self else { return }
            self.profile.scheduleConfig = previous
            self.profile.updatedAt = self.now
            self.enqueueProfileOutbox(self.profile)
            self.persistState()
            self.triggerBackgroundFlush()
        }
    }

    public func setPreferredUnit(_ unit: VolumeUnit) {
        guard preferredUnit != unit else { return }
        preferredUnit = unit
        persistState()
    }

    public func toggleTheme() {
        colorModePreference = (colorModePreference == .night) ? .day : .night
        persistState()
    }

    public func setColorMode(_ mode: AppColorModePreference) {
        guard colorModePreference != mode else { return }
        colorModePreference = mode
        persistState()
    }

    public func setPostureOverride(_ override: PosturePreviewOverride) {
        postureOverride = override
    }

    public func signOutOnThisDevice() {
        stopRealtimeSync()
        inFlightRefreshTask?.cancel()
        inFlightRefreshTask = nil
        try? tokenStore.clear()
        try? storage.clear()
        accessToken = nil
        refreshToken = nil

        let currentNow = Date()
        let blank = SampleSeedData.makeBlankState(referenceDate: currentNow)
        profile = blank.profile
        household = blank.household
        currentUserId = blank.currentUserId
        events = []
        activeNapStart = nil
        activeNursing = nil
        scannedSheets = []
        outbox = []
        serverWatermark = nil
        isSignedInWithApple = false
        isDemoPreview = false
        hasCompletedHouseholdSetup = false
        sessionStage = .signedOut
        authEmail = nil
        displayName = nil
        syncStatus = .localOnly
        lastSyncError = nil
        now = currentNow
        persistState()
        showToast("Signed out on this device", undo: nil)
    }

    public func signInWithAppleSession(_ session: AuthSessionResponse) {
        let deviceId = tokenStore.loadOrCreateDeviceId()
        saveSessionTokens(session, deviceId: deviceId)
        isSignedInWithApple = true
        isDemoPreview = false
        authEmail = session.user.primaryEmail
        displayName = session.user.displayName
        currentUserId = session.user.id
        if let firstHousehold = session.households.first {
            household = firstHousehold
            hasCompletedHouseholdSetup = true
            sessionStage = .ready
        } else {
            hasCompletedHouseholdSetup = false
            sessionStage = .needsHouseholdSetup
        }
        lastSyncError = nil
        persistState()
        triggerBackgroundFlush()
    }

    // MARK: - Toast & Undo

    public func undoLastToast() {
        let action = undoAction
        undoAction = nil
        dismissToast()
        action?()
    }

    public func dismissToast() {
        toastDismissTask?.cancel()
        toastDismissTask = nil
        toast = nil
    }

    public func showInfoToast(_ message: String) {
        showToast(message, undo: nil)
    }

    // MARK: - Sync Engine

    public func configureSync(accessToken: String?) {
        self.accessToken = accessToken
        if accessToken != nil && apiClient != nil {
            isSignedInWithApple = true
            triggerBackgroundFlush()
        } else {
            syncStatus = .localOnly
        }
    }

    public func flushOutbox() async {
        guard let apiClient,
              !isDemoPreview,
              sessionStage == .ready,
              (accessToken != nil || refreshToken != nil)
        else { return }
        guard !outbox.isEmpty else {
            if let watermark = serverWatermark {
                syncStatus = .synced(watermark)
            }
            return
        }

        syncStatus = .syncing

        var eventsById: [UUID: EventDTO] = [:]
        var profilesById: [UUID: ProfileDTO] = [:]
        for item in outbox {
            switch item.entityKind {
            case .event:
                if let decoded = try? item.decodedEvent() {
                    eventsById[decoded.id] = decoded
                }
            case .profile:
                if let decoded = try? item.decodedProfile() {
                    profilesById[decoded.id] = decoded
                }
            }
        }

        let request = SyncPushRequest(
            events: Array(eventsById.values),
            profiles: profilesById.isEmpty ? nil : Array(profilesById.values)
        )

        do {
            let response = try await performAuthorized { token in
                try await apiClient.syncPush(request, accessToken: token)
            }
            let acceptedEvents = Set(response.acceptedEventIds)
            let acceptedProfiles = Set(response.acceptedProfileIds)

            outbox.removeAll { item in
                switch item.entityKind {
                case .event: return acceptedEvents.contains(item.entityId)
                case .profile: return acceptedProfiles.contains(item.entityId)
                }
            }
            serverWatermark = response.serverWatermark
            lastSyncError = nil
            syncStatus = outbox.isEmpty
                ? .synced(response.serverWatermark)
                : .offline(pendingCount: outbox.count)
            persistState()
        } catch BackendAPIError.unauthorized {
            lastSyncError = "Session expired. Sign in again."
            persistState()
        } catch {
            for idx in outbox.indices {
                outbox[idx].retryCount += 1
            }
            lastSyncError = error.localizedDescription
            syncStatus = .offline(pendingCount: outbox.count)
            persistState()
        }
    }

    public func pullFromServer() async {
        guard let apiClient,
              !isDemoPreview,
              sessionStage == .ready,
              (accessToken != nil || refreshToken != nil)
        else { return }
        syncStatus = .syncing

        do {
            var pagesFetched = 0
            let maxPages = 50

            while pagesFetched < maxPages {
                let cursor = serverWatermark
                let response = try await performAuthorized { token in
                    try await apiClient.syncPull(since: cursor, limit: 500, accessToken: token)
                }
                pagesFetched += 1

                mergeRemoteEvents(response.events)
                if let updatedProfile = response.profiles.first(where: { $0.id == self.profile.id }),
                   updatedProfile.updatedAt >= profile.updatedAt
                {
                    profile = updatedProfile
                }

                let previousWatermark = serverWatermark
                serverWatermark = response.serverWatermark

                if !response.hasMore {
                    break
                }
                if response.events.isEmpty && response.profiles.isEmpty && previousWatermark == response.serverWatermark {
                    break
                }
            }

            reconcileActiveNapFromEvents()
            lastSyncError = nil
            let effectiveWatermark = serverWatermark ?? now
            syncStatus = outbox.isEmpty ? .synced(effectiveWatermark) : .offline(pendingCount: outbox.count)
            persistState()
        } catch BackendAPIError.unauthorized {
            lastSyncError = "Session expired. Sign in again."
        } catch {
            lastSyncError = error.localizedDescription
            syncStatus = .error(error.localizedDescription)
        }
    }

    public func startRealtimeSync() {
        stopRealtimeSync()
        guard let apiClient,
              isSignedInWithApple,
              !isDemoPreview,
              sessionStage == .ready,
              (accessToken != nil || refreshToken != nil)
        else { return }

        let backoffScheduleSeconds: [UInt64] = [2, 5, 15, 30]
        sseTask = Task { [weak self] in
            var attempt = 0
            while !Task.isCancelled {
                guard let self,
                      self.isSignedInWithApple,
                      !self.isDemoPreview,
                      self.sessionStage == .ready
                else { break }

                let token: String
                if let current = self.accessToken, !current.isEmpty {
                    token = current
                } else {
                    do {
                        token = try await self.refreshAccessTokenIfPossible()
                    } catch {
                        break
                    }
                }

                let stream = apiClient.syncStream(accessToken: token)
                var receivedFrame = false
                do {
                    for try await _ in stream {
                        if Task.isCancelled { break }
                        receivedFrame = true
                        attempt = 0
                        await self.pullFromServer()
                    }
                } catch BackendAPIError.unauthorized {
                    if Task.isCancelled { break }
                    do {
                        _ = try await self.refreshAccessTokenIfPossible()
                        attempt = 0
                        continue
                    } catch {
                        break
                    }
                } catch is CancellationError {
                    break
                } catch {
                    // Transient stream disconnect: reconnect using exponential backoff below.
                }

                if Task.isCancelled || !self.isSignedInWithApple || self.isDemoPreview || self.sessionStage != .ready {
                    break
                }
                if receivedFrame {
                    attempt = 0
                }
                let delaySeconds = backoffScheduleSeconds[min(attempt, backoffScheduleSeconds.count - 1)]
                attempt += 1
                try? await Task.sleep(nanoseconds: delaySeconds * 1_000_000_000)
            }
        }
    }

    public func stopRealtimeSync() {
        sseTask?.cancel()
        sseTask = nil
    }

    // MARK: - Internal Auth & Session Helpers

    private func refreshAccessTokenIfPossible() async throws -> String {
        if let existingTask = inFlightRefreshTask {
            return try await existingTask.value
        }

        guard let apiClient, let currentRefresh = refreshToken, !currentRefresh.isEmpty else {
            handleExpiredSession()
            throw BackendAPIError.unauthorized
        }

        let deviceId = tokenStore.loadOrCreateDeviceId()
        let task = Task<String, Error> { @MainActor [weak self] in
            let session = try await apiClient.refreshSession(
                RefreshTokenRequest(refreshToken: currentRefresh, deviceId: deviceId)
            )
            guard let self else { return session.accessToken }
            self.saveSessionTokens(session, deviceId: deviceId)
            self.currentUserId = session.user.id
            if let serverEmail = self.trimmedNonEmpty(session.user.primaryEmail) {
                self.authEmail = serverEmail
            }
            if let serverName = self.trimmedNonEmpty(session.user.displayName) {
                self.displayName = serverName
            }
            if self.hasCompletedHouseholdSetup {
                if let matchingHousehold = session.households.first(where: { $0.id == self.household.id }) {
                    self.household = matchingHousehold
                } else if let firstHousehold = session.households.first {
                    self.household = firstHousehold
                }
            }
            self.isSignedInWithApple = true
            self.lastSyncError = nil
            self.persistState()
            return session.accessToken
        }

        inFlightRefreshTask = task
        do {
            let newAccessToken = try await task.value
            inFlightRefreshTask = nil
            return newAccessToken
        } catch {
            inFlightRefreshTask = nil
            if let apiError = error as? BackendAPIError, apiError == .unauthorized {
                handleExpiredSession()
            }
            throw error
        }
    }

    private func saveSessionTokens(_ session: AuthSessionResponse, deviceId: String) {
        let expiresAt = Date().addingTimeInterval(TimeInterval(session.expiresIn))
        let stored = StoredAuthTokens(
            accessToken: session.accessToken,
            refreshToken: session.refreshToken,
            expiresAt: expiresAt,
            deviceId: deviceId
        )
        try? tokenStore.save(stored)
        accessToken = session.accessToken
        refreshToken = session.refreshToken
    }

    private func handleExpiredSession() {
        stopRealtimeSync()
        try? tokenStore.clear()
        accessToken = nil
        refreshToken = nil
        isSignedInWithApple = false
        isDemoPreview = false
        sessionStage = .signedOut
        let message = "Session expired. Sign in again."
        lastSyncError = message
        syncStatus = .error(message)
        persistState()
    }

    // MARK: - Internal Helpers

    private func shouldClassifySleepAsNight(asOf referenceDate: Date) -> Bool {
        completedNapsToday.count >= profile.scheduleConfig.wakeWindowsMinutes.count
            && WakeWindowCalculator.predictNextNap(
                asOf: referenceDate,
                wakeUpTime: todayEvents.compactMap { $0.eventType == .sleep ? $0.endedAt : nil }.max(),
                completedNapsToday: completedNapsToday,
                config: profile.scheduleConfig,
                calendar: profileCalendar
            ) == nil
    }

    private func latestOpenSleepEvent() -> EventDTO? {
        activeEvents
            .filter { $0.profileId == profile.id && $0.eventType == .sleep && $0.endedAt == nil }
            .max { lhs, rhs in
                if lhs.startedAt != rhs.startedAt { return lhs.startedAt < rhs.startedAt }
                return lhs.updatedAt < rhs.updatedAt
            }
    }

    private func latestOpenSleepEventIndex() -> Int? {
        guard let target = latestOpenSleepEvent() else { return nil }
        return events.firstIndex(where: { $0.id == target.id })
    }

    private func reconcileActiveNapFromEvents() {
        if let openSleep = latestOpenSleepEvent() {
            activeNapStart = openSleep.startedAt
        } else {
            activeNapStart = nil
        }
    }

    private func makeEvent(
        type: EventType,
        startedAt: Date,
        endedAt: Date? = nil,
        notes: String? = nil,
        metadata: EventMetadata,
        source: EventSource = .manual,
        scanId: UUID? = nil,
        externalId: String? = nil
    ) -> EventDTO {
        EventDTO(
            id: UUID(),
            profileId: profile.id,
            eventType: type,
            startedAt: startedAt,
            endedAt: endedAt,
            timezone: profile.defaultTimezone,
            notes: notes,
            metadata: metadata,
            source: source,
            scanId: scanId,
            externalId: externalId,
            createdBy: currentUserId,
            updatedBy: currentUserId,
            createdAt: now,
            updatedAt: now,
            deletedAt: nil
        )
    }

    private func commitNewEvents(_ newEvents: [EventDTO], toastMessage: String) {
        appendEvents(newEvents)
        let ids = Set(newEvents.map(\.id))
        showToast(toastMessage) { [weak self] in
            self?.removeNewlyCreatedEvents(ids: ids)
        }
    }

    private func appendEvents(_ newEvents: [EventDTO]) {
        events.append(contentsOf: newEvents)
        for event in newEvents {
            enqueueEventOutbox(event, operation: .upsert)
        }
        persistState()
        triggerBackgroundFlush()
    }

    private func removeNewlyCreatedEvents(ids: Set<UUID>) {
        events.removeAll { ids.contains($0.id) }
        outbox.removeAll { $0.entityKind == .event && ids.contains($0.entityId) }
        persistState()
    }

    private func mergeRemoteEvents(_ remoteEvents: [EventDTO]) {
        for remote in remoteEvents {
            guard remote.profileId == profile.id else { continue }
            if let idx = events.firstIndex(where: { $0.id == remote.id }) {
                if remote.updatedAt >= events[idx].updatedAt {
                    events[idx] = remote
                }
            } else {
                events.append(remote)
            }
        }
    }

    private func enqueueEventOutbox(_ event: EventDTO, operation: SyncOutboxOperation) {
        if let item = try? SyncOutboxItem.event(event, operation: operation, createdAt: now) {
            if let existingIdx = outbox.firstIndex(where: { $0.entityKind == .event && $0.entityId == event.id }) {
                outbox[existingIdx] = item
            } else {
                outbox.append(item)
            }
        }
    }

    private func enqueueProfileOutbox(_ profile: ProfileDTO) {
        if let item = try? SyncOutboxItem.profile(profile, operation: .upsert, createdAt: now) {
            if let existingIdx = outbox.firstIndex(where: { $0.entityKind == .profile && $0.entityId == profile.id }) {
                outbox[existingIdx] = item
            } else {
                outbox.append(item)
            }
        }
    }

    private func persistState() {
        // Never overwrite real on-disk state while previewing sample data in a live-configured app.
        if isDemoPreview && apiClient != nil {
            return
        }
        let snapshot = PersistedAppState(
            profile: profile,
            household: household,
            currentUserId: currentUserId,
            events: events,
            activeNapStart: activeNapStart,
            activeNursingSession: activeNursing,
            pendingScans: scannedSheets,
            outbox: outbox,
            serverWatermark: serverWatermark,
            preferredUnit: preferredUnit,
            colorMode: colorModePreference,
            authEmail: authEmail,
            displayName: displayName,
            isSignedInWithApple: isSignedInWithApple,
            hasCompletedHouseholdSetup: hasCompletedHouseholdSetup,
            isDemoPreview: isDemoPreview
        )
        do {
            try storage.save(snapshot)
            lastPersistError = nil
        } catch {
            lastPersistError = error.localizedDescription
        }
    }

    private func triggerBackgroundFlush() {
        guard apiClient != nil,
              !isDemoPreview,
              sessionStage == .ready,
              (accessToken != nil || refreshToken != nil)
        else { return }
        Task { [weak self] in
            await self?.flushOutbox()
        }
    }

    private func showToast(_ message: String, undo: (@MainActor () -> Void)?) {
        toastDismissTask?.cancel()
        undoAction = undo
        let newToast = ToastState(message: message, canUndo: undo != nil)
        toast = newToast
        let toastId = newToast.id
        toastDismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_500_000_000)
            guard !Task.isCancelled, let self, self.toast?.id == toastId else { return }
            self.toast = nil
            self.undoAction = nil
        }
    }

    private func trimmedNonEmpty(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func currentDeviceName() -> String {
        #if os(iOS) && canImport(UIKit)
        let name = UIDevice.current.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "iPhone" : name
        #else
        let host = ProcessInfo.processInfo.hostName.trimmingCharacters(in: .whitespacesAndNewlines)
        return host.isEmpty ? "Apple Device" : host
        #endif
    }

    private static func formatCalendarDateISO(_ date: Date, timeZone: TimeZone) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let year = comps.year ?? 2026
        let month = comps.month ?? 1
        let day = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private static func selectPreferredHousehold(
        from households: [HouseholdDTO],
        profiles: [ProfileDTO]
    ) -> HouseholdDTO? {
        guard !households.isEmpty else { return nil }
        let activeProfileHouseholdIds = Set(profiles.filter { $0.deletedAt == nil }.map(\.householdId))

        var best = households[0]
        var bestMembers = best.members?.count ?? 0
        var bestHasProfile = activeProfileHouseholdIds.contains(best.id)

        for candidate in households.dropFirst() {
            let candidateMembers = candidate.members?.count ?? 0
            let candidateHasProfile = activeProfileHouseholdIds.contains(candidate.id)

            if candidateMembers > bestMembers
                || (candidateMembers == bestMembers && candidateHasProfile && !bestHasProfile)
            {
                best = candidate
                bestMembers = candidateMembers
                bestHasProfile = candidateHasProfile
            }
        }
        return best
    }

    private static func buildScanSubtitle(from drafts: [ScanReviewDraftItem]) -> String {
        let newCount = drafts.filter { $0.matchAction == .create && !$0.isSuggestion }.count
        let updateCount = drafts.filter { $0.matchAction == .updateExisting }.count
        let suggestedCount = drafts.filter(\.isSuggestion).count
        let duplicateCount = drafts.filter { $0.matchAction == .skipDuplicate }.count

        var parts: [String] = []
        if newCount > 0 { parts.append("\(newCount) new") }
        if updateCount > 0 { parts.append("\(updateCount) updated") }
        if suggestedCount > 0 { parts.append("\(suggestedCount) suggested") }
        if duplicateCount > 0 { parts.append("\(duplicateCount) already logged") }
        return parts.isEmpty ? "No new entries found" : parts.joined(separator: " · ")
    }
}
