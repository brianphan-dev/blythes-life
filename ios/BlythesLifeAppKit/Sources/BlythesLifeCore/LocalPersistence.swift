import BlythesLifeShared
import Foundation
import os

/// Day/Night color mode preference (Night uses true OLED black with warm dim amber text).
public enum AppColorModePreference: String, Codable, Sendable, CaseIterable, Equatable, Hashable {
    case day
    case night
}

/// Entity category tracked in the offline-first sync outbox.
public enum SyncOutboxEntityKind: String, Codable, Sendable, Equatable, Hashable {
    case event
    case profile
}

/// Outbox mutation operation kind.
public enum SyncOutboxOperation: String, Codable, Sendable, Equatable, Hashable {
    case upsert
    case delete
}

/// Durable queued mutation awaiting delivery to `POST /v1/sync/push`.
public struct SyncOutboxItem: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var entityKind: SyncOutboxEntityKind
    public var entityId: UUID
    public var operation: SyncOutboxOperation
    public var payload: Data
    public var createdAt: Date
    public var retryCount: Int

    public init(
        id: UUID = UUID(),
        entityKind: SyncOutboxEntityKind,
        entityId: UUID,
        operation: SyncOutboxOperation = .upsert,
        payload: Data,
        createdAt: Date = Date(),
        retryCount: Int = 0
    ) {
        self.id = id
        self.entityKind = entityKind
        self.entityId = entityId
        self.operation = operation
        self.payload = payload
        self.createdAt = createdAt
        self.retryCount = retryCount
    }

    public static func event(
        _ event: EventDTO,
        operation: SyncOutboxOperation = .upsert,
        createdAt: Date = Date()
    ) throws -> SyncOutboxItem {
        let data = try BlythesLifeJSONCoding.makeEncoder().encode(event)
        return SyncOutboxItem(
            entityKind: .event,
            entityId: event.id,
            operation: operation,
            payload: data,
            createdAt: createdAt
        )
    }

    public static func profile(
        _ profile: ProfileDTO,
        operation: SyncOutboxOperation = .upsert,
        createdAt: Date = Date()
    ) throws -> SyncOutboxItem {
        let data = try BlythesLifeJSONCoding.makeEncoder().encode(profile)
        return SyncOutboxItem(
            entityKind: .profile,
            entityId: profile.id,
            operation: operation,
            payload: data,
            createdAt: createdAt
        )
    }

    public func decodedEvent() throws -> EventDTO? {
        guard entityKind == .event else { return nil }
        return try BlythesLifeJSONCoding.makeDecoder().decode(EventDTO.self, from: payload)
    }

    public func decodedProfile() throws -> ProfileDTO? {
        guard entityKind == .profile else { return nil }
        return try BlythesLifeJSONCoding.makeDecoder().decode(ProfileDTO.self, from: payload)
    }
}

/// Active left/right nursing timer persisted across app launches and shared with widgets/devices.
public struct ActiveNursingSession: Codable, Sendable, Equatable, Hashable {
    public var eventId: UUID?
    public var startedAt: Date
    public var leftAccumulatedSeconds: TimeInterval
    public var rightAccumulatedSeconds: TimeInterval
    public var activeSide: BreastSide?
    public var activeSegmentStartedAt: Date?
    public var lastActiveSide: BreastSide?

    public init(
        eventId: UUID? = nil,
        startedAt: Date,
        leftAccumulatedSeconds: TimeInterval = 0,
        rightAccumulatedSeconds: TimeInterval = 0,
        activeSide: BreastSide? = nil,
        activeSegmentStartedAt: Date? = nil,
        lastActiveSide: BreastSide? = nil
    ) {
        self.eventId = eventId
        self.startedAt = startedAt
        self.leftAccumulatedSeconds = leftAccumulatedSeconds
        self.rightAccumulatedSeconds = rightAccumulatedSeconds
        self.activeSide = activeSide
        self.activeSegmentStartedAt = activeSegmentStartedAt
        self.lastActiveSide = lastActiveSide
    }

