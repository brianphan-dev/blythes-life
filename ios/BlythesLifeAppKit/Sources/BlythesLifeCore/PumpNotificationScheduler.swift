import Foundation
#if canImport(UserNotifications)
import UserNotifications
#endif

/// Authorization status for local pump notifications on the current device.
public enum PumpNotificationAuthorizationStatus: String, Sendable, Equatable {
    case notDetermined
    case authorized
    case denied
    case unsupported
}

/// Pure, deterministic planner for next pump reminder and active pump timer alert timestamps.
public enum PumpNotificationPlanner: Sendable {
    /// Computes the next local reminder date after the latest completed pump session,
    /// suppressing reminders when disabled, while actively pumping, or when already overdue,
    /// and rolling targets inside quiet hours forward to `quietEnd`.
    public static func nextReminderDate(
        lastCompletedPumpAt: Date?,
        activePump: ActivePumpSession?,
        settings: PumpNotificationSettings,
        now: Date,
        calendar: Calendar
    ) -> Date? {
        guard settings.isEnabled, activePump == nil, let lastCompletedPumpAt else {
            return nil
        }

        let intervalMinutes = max(30, settings.intervalMinutes)
        var target = lastCompletedPumpAt.addingTimeInterval(TimeInterval(intervalMinutes * 60))

        if settings.quietHoursEnabled {
            let quietStart = normalizedMinutesFromMidnight(settings.quietStartMinutesFromMidnight)
            let quietEnd = normalizedMinutesFromMidnight(settings.quietEndMinutesFromMidnight)

            if quietStart != quietEnd {
                let comps = calendar.dateComponents([.hour, .minute], from: target)
                let targetMinuteOfDay = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)

                let isInsideQuietWindow: Bool
                if quietStart > quietEnd {
                    // Overnight wrap, e.g. 22:00 (1320) -> 06:00 (360)
                    isInsideQuietWindow = targetMinuteOfDay >= quietStart || targetMinuteOfDay < quietEnd
                } else {
                    // Same-day window, e.g. 13:00 (780) -> 15:00 (900)
                    isInsideQuietWindow = targetMinuteOfDay >= quietStart && targetMinuteOfDay < quietEnd
                }

                if isInsideQuietWindow {
                    let dayForQuietEnd: Date
                    if quietStart > quietEnd && targetMinuteOfDay >= quietStart {
                        dayForQuietEnd = calendar.date(byAdding: .day, value: 1, to: target)
                            ?? target.addingTimeInterval(86_400)
                    } else {
                        dayForQuietEnd = target
                    }

                    var endComps = calendar.dateComponents([.year, .month, .day], from: dayForQuietEnd)
                    endComps.timeZone = calendar.timeZone
                    endComps.hour = quietEnd / 60
                    endComps.minute = quietEnd % 60
                    endComps.second = 0

                    if let shifted = calendar.date(from: endComps) {
                        target = shifted
                    }
                }
            }
        }

        guard target > now else {
            return nil
        }
        return target
    }

    /// Computes when an active, currently running pump timer will hit the user's configured target duration.
    public static func nextTimerAlertDate(
        activePump: ActivePumpSession?,
        settings: PumpNotificationSettings,
        now: Date
    ) -> Date? {
        guard settings.isEnabled,
              let targetMinutes = settings.timerAlertMinutes,
              targetMinutes > 0,
              let activePump,
              activePump.isRunning
        else {
            return nil
        }

        let elapsed = activePump.elapsedSeconds(asOf: now).session
        let targetSeconds = TimeInterval(targetMinutes * 60)
        let remaining = targetSeconds - elapsed
        guard remaining > 1.0 else {
            return nil
        }
        return now.addingTimeInterval(remaining)
    }

    private static func normalizedMinutesFromMidnight(_ raw: Int) -> Int {
        ((raw % 1440) + 1440) % 1440
    }
}

