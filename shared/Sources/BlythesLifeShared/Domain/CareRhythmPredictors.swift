import Foundation

// MARK: - Meal Slot Classification (Engine A2)

public enum MealSlotClassifier: Sendable {
    /// Classifies minutes from midnight into a canonical `MealSlot`:
    /// - `< 630` (`< 10:30 AM`): `.breakfast`
    /// - `630..<870` (`10:30 AM – 2:29 PM`): `.lunch`
    /// - `870..<990` (`2:30 PM – 4:29 PM`): `.snack`
    /// - `>= 990` (`4:30 PM` onward): `.dinner`
    public static func classify(minutesFromMidnight: Int) -> MealSlot {
        let normalized = ((minutesFromMidnight % 1440) + 1440) % 1440
        switch normalized {
        case ..<630:
            return .breakfast
        case 630..<870:
            return .lunch
        case 870..<990:
            return .snack
        default:
            return .dinner
        }
    }

    /// Classifies `date` into a canonical `MealSlot` using its wall-clock `hour * 60 + minute` in `calendar`,
    /// an optional late-wake Breakfast anchor (`<= morningWakeAt + 2h30m` and `< 11:15 AM`),
    /// and a duplicate-lunch guard (`630..<870` when `.lunch` is already logged today -> `.snack`).
    public static func classify(
        date: Date,
        morningWakeAt: Date? = nil,
        existingMealsToday: [EventDTO] = [],
        calendar: Calendar = .current
    ) -> MealSlot {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let mins = (components.hour ?? 0) * 60 + (components.minute ?? 0)

        var existingSlots: Set<MealSlot> = []
        for event in existingMealsToday {
            guard event.deletedAt == nil,
                  event.eventType == .meal,
                  calendar.isDate(event.startedAt, inSameDayAs: date)
            else {
                continue
            }
            let explicitSlot: MealSlot?
            if case .meal(let meta) = event.metadata {
                explicitSlot = meta.mealSlot
            } else {
                explicitSlot = nil
            }
            let eventComponents = calendar.dateComponents([.hour, .minute], from: event.startedAt)
            let eventMins = (eventComponents.hour ?? 0) * 60 + (eventComponents.minute ?? 0)
            existingSlots.insert(explicitSlot ?? classify(minutesFromMidnight: eventMins))
        }

        // Late-wake Breakfast anchor: within 2h30m of morning wake, before 11:15 AM, if no Breakfast logged yet.
        if let wake = morningWakeAt,
           calendar.isDate(wake, inSameDayAs: date),
           date >= wake,
           date <= wake.addingTimeInterval(150 * 60),
           mins < 675,
           !existingSlots.contains(.breakfast)
        {
            return .breakfast
        }

        switch mins {
        case ..<630:
            return .breakfast
        case 630..<870:
            return existingSlots.contains(.lunch) ? .snack : .lunch
        case 870..<990:
            return .snack
        default:
            return .dinner
        }
    }
}

// MARK: - Next Feed Prediction (Engine B2)

public struct NextFeedPrediction: Codable, Sendable, Equatable, Hashable {
    public var recommendedStart: Date
    public var windowStart: Date
    public var windowEnd: Date
    public var intervalMinutes: Int
    public var lastFeedAt: Date?
    public var isBedtimeFeed: Bool
    public var isLightFeedNote: Bool
    public var reason: String

