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
    public var startedAt: Date
    public var leftAccumulatedSeconds: TimeInterval
    public var rightAccumulatedSeconds: TimeInterval
    public var activeSide: BreastSide?
    public var activeSegmentStartedAt: Date?

    public init(
        startedAt: Date,
        leftAccumulatedSeconds: TimeInterval = 0,
        rightAccumulatedSeconds: TimeInterval = 0,
        activeSide: BreastSide? = nil,
        activeSegmentStartedAt: Date? = nil
    ) {
        self.startedAt = startedAt
        self.leftAccumulatedSeconds = leftAccumulatedSeconds
        self.rightAccumulatedSeconds = rightAccumulatedSeconds
        self.activeSide = activeSide
        self.activeSegmentStartedAt = activeSegmentStartedAt
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

/// Complete offline-first state persisted atomically on disk (App Group or Application Support).
public struct PersistedAppState: Codable, Sendable, Equatable {
    public var profile: ProfileDTO
    public var household: HouseholdDTO
    public var currentUserId: UUID
    public var events: [EventDTO]
    public var activeNapStart: Date?
    public var activeNursingSession: ActiveNursingSession?
    public var pendingScans: [ScannedSheetRecord]
    public var outbox: [SyncOutboxItem]
    public var serverWatermark: Date?
    public var preferredUnit: VolumeUnit
    public var colorMode: AppColorModePreference
    public var authEmail: String?
    public var displayName: String?
    public var isSignedInWithApple: Bool

    public init(
        profile: ProfileDTO,
        household: HouseholdDTO,
        currentUserId: UUID,
        events: [EventDTO],
        activeNapStart: Date? = nil,
        activeNursingSession: ActiveNursingSession? = nil,
        pendingScans: [ScannedSheetRecord] = [],
        outbox: [SyncOutboxItem] = [],
        serverWatermark: Date? = nil,
        preferredUnit: VolumeUnit = .oz,
        colorMode: AppColorModePreference = .day,
        authEmail: String? = nil,
        displayName: String? = nil,
        isSignedInWithApple: Bool = true
    ) {
        self.profile = profile
        self.household = household
        self.currentUserId = currentUserId
        self.events = events
        self.activeNapStart = activeNapStart
        self.activeNursingSession = activeNursingSession
        self.pendingScans = pendingScans
        self.outbox = outbox
        self.serverWatermark = serverWatermark
        self.preferredUnit = preferredUnit
        self.colorMode = colorMode
        self.authEmail = authEmail
        self.displayName = displayName
        self.isSignedInWithApple = isSignedInWithApple
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