    private enum CodingKeys: String, CodingKey {
        case eventId
        case startedAt
        case leftAccumulatedSeconds
        case rightAccumulatedSeconds
        case activeSide
        case activeSegmentStartedAt
        case lastActiveSide
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.eventId = try container.decodeIfPresent(UUID.self, forKey: .eventId)
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.leftAccumulatedSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .leftAccumulatedSeconds) ?? 0
        self.rightAccumulatedSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .rightAccumulatedSeconds) ?? 0
        self.activeSide = try container.decodeIfPresent(BreastSide.self, forKey: .activeSide)
        self.activeSegmentStartedAt = try container.decodeIfPresent(Date.self, forKey: .activeSegmentStartedAt)
        self.lastActiveSide = try container.decodeIfPresent(BreastSide.self, forKey: .lastActiveSide)
    }

    public var isRunning: Bool {
        activeSide != nil && activeSegmentStartedAt != nil
    }

    /// Computes live elapsed seconds for left, right, and total as of `now`.
    public func elapsedSeconds(asOf now: Date) -> (left: TimeInterval, right: TimeInterval, total: TimeInterval) {
        let liveDelta: TimeInterval
        if let activeSegmentStartedAt, activeSide != nil {
            liveDelta = max(0, now.timeIntervalSince(activeSegmentStartedAt))
        } else {
            liveDelta = 0
        }
        let left = leftAccumulatedSeconds + (activeSide == .left ? liveDelta : 0)
        let right = rightAccumulatedSeconds + (activeSide == .right ? liveDelta : 0)
        return (left, right, left + right)
    }
}

/// Active independent dual-side pumping timer persisted across app launches.
/// Tracks left, right, and union-of-active-intervals session elapsed durations independently.
public struct ActivePumpSession: Codable, Sendable, Equatable, Hashable {
    public var eventId: UUID?
    public var startedAt: Date
    public var leftAccumulatedSeconds: TimeInterval
    public var rightAccumulatedSeconds: TimeInterval
    public var leftSegmentStartedAt: Date?
    public var rightSegmentStartedAt: Date?
    public var sessionAccumulatedSeconds: TimeInterval
    public var sessionSegmentStartedAt: Date?

    public init(
        eventId: UUID? = nil,
        startedAt: Date,
        leftAccumulatedSeconds: TimeInterval = 0,
        rightAccumulatedSeconds: TimeInterval = 0,
        leftSegmentStartedAt: Date? = nil,
        rightSegmentStartedAt: Date? = nil,
        sessionAccumulatedSeconds: TimeInterval = 0,
        sessionSegmentStartedAt: Date? = nil
    ) {
        self.eventId = eventId
        self.startedAt = startedAt
        self.leftAccumulatedSeconds = leftAccumulatedSeconds
        self.rightAccumulatedSeconds = rightAccumulatedSeconds
        self.leftSegmentStartedAt = leftSegmentStartedAt
        self.rightSegmentStartedAt = rightSegmentStartedAt
        self.sessionAccumulatedSeconds = sessionAccumulatedSeconds
        self.sessionSegmentStartedAt = sessionSegmentStartedAt
    }

    public var isLeftRunning: Bool { leftSegmentStartedAt != nil }
    public var isRightRunning: Bool { rightSegmentStartedAt != nil }
    public var isRunning: Bool { isLeftRunning || isRightRunning }
    public var isBothRunning: Bool { isLeftRunning && isRightRunning }

