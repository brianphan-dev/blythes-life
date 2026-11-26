import Foundation

public struct NextNapPrediction: Codable, Sendable, Equatable, Hashable {
    public var recommendedStart: Date
    public var windowStart: Date
    public var windowEnd: Date
    public var wakeWindowMinutes: Int
    public var maxNapEnd: Date
    public var isBackupCatnap: Bool
    public var reason: String

    public init(
        recommendedStart: Date,
        windowStart: Date,
        windowEnd: Date,
        wakeWindowMinutes: Int,
        maxNapEnd: Date,
        isBackupCatnap: Bool,
        reason: String
    ) {
        self.recommendedStart = recommendedStart
        self.windowStart = windowStart
        self.windowEnd = windowEnd
        self.wakeWindowMinutes = wakeWindowMinutes
        self.maxNapEnd = maxNapEnd
        self.isBackupCatnap = isBackupCatnap
        self.reason = reason
    }

    enum CodingKeys: String, CodingKey {
        case recommendedStart = "recommended_start"
        case windowStart = "window_start"
        case windowEnd = "window_end"
        case wakeWindowMinutes = "wake_window_minutes"
        case maxNapEnd = "max_nap_end"
        case isBackupCatnap = "is_backup_catnap"
        case reason
    }
}

public enum WakeWindowCalculator: Sendable {
    /// Half-width in minutes around `recommendedStart` forming `[windowStart, windowEnd]`.
    public static let sweetSpotWindowHalfWidthMinutes: Int = 15

