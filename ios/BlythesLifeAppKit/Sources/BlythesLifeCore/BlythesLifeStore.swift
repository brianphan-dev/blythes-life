import BlythesLifeShared
import Foundation
import Observation

// MARK: - View Models & Supporting State

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
    public var isSignedInWithApple: Bool
    public var authEmail: String?
    public var displayName: String?
    public private(set) var outbox: [SyncOutboxItem]
    public private(set) var serverWatermark: Date?

    public var outboxCount: Int { outbox.count }

    @ObservationIgnored private let storage: any LocalStateStorage
    @ObservationIgnored private let apiClient: (any BackendAPIProviding)?
    @ObservationIgnored private var accessToken: String?
    @ObservationIgnored private var undoAction: (@MainActor () -> Void)?
    @ObservationIgnored private var clockTask: Task<Void, Never>?
    @ObservationIgnored private var toastDismissTask: Task<Void, Never>?
    @ObservationIgnored private var sseTask: Task<Void, Never>?
    @ObservationIgnored private var lastPersistError: String?

    public init(
        storage: any LocalStateStorage = FileLocalStateStorage(),
        apiClient: (any BackendAPIProviding)? = nil,
        accessToken: String? = nil,
        seedReferenceDate: Date = SampleSeedData.defaultReferenceDate,
        initialNow: Date? = nil,
        autoStartClock: Bool = false
    ) {
        self.storage = storage
        self.apiClient = apiClient
        self.accessToken = accessToken

        let loadedState: PersistedAppState
        if let existing = try? storage.load() {
            loadedState = existing
        } else {
            let demo = SampleSeedData.makeDemoState(referenceDate: seedReferenceDate)
            loadedState = demo
            try? storage.save(demo)
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
        self.isSignedInWithApple = loadedState.isSignedInWithApple
        self.postureOverride = .automatic
        self.now = initialNow ?? seedReferenceDate
        self.toast = nil

        if apiClient != nil && accessToken != nil {
            if let watermark = loadedState.serverWatermark {
                self.syncStatus = .synced(watermark)
            } else if !loadedState.outbox.isEmpty {
                self.syncStatus = .offline(pendingCount: loadedState.outbox.count)
            } else {
                self.syncStatus = .localOnly
            }
        } else {
            self.syncStatus = .localOnly
        }

        if autoStartClock {
            startClock()
        }
    }

    /// Creates an in-memory store seeded with realistic demo state for SwiftUI Previews and tests.
    public static func makeDemo(
        referenceDate: Date = SampleSeedData.defaultReferenceDate,
        apiClient: (any BackendAPIProviding)? = nil,
        accessToken: String? = nil
    ) -> BlythesLifeStore {
        let seed = SampleSeedData.makeDemoState(referenceDate: referenceDate)
        let memory = InMemoryLocalStateStorage(initialState: seed)
        return BlythesLifeStore(
            storage: memory,
            apiClient: apiClient,
            accessToken: accessToken,
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

    /// Non-deleted events belonging to today's local calendar day, sorted newest first.
    public var todayEvents: [EventDTO] {
        let calendar = profileCalendar
        return activeEvents
            .filter { event in
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
                    let effectiveEnd = event.endedAt ?? (isToday ? max(now, event.startedAt) : event.startedAt)
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
                            isNap: true
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

    // MARK: - Sleep & Nap Actions

    @discardableResult
    public func toggleNap() -> EventDTO? {
        guard let napStart = activeNapStart else {
            activeNapStart = now
            persistState()
            showToast("Nap timer started on every device") { [weak self] in
                guard let self else { return }
                self.activeNapStart = nil
                self.persistState()
            }
            return nil
        }

        let end = max(now, napStart)
        let isNight = completedNapsToday.count >= profile.scheduleConfig.wakeWindowsMinutes.count
            && WakeWindowCalculator.predictNextNap(
                asOf: napStart,
                wakeUpTime: todayEvents.compactMap { $0.eventType == .sleep ? $0.endedAt : nil }.max(),
                completedNapsToday: completedNapsToday,
                config: profile.scheduleConfig,
                calendar: profileCalendar
            ) == nil

        let napNumber = completedNapsToday.count + 1
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
        persistState()
        let clock = FormattingHelpers.formatClock(newStart, timeZone: profileTimeZone)
        showToast("Nap start set to \(clock)") { [weak self] in
            guard let self else { return }
            self.activeNapStart = previous
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
            // Pause currently running side
            activeNursing = ActiveNursingSession(
                startedAt: session.startedAt,
                leftAccumulatedSeconds: elapsed.left,
                rightAccumulatedSeconds: elapsed.right,
                activeSide: nil,
                activeSegmentStartedAt: nil
            )
        } else {
            // Switch to or resume the tapped side
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

    // MARK: - Paper Scan Review & Confirm

    public func addScannedSheet(_ sheet: ScannedSheetRecord) {
        scannedSheets.insert(sheet, at: 0)
        persistState()
    }

    @discardableResult
    public func confirmScanReview(sheetId: UUID, drafts: [ScanReviewDraftItem]) -> [EventDTO] {
        let included = drafts.filter(\.isIncluded)
        guard !included.isEmpty, included.allSatisfy({ !$0.hasUnresolvedAmbiguity }) else {
            return []
        }

        let createdEvents: [EventDTO] = included.map { draft in
            let effectiveStart = draft.effectiveStartedAt
            let adjustedEnd: Date? = {
                guard let endedAt = draft.endedAt else { return nil }
                if effectiveStart != draft.startedAt {
                    let duration = max(0, endedAt.timeIntervalSince(draft.startedAt))
                    return effectiveStart.addingTimeInterval(duration)
                }
                return endedAt
            }()

            return makeEvent(
                type: draft.eventType,
                startedAt: effectiveStart,
                endedAt: adjustedEnd,
                notes: draft.notes,
                metadata: draft.metadata,
                source: .paperScan,
                scanId: sheetId
            )
        }

        let sheetIndex = scannedSheets.firstIndex(where: { $0.id == sheetId })
        let previousSheet = sheetIndex.map { scannedSheets[$0] }
        if let sheetIndex {
            scannedSheets[sheetIndex].status = .confirmed
            scannedSheets[sheetIndex].drafts = drafts
            scannedSheets[sheetIndex].confirmedEntryCount = createdEvents.count
            scannedSheets[sheetIndex].subtitle = "Entries saved"
        }

        appendEvents(createdEvents)
        let createdIds = Set(createdEvents.map(\.id))
        let count = createdEvents.count
        let noun = count == 1 ? "entry" : "entries"
        showToast("\(count) \(noun) saved from Grandma's sheet") { [weak self] in
            guard let self else { return }
            self.removeNewlyCreatedEvents(ids: createdIds)
            if let sheetIndex, let previousSheet, sheetIndex < self.scannedSheets.count {
                self.scannedSheets[sheetIndex] = previousSheet
            }
            self.persistState()
        }
        return createdEvents
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
        accessToken = nil
        isSignedInWithApple = false
        syncStatus = .localOnly
        persistState()
        showToast("Signed out on this device", undo: nil)
    }

    public func signInWithAppleSession(_ session: AuthSessionResponse) {
        accessToken = session.accessToken
        isSignedInWithApple = true
        authEmail = session.user.primaryEmail
        displayName = session.user.displayName
        currentUserId = session.user.id
        if let firstHousehold = session.households.first {
            household = firstHousehold
        }
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
            triggerBackgroundFlush()
        } else {
            syncStatus = .localOnly
        }
    }

    public func flushOutbox() async {
        guard let apiClient, let accessToken else { return }
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
            let response = try await apiClient.syncPush(request, accessToken: accessToken)
            let acceptedEvents = Set(response.acceptedEventIds)
            let acceptedProfiles = Set(response.acceptedProfileIds)

            outbox.removeAll { item in
                switch item.entityKind {
                case .event: return acceptedEvents.contains(item.entityId)
                case .profile: return acceptedProfiles.contains(item.entityId)
                }
            }
            serverWatermark = response.serverWatermark
            syncStatus = outbox.isEmpty
                ? .synced(response.serverWatermark)
                : .offline(pendingCount: outbox.count)
            persistState()
        } catch {
            for idx in outbox.indices {
                outbox[idx].retryCount += 1
            }
            syncStatus = .offline(pendingCount: outbox.count)
            persistState()
        }
    }

    public func pullFromServer() async {
        guard let apiClient, let accessToken else { return }
        syncStatus = .syncing
        do {
            let response = try await apiClient.syncPull(since: serverWatermark, limit: 500, accessToken: accessToken)
            mergeRemoteEvents(response.events)
            if let updatedProfile = response.profiles.first(where: { $0.id == profile.id }),
               updatedProfile.updatedAt > profile.updatedAt
            {
                profile = updatedProfile
            }
            serverWatermark = response.serverWatermark
            syncStatus = outbox.isEmpty ? .synced(response.serverWatermark) : .offline(pendingCount: outbox.count)
            persistState()
        } catch {
            syncStatus = .error(error.localizedDescription)
        }
    }

    public func startRealtimeSync() {
        stopRealtimeSync()
        guard let apiClient, let accessToken else { return }
        sseTask = Task { [weak self] in
            let stream = apiClient.syncStream(accessToken: accessToken)
            do {
                for try await _ in stream {
                    if Task.isCancelled { break }
                    await self?.pullFromServer()
                }
            } catch {
                // Reconnect handled by caller / foreground resume.
            }
        }
    }

    public func stopRealtimeSync() {
        sseTask?.cancel()
        sseTask = nil
    }

    // MARK: - Internal Helpers

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
            outbox.append(item)
        }
    }

    private func enqueueProfileOutbox(_ profile: ProfileDTO) {
        if let item = try? SyncOutboxItem.profile(profile, operation: .upsert, createdAt: now) {
            outbox.append(item)
        }
    }

    private func persistState() {
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
            isSignedInWithApple: isSignedInWithApple
        )
        do {
            try storage.save(snapshot)
            lastPersistError = nil
        } catch {
            lastPersistError = error.localizedDescription
        }
    }

    private func triggerBackgroundFlush() {
        guard apiClient != nil, accessToken != nil else { return }
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
}