    public init(
        recommendedStart: Date,
        windowStart: Date,
        windowEnd: Date,
        intervalMinutes: Int,
        lastFeedAt: Date? = nil,
        isBedtimeFeed: Bool = false,
        isLightFeedNote: Bool = false,
        reason: String
    ) {
        self.recommendedStart = recommendedStart
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.intervalMinutes = intervalMinutes
        self.lastFeedAt = lastFeedAt
        self.isBedtimeFeed = isBedtimeFeed
        self.isLightFeedNote = isLightFeedNote
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case recommendedStart = "recommended_start"
        case windowStart = "window_start"
        case windowEnd = "window_end"
        case intervalMinutes = "interval_minutes"
        case lastFeedAt = "last_feed_at"
        case isBedtimeFeed = "is_bedtime_feed"
        case isLightFeedNote = "is_light_feed_note"
        case reason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.recommendedStart = try container.decode(Date.self, forKey: .recommendedStart)
        self.windowStart = try container.decode(Date.self, forKey: .windowStart)
        self.windowEnd = try container.decode(Date.self, forKey: .windowEnd)
        self.intervalMinutes = try container.decode(Int.self, forKey: .intervalMinutes)
        self.lastFeedAt = try container.decodeIfPresent(Date.self, forKey: .lastFeedAt)
        self.isBedtimeFeed = try container.decodeIfPresent(Bool.self, forKey: .isBedtimeFeed) ?? false
        self.isLightFeedNote = try container.decodeIfPresent(Bool.self, forKey: .isLightFeedNote) ?? false
        self.reason = try container.decode(String.self, forKey: .reason)
    }
}

public enum FeedPredictor: Sendable {
    /// Half-width in minutes around `recommendedStart` forming `[windowStart, windowEnd]`.
    public static let sweetSpotHalfWidthMinutes: Int = 15

    /// Predicts the next daytime bottle/nursing feed ("Mini SweetSpot") anchored around
    /// `config.targetBedtimeMinutesFromMidnight`, including bedtime-feed capping and light-feed notes.
    public static func predictNextFeed(
        asOf: Date,
        wakeUpTime: Date?,
        eventsToday: [EventDTO],
        isNightSleepActive: Bool = false,
        config: ScheduleConfig,
        calendar: Calendar = .current
    ) -> NextFeedPrediction? {
        guard !isNightSleepActive, config.feedingIntervalMinutes > 0 else {
            return nil
        }

        let targetBedtimeDate = CareRhythmHelpers.makeTimeOfDay(
            onDayOf: asOf,
            minutesFromMidnight: config.targetBedtimeMinutesFromMidnight,
            calendar: calendar
        )
        let bedtimeFeedCap = targetBedtimeDate.addingTimeInterval(-30 * 60)
        let bedtimeDoneAfter = targetBedtimeDate.addingTimeInterval(-45 * 60)
        let lateEveningCutoff = targetBedtimeDate.addingTimeInterval(60 * 60)

        if asOf > lateEveningCutoff {
            return nil
        }

        if let latestFeed = CareRhythmHelpers.latestFeedToday(
            asOf: asOf,
            eventsToday: eventsToday,
            calendar: calendar
        ) {
            if latestFeed.anchor >= bedtimeDoneAfter {
                return nil
            }

            let isLightFeedNote = CareRhythmHelpers.isLightFeed(
                latestFeed.event,
                asOf: asOf,
                eventsToday: eventsToday,
                calendar: calendar
            )

            let rawNext = latestFeed.anchor.addingTimeInterval(TimeInterval(config.feedingIntervalMinutes * 60))
            let recommendedStart: Date
            let isBedtimeFeed: Bool
            let reason: String

            if rawNext > bedtimeFeedCap {
                recommendedStart = bedtimeFeedCap
                isBedtimeFeed = true
                let clockText = CareRhythmHelpers.formatClock(
                    minutesFromMidnight: config.targetBedtimeMinutesFromMidnight
                )
                reason = "Bedtime feed before \(clockText)"
            } else {
                recommendedStart = rawNext
                isBedtimeFeed = false
                reason = "Every \(CareRhythmHelpers.formatDuration(config.feedingIntervalMinutes)) after last feed"
            }

            let windowStart = recommendedStart.addingTimeInterval(TimeInterval(-sweetSpotHalfWidthMinutes * 60))
            let windowEnd = recommendedStart.addingTimeInterval(TimeInterval(sweetSpotHalfWidthMinutes * 60))

            return NextFeedPrediction(
                recommendedStart: recommendedStart,
                windowStart: windowStart,
                windowEnd: windowEnd,
                intervalMinutes: config.feedingIntervalMinutes,
                lastFeedAt: latestFeed.anchor,
                isBedtimeFeed: isBedtimeFeed,
                isLightFeedNote: isLightFeedNote,
                reason: reason
            )
        }

        guard let wakeUpTime, asOf <= lateEveningCutoff else {
            return nil
        }

        let firstFeedDelayMinutes = 30
        let rawFirst = wakeUpTime.addingTimeInterval(TimeInterval(firstFeedDelayMinutes * 60))
        guard rawFirst <= bedtimeFeedCap else {
            return nil
        }

        let windowStart = rawFirst.addingTimeInterval(TimeInterval(-sweetSpotHalfWidthMinutes * 60))
        let windowEnd = rawFirst.addingTimeInterval(TimeInterval(sweetSpotHalfWidthMinutes * 60))

        return NextFeedPrediction(
            recommendedStart: rawFirst,
            windowStart: windowStart,
            windowEnd: windowEnd,
            intervalMinutes: firstFeedDelayMinutes,
            lastFeedAt: nil,
            isBedtimeFeed: false,
            isLightFeedNote: false,
            reason: "First feed after morning wake"
        )
    }
}