    /// Computes live elapsed seconds for left, right, and union-of-active-intervals session as of `now`.
    public func elapsedSeconds(asOf now: Date) -> (left: TimeInterval, right: TimeInterval, session: TimeInterval) {
        let left = leftAccumulatedSeconds + (leftSegmentStartedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
        let right = rightAccumulatedSeconds + (rightSegmentStartedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
        let session = sessionAccumulatedSeconds + (sessionSegmentStartedAt.map { max(0, now.timeIntervalSince($0)) } ?? 0)
        return (left, right, session)
    }

    /// Derives the canonical breast side from accumulated or currently running sides.
    public func derivedSide(asOf now: Date) -> BreastSide {
        let elapsed = elapsedSeconds(asOf: now)
        let hasLeft = elapsed.left > 0 || isLeftRunning
        let hasRight = elapsed.right > 0 || isRightRunning
        if hasLeft && hasRight {
            return .both
        }
        if hasLeft {
            return .left
        }
        if hasRight {
            return .right
        }
        return .both
    }

    private enum CodingKeys: String, CodingKey {
        case eventId
        case startedAt
        case leftAccumulatedSeconds
        case rightAccumulatedSeconds
        case leftSegmentStartedAt
        case rightSegmentStartedAt
        case sessionAccumulatedSeconds
        case sessionSegmentStartedAt
    }

    private enum LegacyCodingKeys: String, CodingKey {
        case accumulatedSeconds
        case isRunning
        case activeSegmentStartedAt
        case side
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.eventId = try container.decodeIfPresent(UUID.self, forKey: .eventId)
        let startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.startedAt = startedAt

        let hasNewKeys = container.contains(.leftAccumulatedSeconds)
            || container.contains(.rightAccumulatedSeconds)
            || container.contains(.sessionAccumulatedSeconds)
            || container.contains(.leftSegmentStartedAt)
            || container.contains(.rightSegmentStartedAt)
            || container.contains(.sessionSegmentStartedAt)

        if hasNewKeys {
            self.leftAccumulatedSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .leftAccumulatedSeconds) ?? 0
            self.rightAccumulatedSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .rightAccumulatedSeconds) ?? 0
            self.leftSegmentStartedAt = try container.decodeIfPresent(Date.self, forKey: .leftSegmentStartedAt)
            self.rightSegmentStartedAt = try container.decodeIfPresent(Date.self, forKey: .rightSegmentStartedAt)
            self.sessionAccumulatedSeconds = try container.decodeIfPresent(TimeInterval.self, forKey: .sessionAccumulatedSeconds) ?? 0
            self.sessionSegmentStartedAt = try container.decodeIfPresent(Date.self, forKey: .sessionSegmentStartedAt)
        } else {
            let legacy = try decoder.container(keyedBy: LegacyCodingKeys.self)
            let oldAccum = try legacy.decodeIfPresent(TimeInterval.self, forKey: .accumulatedSeconds) ?? 0
            let oldIsRunning = try legacy.decodeIfPresent(Bool.self, forKey: .isRunning) ?? false
            let oldActiveSeg = try legacy.decodeIfPresent(Date.self, forKey: .activeSegmentStartedAt)
            let oldSide = try legacy.decodeIfPresent(BreastSide.self, forKey: .side) ?? .both
            let oldSeg: Date? = oldIsRunning ? (oldActiveSeg ?? startedAt) : nil

            self.sessionAccumulatedSeconds = oldAccum
            self.sessionSegmentStartedAt = oldSeg
            self.leftAccumulatedSeconds = (oldSide == .left || oldSide == .both) ? oldAccum : 0
            self.rightAccumulatedSeconds = (oldSide == .right || oldSide == .both) ? oldAccum : 0
            self.leftSegmentStartedAt = (oldSide == .left || oldSide == .both) ? oldSeg : nil
            self.rightSegmentStartedAt = (oldSide == .right || oldSide == .both) ? oldSeg : nil
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(eventId, forKey: .eventId)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(leftAccumulatedSeconds, forKey: .leftAccumulatedSeconds)
        try container.encode(rightAccumulatedSeconds, forKey: .rightAccumulatedSeconds)
        try container.encodeIfPresent(leftSegmentStartedAt, forKey: .leftSegmentStartedAt)
        try container.encodeIfPresent(rightSegmentStartedAt, forKey: .rightSegmentStartedAt)
        try container.encode(sessionAccumulatedSeconds, forKey: .sessionAccumulatedSeconds)
        try container.encodeIfPresent(sessionSegmentStartedAt, forKey: .sessionSegmentStartedAt)
    }
}

/// Per-device local notification preferences for pump reminders and active pump timer alerts.
public struct PumpNotificationSettings: Codable, Sendable, Equatable, Hashable {
    public static let defaultIntervalMinutes = 180
    public static let defaultQuietStartMinutesFromMidnight = 1320
    public static let defaultQuietEndMinutesFromMidnight = 360

    public var isEnabled: Bool
    public var intervalMinutes: Int
    public var quietHoursEnabled: Bool
    public var quietStartMinutesFromMidnight: Int
    public var quietEndMinutesFromMidnight: Int
    public var timerAlertMinutes: Int?

    public init(
        isEnabled: Bool = false,
        intervalMinutes: Int = PumpNotificationSettings.defaultIntervalMinutes,
        quietHoursEnabled: Bool = false,
        quietStartMinutesFromMidnight: Int = PumpNotificationSettings.defaultQuietStartMinutesFromMidnight,
        quietEndMinutesFromMidnight: Int = PumpNotificationSettings.defaultQuietEndMinutesFromMidnight,
        timerAlertMinutes: Int? = nil
    ) {
        self.isEnabled = isEnabled
        self.intervalMinutes = intervalMinutes
        self.quietHoursEnabled = quietHoursEnabled
        self.quietStartMinutesFromMidnight = quietStartMinutesFromMidnight
        self.quietEndMinutesFromMidnight = quietEndMinutesFromMidnight
        self.timerAlertMinutes = timerAlertMinutes
    }