/// Platform scheduling abstraction for local pump reminders and timer alerts.
public protocol PumpNotificationScheduling: Sendable {
    func authorizationStatus() async -> PumpNotificationAuthorizationStatus
    func requestAuthorization() async -> Bool
    func syncNotifications(
        nextReminderDate: Date?,
        timerAlertDate: Date?,
        timerAlertMinutes: Int?,
        childName: String
    ) async
    func cancelAll() async
}

/// Production `UNUserNotificationCenter`-backed scheduler with safe `.app` bundle guard for `swift test`.
public final class UserNotificationPumpScheduler: PumpNotificationScheduling, Sendable {
    public static let nextReminderRequestId = "blythes-life.pump.next-reminder"
    public static let timerAlertRequestId = "blythes-life.pump.timer-alert"

    public init() {}

    private var isSupportedEnvironment: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
    }

    public func authorizationStatus() async -> PumpNotificationAuthorizationStatus {
        #if canImport(UserNotifications)
        guard isSupportedEnvironment else { return .unsupported }
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional:
            return .authorized
        #if os(iOS)
        case .ephemeral:
            return .authorized
        #endif
        case .denied:
            return .denied
        case .notDetermined:
            return .notDetermined
        @unknown default:
            return .notDetermined
        }
        #else
        return .unsupported
        #endif
    }

    public func requestAuthorization() async -> Bool {
        #if canImport(UserNotifications)
        guard isSupportedEnvironment else { return false }
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])
        } catch {
            return false
        }
        #else
        return false
        #endif
    }

    public func syncNotifications(
        nextReminderDate: Date?,
        timerAlertDate: Date?,
        timerAlertMinutes: Int?,
        childName: String
    ) async {
        _ = childName
        #if canImport(UserNotifications)
        guard isSupportedEnvironment else { return }
        let center = UNUserNotificationCenter.current()

        if let nextReminderDate {
            let content = UNMutableNotificationContent()
            content.title = "Time to pump"
            content.body = "It has been a while since your last pump session."
            content.sound = .default
            content.userInfo = ["kind": "pump"]

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, nextReminderDate.timeIntervalSinceNow),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: Self.nextReminderRequestId,
                content: content,
                trigger: trigger
            )
            center.removePendingNotificationRequests(withIdentifiers: [Self.nextReminderRequestId])
            try? await center.add(request)
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.nextReminderRequestId])
        }

        if let timerAlertDate {
            let mins = max(
                1,
                timerAlertMinutes ?? Int(max(1, (timerAlertDate.timeIntervalSinceNow / 60.0).rounded()))
            )
            let content = UNMutableNotificationContent()
            content.title = "Pump timer reached \(mins)m"
            content.body = "Open Blythe's Life to finish and save output."
            content.sound = .default
            content.userInfo = ["kind": "pump"]

            let trigger = UNTimeIntervalNotificationTrigger(
                timeInterval: max(1, timerAlertDate.timeIntervalSinceNow),
                repeats: false
            )
            let request = UNNotificationRequest(
                identifier: Self.timerAlertRequestId,
                content: content,
                trigger: trigger
            )
            center.removePendingNotificationRequests(withIdentifiers: [Self.timerAlertRequestId])
            try? await center.add(request)
        } else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.timerAlertRequestId])
        }
        #endif
    }

    public func cancelAll() async {
        #if canImport(UserNotifications)
        guard isSupportedEnvironment else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [Self.nextReminderRequestId, Self.timerAlertRequestId]
        )
        #endif
    }
}

/// Deterministic no-op scheduler for unit tests and SwiftUI previews.
public struct NoopPumpNotificationScheduler: PumpNotificationScheduling, Sendable {
    public init() {}

    public func authorizationStatus() async -> PumpNotificationAuthorizationStatus {
        .notDetermined
    }

    public func requestAuthorization() async -> Bool {
        false
    }

    public func syncNotifications(
        nextReminderDate: Date?,
        timerAlertDate: Date?,
        timerAlertMinutes: Int?,
        childName: String
    ) async {}

    public func cancelAll() async {}
}