// MARK: - Next Meal Prediction (Engine B3)

public struct NextMealPrediction: Codable, Sendable, Equatable, Hashable {
    public var slot: MealSlot
    public var recommendedStart: Date
    public var windowStart: Date
    public var windowEnd: Date
    public var isSpacedAfterFeed: Bool
    public var isWaitingForNap: Bool
    public var reason: String

    public init(
        slot: MealSlot,
        recommendedStart: Date,
        windowStart: Date,
        windowEnd: Date,
        isSpacedAfterFeed: Bool,
        isWaitingForNap: Bool = false,
        reason: String
    ) {
        self.slot = slot
        self.recommendedStart = recommendedStart
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.isSpacedAfterFeed = isSpacedAfterFeed
        self.isWaitingForNap = isWaitingForNap
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case slot
        case recommendedStart = "recommended_start"
        case windowStart = "window_start"
        case windowEnd = "window_end"
        case isSpacedAfterFeed = "is_spaced_after_feed"
        case isWaitingForNap = "is_waiting_for_nap"
        case reason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.slot = try container.decode(MealSlot.self, forKey: .slot)
        self.recommendedStart = try container.decode(Date.self, forKey: .recommendedStart)
        self.windowStart = try container.decode(Date.self, forKey: .windowStart)
        self.windowEnd = try container.decode(Date.self, forKey: .windowEnd)
        self.isSpacedAfterFeed = try container.decode(Bool.self, forKey: .isSpacedAfterFeed)
        self.isWaitingForNap = try container.decodeIfPresent(Bool.self, forKey: .isWaitingForNap) ?? false
        self.reason = try container.decode(String.self, forKey: .reason)
    }
}

public enum MealPredictor: Sendable {
    /// Half-width in minutes around `recommendedStart` forming `[windowStart, windowEnd]`.
    public static let sweetSpotHalfWidthMinutes: Int = 20

    /// Grace period in minutes past a non-final meal target before advancing to the next planned meal slot.
    public static let missedSlotGraceMinutes: Int = 90