    private enum CodingKeys: String, CodingKey {
        case isEnabled
        case intervalMinutes
        case quietHoursEnabled
        case quietStartMinutesFromMidnight
        case quietEndMinutesFromMidnight
        case timerAlertMinutes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? false
        self.intervalMinutes = try container.decodeIfPresent(Int.self, forKey: .intervalMinutes)
            ?? Self.defaultIntervalMinutes
        self.quietHoursEnabled = try container.decodeIfPresent(Bool.self, forKey: .quietHoursEnabled) ?? false
        self.quietStartMinutesFromMidnight = try container.decodeIfPresent(
            Int.self,
            forKey: .quietStartMinutesFromMidnight
        ) ?? Self.defaultQuietStartMinutesFromMidnight
        self.quietEndMinutesFromMidnight = try container.decodeIfPresent(
            Int.self,
            forKey: .quietEndMinutesFromMidnight
        ) ?? Self.defaultQuietEndMinutesFromMidnight
        self.timerAlertMinutes = try container.decodeIfPresent(Int.self, forKey: .timerAlertMinutes)
    }
}

/// Complete offline-first state persisted atomically on disk (App Group or Application Support).
public struct PersistedAppState: Codable, Sendable, Equatable {
    public var profile: ProfileDTO
    public var household: HouseholdDTO
    public var currentUserId: UUID
    public var events: [EventDTO]
    public var activeNapStart: Date?
    public var activeNursingSession: ActiveNursingSession?
    public var activePumpSession: ActivePumpSession?
    public var pendingScans: [ScannedSheetRecord]
    public var outbox: [SyncOutboxItem]
    public var serverWatermark: Date?
    public var preferredUnit: VolumeUnit
    public var colorMode: AppColorModePreference
    public var authEmail: String?
    public var displayName: String?
    public var isSignedInWithApple: Bool
    public var hasCompletedHouseholdSetup: Bool
    public var isDemoPreview: Bool
    public var pendingJoinRequest: HouseholdJoinRequestDTO?
    public var pumpNotificationSettings: PumpNotificationSettings

    public init(
        profile: ProfileDTO,
        household: HouseholdDTO,
        currentUserId: UUID,
        events: [EventDTO],
        activeNapStart: Date? = nil,
        activeNursingSession: ActiveNursingSession? = nil,
        activePumpSession: ActivePumpSession? = nil,
        pendingScans: [ScannedSheetRecord] = [],
        outbox: [SyncOutboxItem] = [],
        serverWatermark: Date? = nil,
        preferredUnit: VolumeUnit = .oz,
        colorMode: AppColorModePreference = .day,
        authEmail: String? = nil,
        displayName: String? = nil,
        isSignedInWithApple: Bool = true,
        hasCompletedHouseholdSetup: Bool = true,
        isDemoPreview: Bool = false,
        pendingJoinRequest: HouseholdJoinRequestDTO? = nil,
        pumpNotificationSettings: PumpNotificationSettings = PumpNotificationSettings()
    ) {
        self.profile = profile
        self.household = household
        self.currentUserId = currentUserId
        self.events = events
        self.activeNapStart = activeNapStart
        self.activeNursingSession = activeNursingSession
        self.activePumpSession = activePumpSession
        self.pendingScans = pendingScans
        self.outbox = outbox
        self.serverWatermark = serverWatermark
        self.preferredUnit = preferredUnit
        self.colorMode = colorMode
        self.authEmail = authEmail
        self.displayName = displayName
        self.isSignedInWithApple = isSignedInWithApple
        self.hasCompletedHouseholdSetup = hasCompletedHouseholdSetup
        self.isDemoPreview = isDemoPreview
        self.pendingJoinRequest = pendingJoinRequest
        self.pumpNotificationSettings = pumpNotificationSettings
    }