    /// Predicts the next nap window using asymmetric per-nap wake windows, short-nap reset (`< shortNapThresholdMinutes`),
    /// per-nap duration cap (`napCapMinutes`), and the backup catnap cutoff rule.
    public static func predictNextNap(
        asOf: Date,
        wakeUpTime: Date?,
        completedNapsToday: [EventDTO],
        config: ScheduleConfig,
        calendar: Calendar = .current
    ) -> NextNapPrediction? {
        guard !config.wakeWindowsMinutes.isEmpty else {
            return nil
        }

        // Filter to non-deleted completed daytime naps, sorted chronologically.
        let completedNaps = completedNapsToday
            .compactMap { event -> (startedAt: Date, endedAt: Date)? in
                guard event.deletedAt == nil,
                      event.eventType == .sleep,
                      case .sleep(let sleepMeta) = event.metadata,
                      sleepMeta.sleepType == .nap,
                      let endedAt = event.endedAt,
                      endedAt >= event.startedAt
                else {
                    return nil
                }
                return (event.startedAt, endedAt)
            }
            .sorted { $0.startedAt < $1.startedAt }

        let napCount = completedNaps.count

        // Already took all scheduled naps plus the backup catnap -> bedtime next.
        if napCount > config.wakeWindowsMinutes.count {
            return nil
        }

        let isBackupCatnap = (napCount == config.wakeWindowsMinutes.count)

        let anchorTime: Date
        let lastNapDurationMinutes: Int?
        if let lastNap = completedNaps.last {
            anchorTime = lastNap.endedAt
            lastNapDurationMinutes = Int((lastNap.endedAt.timeIntervalSince(lastNap.startedAt) / 60.0).rounded())
        } else if let wakeUpTime {
            anchorTime = wakeUpTime
            lastNapDurationMinutes = nil
        } else {
            return nil
        }

        let baseWakeWindowMinutes: Int
        if isBackupCatnap {
            baseWakeWindowMinutes = config.wakeWindowsMinutes.last ?? config.shortNapNextWindowMinutes
        } else {
            baseWakeWindowMinutes = config.wakeWindowsMinutes[napCount]
        }

        let isShortNapReset: Bool
        let effectiveWakeWindowMinutes: Int
        if let lastDuration = lastNapDurationMinutes, lastDuration < config.shortNapThresholdMinutes {
            isShortNapReset = true
            effectiveWakeWindowMinutes = config.shortNapNextWindowMinutes
        } else {
            isShortNapReset = false
            effectiveWakeWindowMinutes = baseWakeWindowMinutes
        }

        let recommendedStart = anchorTime.addingTimeInterval(TimeInterval(effectiveWakeWindowMinutes * 60))
        let windowStart = recommendedStart.addingTimeInterval(TimeInterval(-sweetSpotWindowHalfWidthMinutes * 60))
        let windowEnd = recommendedStart.addingTimeInterval(TimeInterval(sweetSpotWindowHalfWidthMinutes * 60))

        if isBackupCatnap {
            let cutoffDate = makeCutoffDate(
                onDayOf: anchorTime,
                minutesFromMidnight: config.backupCatnapCutoffMinutesFromMidnight,
                calendar: calendar
            )

            // Do not suggest a backup catnap if its start or current time is past the cutoff.
            if recommendedStart > cutoffDate || asOf > cutoffDate {
                return nil
            }

            let maxNapEnd = recommendedStart.addingTimeInterval(
                TimeInterval(config.backupCatnapDurationMinutes * 60)
            )

            let reason: String
            if isShortNapReset, let lastDuration = lastNapDurationMinutes {
                reason = "Backup catnap (capped at \(config.backupCatnapDurationMinutes)m): short nap (\(lastDuration)m < \(config.shortNapThresholdMinutes)m) reset wake window to \(formatDuration(effectiveWakeWindowMinutes))."
            } else {
                reason = "Backup catnap (capped at \(config.backupCatnapDurationMinutes)m) before cutoff after \(formatDuration(effectiveWakeWindowMinutes)) wake window."
            }

            return NextNapPrediction(
                recommendedStart: recommendedStart,
                windowStart: windowStart,
                windowEnd: windowEnd,
                wakeWindowMinutes: effectiveWakeWindowMinutes,
                maxNapEnd: maxNapEnd,
                isBackupCatnap: true,
                reason: reason
            )
        }

        let maxNapEnd = recommendedStart.addingTimeInterval(TimeInterval(config.napCapMinutes * 60))
        let nextNapNumber = napCount + 1

        let reason: String
        if isShortNapReset, let lastDuration = lastNapDurationMinutes {
            reason = "Nap \(nextNapNumber): short nap (\(lastDuration)m < \(config.shortNapThresholdMinutes)m) reset wake window to \(formatDuration(effectiveWakeWindowMinutes)) (cap \(config.napCapMinutes)m)."
        } else if napCount == 0 {
            reason = "Nap 1 after morning wake: \(formatDuration(effectiveWakeWindowMinutes)) wake window (cap \(config.napCapMinutes)m)."
        } else {
            reason = "Nap \(nextNapNumber) after Nap \(napCount): \(formatDuration(effectiveWakeWindowMinutes)) wake window (cap \(config.napCapMinutes)m)."
        }

        return NextNapPrediction(
            recommendedStart: recommendedStart,
            windowStart: windowStart,
            windowEnd: windowEnd,
            wakeWindowMinutes: effectiveWakeWindowMinutes,
            maxNapEnd: maxNapEnd,
            isBackupCatnap: false,
            reason: reason
        )
    }

    private static func makeCutoffDate(
        onDayOf referenceDate: Date,
        minutesFromMidnight: Int,
        calendar: Calendar
    ) -> Date {
        let clampedMinutes = max(0, minutesFromMidnight)
        let hour = clampedMinutes / 60
        let minute = clampedMinutes % 60
        if hour < 24,
           let date = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: referenceDate) {
            return date
        }
        let startOfDay = calendar.startOfDay(for: referenceDate)
        return startOfDay.addingTimeInterval(TimeInterval(clampedMinutes * 60))
    }

    private static func formatDuration(_ minutes: Int) -> String {
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
}

/// Top-level convenience forwarding to `WakeWindowCalculator.predictNextNap`.
public func predictNextNap(
    asOf: Date,
    wakeUpTime: Date?,
    completedNapsToday: [EventDTO],
    config: ScheduleConfig,
    calendar: Calendar = .current
) -> NextNapPrediction? {
    WakeWindowCalculator.predictNextNap(
        asOf: asOf,
        wakeUpTime: wakeUpTime,
        completedNapsToday: completedNapsToday,
        config: config,
        calendar: calendar
    )
}