    /// Predicts the next solid meal window ("Mini SweetSpot") using time-classified meal slots,
    /// missed-slot grace progression, gentle feed-to-meal spacing, active-nap waiting state,
    /// and target bedtime suppression.
    public static func predictNextMeal(
        asOf: Date,
        eventsToday: [EventDTO],
        isNightSleepActive: Bool = false,
        isNapActive: Bool = false,
        config: ScheduleConfig,
        calendar: Calendar = .current
    ) -> NextMealPrediction? {
        guard !isNightSleepActive, !config.mealTargetMinutesFromMidnight.isEmpty else {
            return nil
        }

        // Build chronologically sorted target slots with unique MealSlot entries on `asOf`'s calendar day.
        var seenSlots: Set<MealSlot> = []
        let plannedTargets: [(targetMinutes: Int, slot: MealSlot, targetDate: Date)] = config
            .mealTargetMinutesFromMidnight
            .map { ((($0 % 1440) + 1440) % 1440) }
            .sorted()
            .compactMap { targetMinutes in
                let slot = MealSlotClassifier.classify(minutesFromMidnight: targetMinutes)
                guard seenSlots.insert(slot).inserted else {
                    return nil
                }
                let targetDate = CareRhythmHelpers.makeTimeOfDay(
                    onDayOf: asOf,
                    minutesFromMidnight: targetMinutes,
                    calendar: calendar
                )
                return (targetMinutes, slot, targetDate)
            }

        guard let finalPlannedSlot = plannedTargets.last?.slot else {
            return nil
        }

        // Collect completed meal slots today from non-deleted `.meal` events.
        var completedSlots: Set<MealSlot> = []
        for event in eventsToday {
            guard event.deletedAt == nil,
                  event.eventType == .meal,
                  calendar.isDate(event.startedAt, inSameDayAs: asOf)
            else {
                continue
            }
            let explicitSlot: MealSlot?
            if case .meal(let meta) = event.metadata {
                explicitSlot = meta.mealSlot
            } else {
                explicitSlot = nil
            }
            let resolvedSlot = explicitSlot ?? MealSlotClassifier.classify(date: event.startedAt, calendar: calendar)
            completedSlots.insert(resolvedSlot)
        }

        let remainingTargets = plannedTargets.filter { !completedSlots.contains($0.slot) }
        guard !remainingTargets.isEmpty else {
            return nil
        }

        let bedtimeCutoffDate = CareRhythmHelpers.makeTimeOfDay(
            onDayOf: asOf,
            minutesFromMidnight: config.targetBedtimeMinutesFromMidnight,
            calendar: calendar
        )
        if asOf >= bedtimeCutoffDate {
            return nil
        }

        let lastFeedAnchor = CareRhythmHelpers.latestFeedToday(
            asOf: asOf,
            eventsToday: eventsToday,
            calendar: calendar
        )?.anchor

        let graceInterval = TimeInterval(missedSlotGraceMinutes * 60)
        var chosenTarget: (targetMinutes: Int, slot: MealSlot, targetDate: Date)?
        for target in remainingTargets {
            let isFinalPlannedTarget = (target.slot == finalPlannedSlot)
            if !isFinalPlannedTarget && asOf > target.targetDate.addingTimeInterval(graceInterval) {
                continue
            }
            chosenTarget = target
            break
        }

        guard let target = chosenTarget else {
            return nil
        }

        let recommendedStart: Date
        let isSpacedAfterFeed: Bool
        let minFeedSpacingSeconds = TimeInterval(config.minMinutesAfterFeedForMeal * 60)

        if let lastFeedAnchor,
           config.minMinutesAfterFeedForMeal > 0,
           lastFeedAnchor <= target.targetDate,
           target.targetDate.timeIntervalSince(lastFeedAnchor) < minFeedSpacingSeconds
        {
            recommendedStart = lastFeedAnchor.addingTimeInterval(minFeedSpacingSeconds)
            isSpacedAfterFeed = true
        } else {
            recommendedStart = target.targetDate
            isSpacedAfterFeed = false
        }

        if recommendedStart >= bedtimeCutoffDate {
            return nil
        }

        let windowStart = recommendedStart.addingTimeInterval(TimeInterval(-sweetSpotHalfWidthMinutes * 60))
        let windowEnd = recommendedStart.addingTimeInterval(TimeInterval(sweetSpotHalfWidthMinutes * 60))
        let slotLabel = CareRhythmHelpers.displayName(for: target.slot)

        let isWaitingForNap = isNapActive && asOf >= recommendedStart.addingTimeInterval(-20 * 60)

        let reason: String
        if isWaitingForNap {
            reason = "Waiting until after nap"
        } else if isSpacedAfterFeed {
            reason = "\(slotLabel) spaced \(config.minMinutesAfterFeedForMeal)m after last feed"
        } else {
            reason = "Scheduled \(slotLabel.lowercased()) window"
        }

        return NextMealPrediction(
            slot: target.slot,
            recommendedStart: recommendedStart,
            windowStart: windowStart,
            windowEnd: windowEnd,
            isSpacedAfterFeed: isSpacedAfterFeed,
            isWaitingForNap: isWaitingForNap,
            reason: reason
        )
    }
}