    private enum CodingKeys: String, CodingKey {
        case profile
        case household
        case currentUserId
        case events
        case activeNapStart
        case activeNursingSession
        case activePumpSession
        case pendingScans
        case outbox
        case serverWatermark
        case preferredUnit
        case colorMode
        case authEmail
        case displayName
        case isSignedInWithApple
        case hasCompletedHouseholdSetup
        case isDemoPreview
        case pendingJoinRequest
        case pumpNotificationSettings
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.profile = try container.decode(ProfileDTO.self, forKey: .profile)
        self.household = try container.decode(HouseholdDTO.self, forKey: .household)
        self.currentUserId = try container.decode(UUID.self, forKey: .currentUserId)
        self.events = try container.decodeIfPresent([EventDTO].self, forKey: .events) ?? []
        self.activeNapStart = try container.decodeIfPresent(Date.self, forKey: .activeNapStart)
        self.activeNursingSession = try container.decodeIfPresent(ActiveNursingSession.self, forKey: .activeNursingSession)
        self.activePumpSession = try container.decodeIfPresent(ActivePumpSession.self, forKey: .activePumpSession)
        self.pendingScans = try container.decodeIfPresent([ScannedSheetRecord].self, forKey: .pendingScans) ?? []
        self.outbox = try container.decodeIfPresent([SyncOutboxItem].self, forKey: .outbox) ?? []
        self.serverWatermark = try container.decodeIfPresent(Date.self, forKey: .serverWatermark)
        self.preferredUnit = try container.decodeIfPresent(VolumeUnit.self, forKey: .preferredUnit) ?? .oz
        self.colorMode = try container.decodeIfPresent(AppColorModePreference.self, forKey: .colorMode) ?? .day
        self.authEmail = try container.decodeIfPresent(String.self, forKey: .authEmail)
        self.displayName = try container.decodeIfPresent(String.self, forKey: .displayName)
        self.isSignedInWithApple = try container.decodeIfPresent(Bool.self, forKey: .isSignedInWithApple) ?? false
        self.hasCompletedHouseholdSetup = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedHouseholdSetup) ?? true
        self.isDemoPreview = try container.decodeIfPresent(Bool.self, forKey: .isDemoPreview) ?? false
        self.pendingJoinRequest = try container.decodeIfPresent(
            HouseholdJoinRequestDTO.self,
            forKey: .pendingJoinRequest
        )
        self.pumpNotificationSettings = try container.decodeIfPresent(
            PumpNotificationSettings.self,
            forKey: .pumpNotificationSettings
        ) ?? PumpNotificationSettings()
    }
}

/// Persistence abstraction enabling atomic disk storage in production and deterministic in-memory storage in tests/previews.
public protocol LocalStateStorage: Sendable {
    func load() throws -> PersistedAppState?
    func save(_ state: PersistedAppState) throws
    func clear() throws
}

/// Atomic file-backed persistence targeting an App Group container when configured, falling back to Application Support.
public final class FileLocalStateStorage: LocalStateStorage, Sendable {
    public let fileURL: URL
    private let lock = OSAllocatedUnfairLock<Void>(initialState: ())

    public init(
        appGroupIdentifier: String? = nil,
        fileName: String = "blythes-life-state.json",
        fileURL: URL? = nil
    ) {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let baseDirectory: URL
            if let appGroupIdentifier,
               let groupURL = FileManager.default.containerURL(
                   forSecurityApplicationGroupIdentifier: appGroupIdentifier
               )
            {
                baseDirectory = groupURL.appendingPathComponent("BlythesLife", isDirectory: true)
            } else {
                let appSupport = FileManager.default.urls(
                    for: .applicationSupportDirectory,
                    in: .userDomainMask
                ).first ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
                baseDirectory = appSupport.appendingPathComponent("BlythesLife", isDirectory: true)
            }
            self.fileURL = baseDirectory.appendingPathComponent(fileName, isDirectory: false)
        }
    }

    public func load() throws -> PersistedAppState? {
        try lock.withLock {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                return nil
            }
            let data = try Data(contentsOf: fileURL)
            return try BlythesLifeJSONCoding.makeDecoder().decode(PersistedAppState.self, from: data)
        }
    }

    public func save(_ state: PersistedAppState) throws {
        try lock.withLock {
            let directory = fileURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: directory.path) {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            }
            let data = try BlythesLifeJSONCoding.makeEncoder().encode(state)
            #if os(iOS)
            let options: Data.WritingOptions = [.atomic, .completeFileProtectionUntilFirstUserAuthentication]
            #else
            let options: Data.WritingOptions = [.atomic]
            #endif
            try data.write(to: fileURL, options: options)
        }
    }

    public func clear() throws {
        try lock.withLock {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        }
    }
}

/// Thread-safe in-memory storage for unit tests and SwiftUI previews.
public final class InMemoryLocalStateStorage: LocalStateStorage, Sendable {
    private let stateLock: OSAllocatedUnfairLock<PersistedAppState?>

    public init(initialState: PersistedAppState? = nil) {
        self.stateLock = OSAllocatedUnfairLock(initialState: initialState)
    }

    public func load() throws -> PersistedAppState? {
        stateLock.withLock { $0 }
    }

    public func save(_ state: PersistedAppState) throws {
        stateLock.withLock { $0 = state }
    }

    public func clear() throws {
        stateLock.withLock { $0 = nil }
    }
}