// MARK: - Internal Helpers

private enum CareRhythmHelpers {
    static func latestFeedToday(
        asOf: Date,
        eventsToday: [EventDTO],
        calendar: Calendar
    ) -> (event: EventDTO, anchor: Date)? {
        eventsToday
            .compactMap { event -> (event: EventDTO, anchor: Date)? in
                guard event.deletedAt == nil,
                      event.eventType == .feeding,
                      calendar.isDate(event.startedAt, inSameDayAs: asOf)
                else {
                    return nil
                }
                let anchor: Date
                if let endedAt = event.endedAt, endedAt >= event.startedAt {
                    anchor = endedAt
                } else {
                    anchor = event.startedAt
                }
                return (event, anchor)
            }
            .max { lhs, rhs in
                if lhs.anchor != rhs.anchor {
                    return lhs.anchor < rhs.anchor
                }
                return lhs.event.startedAt < rhs.event.startedAt
            }
    }

    static func isLightFeed(
        _ feedEvent: EventDTO,
        asOf: Date,
        eventsToday: [EventDTO],
        calendar: Calendar
    ) -> Bool {
        // If a solid meal occurred within ±45m of the feed, a smaller milk top-off is normal.
        let hasNearbySolidMeal = eventsToday.contains { event in
            guard event.deletedAt == nil,
                  event.eventType == .meal,
                  calendar.isDate(event.startedAt, inSameDayAs: asOf)
            else {
                return false
            }
            return abs(event.startedAt.timeIntervalSince(feedEvent.startedAt)) <= 45 * 60
        }

        if hasNearbySolidMeal {
            return false
        }

        guard case .feeding(let meta) = feedEvent.metadata else {
            return false
        }

        switch meta.method {
        case .bottle:
            if let amountMl = meta.amountMl, amountMl < 45.0 {
                return true
            }
            return false
        case .breast:
            let resolvedDurationMinutes: Double?
            if let durationMinutes = meta.durationMinutes {
                resolvedDurationMinutes = durationMinutes
            } else if meta.leftDurationSeconds != nil || meta.rightDurationSeconds != nil {
                let totalSeconds = (meta.leftDurationSeconds ?? 0) + (meta.rightDurationSeconds ?? 0)
                resolvedDurationMinutes = Double(totalSeconds) / 60.0
            } else if let endedAt = feedEvent.endedAt, endedAt >= feedEvent.startedAt {
                resolvedDurationMinutes = endedAt.timeIntervalSince(feedEvent.startedAt) / 60.0
            } else {
                resolvedDurationMinutes = nil
            }
            if let duration = resolvedDurationMinutes, duration < 3.0 {
                return true
            }
            return false
        }
    }

    static func makeTimeOfDay(
        onDayOf referenceDate: Date,
        minutesFromMidnight: Int,
        calendar: Calendar
    ) -> Date {
        let clampedMinutes = min(max(minutesFromMidnight, 0), 1439)
        var components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        components.timeZone = calendar.timeZone
        components.hour = clampedMinutes / 60
        components.minute = clampedMinutes % 60
        components.second = 0
        if let date = calendar.date(from: components) {
            return date
        }
        let startOfDay = calendar.startOfDay(for: referenceDate)
        return startOfDay.addingTimeInterval(TimeInterval(clampedMinutes * 60))
    }

    static func formatClock(minutesFromMidnight: Int) -> String {
        let normalized = ((minutesFromMidnight % 1440) + 1440) % 1440
        let hour24 = normalized / 60
        let minute = normalized % 60
        let meridiem = hour24 >= 12 ? "PM" : "AM"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        let minuteString = minute < 10 ? "0\(minute)" : "\(minute)"
        return "\(hour12):\(minuteString) \(meridiem)"
    }

    static func formatDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0 && remainder > 0 {
            return "\(hours)h \(remainder)m"
        } else if hours > 0 {
            return "\(hours)h"
        } else {
            return "\(remainder)m"
        }
    }

    static func displayName(for slot: MealSlot) -> String {
        switch slot {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .snack: "Snack"
        case .dinner: "Dinner"
        }
    }
}
