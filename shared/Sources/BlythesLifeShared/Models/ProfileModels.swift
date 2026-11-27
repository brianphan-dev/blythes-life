import Foundation

public enum HouseholdRole: String, Codable, Sendable, CaseIterable, Hashable {
    case owner
    case member
    case caregiver
}

public enum HouseholdJoinRequestStatus: String, Codable, Sendable, CaseIterable, Hashable {
    case pending
    case approved
    case declined
}

public struct HouseholdInviteDTO: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var householdId: UUID
    public var code: String
    public var label: String?
    public var role: HouseholdRole
    public var createdBy: UUID
    public var createdAt: Date
    public var expiresAt: Date
    public var usedAt: Date?
    public var usedBy: UUID?
    public var revokedAt: Date?

    public init(
        id: UUID = UUID(),
        householdId: UUID,
        code: String,
        label: String? = nil,
        role: HouseholdRole = .member,
        createdBy: UUID,
        createdAt: Date = Date(),
        expiresAt: Date,
        usedAt: Date? = nil,
        usedBy: UUID? = nil,
        revokedAt: Date? = nil
    ) {
        self.id = id
        self.householdId = householdId
        self.code = code
        self.label = label
        self.role = role
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.expiresAt = expiresAt
        self.usedAt = usedAt
        self.usedBy = usedBy
        self.revokedAt = revokedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case code
        case label
        case role
        case createdBy = "created_by"
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case usedAt = "used_at"
        case usedBy = "used_by"
        case revokedAt = "revoked_at"
    }
}

public struct HouseholdJoinRequestDTO: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var householdId: UUID
    public var householdName: String
    public var inviteId: UUID?
    public var userId: UUID
    public var displayName: String
    public var requestedRole: HouseholdRole
    public var status: HouseholdJoinRequestStatus
    public var createdAt: Date
    public var resolvedAt: Date?

    public init(
        id: UUID = UUID(),
        householdId: UUID,
        householdName: String,
        inviteId: UUID? = nil,
        userId: UUID,
        displayName: String,
        requestedRole: HouseholdRole = .member,
        status: HouseholdJoinRequestStatus = .pending,
        createdAt: Date = Date(),
        resolvedAt: Date? = nil
    ) {
        self.id = id
        self.householdId = householdId
        self.householdName = householdName
        self.inviteId = inviteId
        self.userId = userId
        self.displayName = displayName
        self.requestedRole = requestedRole
        self.status = status
        self.createdAt = createdAt
        self.resolvedAt = resolvedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case householdName = "household_name"
        case inviteId = "invite_id"
        case userId = "user_id"
        case displayName = "display_name"
        case requestedRole = "requested_role"
        case status
        case createdAt = "created_at"
        case resolvedAt = "resolved_at"
    }
}

public struct HouseholdMemberDTO: Codable, Sendable, Equatable, Hashable {
    public var householdId: UUID
    public var userId: UUID
    public var role: HouseholdRole
    public var displayName: String

    public init(
        householdId: UUID,
        userId: UUID,
        role: HouseholdRole,
        displayName: String
    ) {
        self.householdId = householdId
        self.userId = userId
        self.role = role
        self.displayName = displayName
    }

    enum CodingKeys: String, CodingKey {
        case householdId = "household_id"
        case userId = "user_id"
        case role
        case displayName = "display_name"
    }
}

public struct HouseholdDTO: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var name: String
    public var inviteCode: String?
    public var inviteExpiresAt: Date?
    public var createdBy: UUID
    public var createdAt: Date
    public var role: HouseholdRole?
    public var members: [HouseholdMemberDTO]?
    public var activeInvites: [HouseholdInviteDTO]?
    public var pendingJoinRequests: [HouseholdJoinRequestDTO]?

    public init(
        id: UUID = UUID(),
        name: String,
        inviteCode: String? = nil,
        inviteExpiresAt: Date? = nil,
        createdBy: UUID,
        createdAt: Date = Date(),
        role: HouseholdRole? = nil,
        members: [HouseholdMemberDTO]? = nil,
        activeInvites: [HouseholdInviteDTO]? = nil,
        pendingJoinRequests: [HouseholdJoinRequestDTO]? = nil
    ) {
        self.id = id
        self.name = name
        self.inviteCode = inviteCode
        self.inviteExpiresAt = inviteExpiresAt
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.role = role
        self.members = members
        self.activeInvites = activeInvites
        self.pendingJoinRequests = pendingJoinRequests
    }

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case inviteCode = "invite_code"
        case inviteExpiresAt = "invite_expires_at"
        case createdBy = "created_by"
        case createdAt = "created_at"
        case role
        case members
        case activeInvites = "active_invites"
        case pendingJoinRequests = "pending_join_requests"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.inviteCode = try container.decodeIfPresent(String.self, forKey: .inviteCode)
        self.inviteExpiresAt = try container.decodeIfPresent(Date.self, forKey: .inviteExpiresAt)
        self.createdBy = try container.decode(UUID.self, forKey: .createdBy)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.role = try container.decodeIfPresent(HouseholdRole.self, forKey: .role)
        self.members = try container.decodeIfPresent([HouseholdMemberDTO].self, forKey: .members)
        self.activeInvites = try container.decodeIfPresent([HouseholdInviteDTO].self, forKey: .activeInvites)
        self.pendingJoinRequests = try container.decodeIfPresent(
            [HouseholdJoinRequestDTO].self,
            forKey: .pendingJoinRequests
        )
    }
}

public struct ScheduleConfig: Codable, Sendable, Equatable, Hashable {
    public static let defaultWakeWindowsMinutes = [150, 195]
    public static let defaultNapCapMinutes = 90
    public static let defaultShortNapThresholdMinutes = 45
    public static let defaultShortNapNextWindowMinutes = 150
    public static let defaultBackupCatnapCutoffMinutesFromMidnight = 1020 // 5:00 PM
    public static let defaultBackupCatnapDurationMinutes = 25

    /// Returns age-sensible default wake windows in minutes for a 1-to-4-nap daily schedule.
    public static func defaultWakeWindows(forNapCount count: Int) -> [Int] {
        switch min(max(count, 1), 4) {
        case 1:
            return [300]
        case 2:
            return defaultWakeWindowsMinutes
        case 3:
            return [105, 135, 150]
        default:
            return [75, 90, 90, 105]
        }
    }

    public var wakeWindowsMinutes: [Int]
    public var napCapMinutes: Int
    public var shortNapThresholdMinutes: Int
    public var shortNapNextWindowMinutes: Int
    public var backupCatnapCutoffMinutesFromMidnight: Int
    public var backupCatnapDurationMinutes: Int
    public var targetDailyMilkOzMin: Double?
    public var targetDailyMilkOzMax: Double?

    public init(
        wakeWindowsMinutes: [Int] = ScheduleConfig.defaultWakeWindowsMinutes,
        napCapMinutes: Int = ScheduleConfig.defaultNapCapMinutes,
        shortNapThresholdMinutes: Int = ScheduleConfig.defaultShortNapThresholdMinutes,
        shortNapNextWindowMinutes: Int = ScheduleConfig.defaultShortNapNextWindowMinutes,
        backupCatnapCutoffMinutesFromMidnight: Int = ScheduleConfig.defaultBackupCatnapCutoffMinutesFromMidnight,
        backupCatnapDurationMinutes: Int = ScheduleConfig.defaultBackupCatnapDurationMinutes,
        targetDailyMilkOzMin: Double? = nil,
        targetDailyMilkOzMax: Double? = nil
    ) {
        self.wakeWindowsMinutes = wakeWindowsMinutes
        self.napCapMinutes = napCapMinutes
        self.shortNapThresholdMinutes = shortNapThresholdMinutes
        self.shortNapNextWindowMinutes = shortNapNextWindowMinutes
        self.backupCatnapCutoffMinutesFromMidnight = backupCatnapCutoffMinutesFromMidnight
        self.backupCatnapDurationMinutes = backupCatnapDurationMinutes
        self.targetDailyMilkOzMin = targetDailyMilkOzMin
        self.targetDailyMilkOzMax = targetDailyMilkOzMax
    }

    enum CodingKeys: String, CodingKey {
        case wakeWindowsMinutes = "wake_windows_minutes"
        case napCapMinutes = "nap_cap_minutes"
        case shortNapThresholdMinutes = "short_nap_threshold_minutes"
        case shortNapNextWindowMinutes = "short_nap_next_window_minutes"
        case backupCatnapCutoffMinutesFromMidnight = "backup_catnap_cutoff_minutes_from_midnight"
        case backupCatnapDurationMinutes = "backup_catnap_duration_minutes"
        case targetDailyMilkOzMin = "target_daily_milk_oz_min"
        case targetDailyMilkOzMax = "target_daily_milk_oz_max"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.wakeWindowsMinutes = try container.decodeIfPresent([Int].self, forKey: .wakeWindowsMinutes)
            ?? Self.defaultWakeWindowsMinutes
        self.napCapMinutes = try container.decodeIfPresent(Int.self, forKey: .napCapMinutes)
            ?? Self.defaultNapCapMinutes
        self.shortNapThresholdMinutes = try container.decodeIfPresent(Int.self, forKey: .shortNapThresholdMinutes)
            ?? Self.defaultShortNapThresholdMinutes
        self.shortNapNextWindowMinutes = try container.decodeIfPresent(Int.self, forKey: .shortNapNextWindowMinutes)
            ?? Self.defaultShortNapNextWindowMinutes
        self.backupCatnapCutoffMinutesFromMidnight = try container.decodeIfPresent(
            Int.self,
            forKey: .backupCatnapCutoffMinutesFromMidnight
        ) ?? Self.defaultBackupCatnapCutoffMinutesFromMidnight
        self.backupCatnapDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .backupCatnapDurationMinutes)
            ?? Self.defaultBackupCatnapDurationMinutes
        self.targetDailyMilkOzMin = try container.decodeIfPresent(Double.self, forKey: .targetDailyMilkOzMin)
        self.targetDailyMilkOzMax = try container.decodeIfPresent(Double.self, forKey: .targetDailyMilkOzMax)
    }
}

public struct ProfileDTO: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var householdId: UUID
    public var displayName: String
    /// Calendar date in `YYYY-MM-DD` format.
    public var birthDate: String?
    public var defaultTimezone: String
    public var scheduleConfig: ScheduleConfig
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        householdId: UUID,
        displayName: String,
        birthDate: String? = nil,
        defaultTimezone: String = "America/Los_Angeles",
        scheduleConfig: ScheduleConfig = ScheduleConfig(),
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.householdId = householdId
        self.displayName = displayName
        self.birthDate = birthDate
        self.defaultTimezone = defaultTimezone
        self.scheduleConfig = scheduleConfig
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case displayName = "display_name"
        case birthDate = "birth_date"
        case defaultTimezone = "default_timezone"
        case scheduleConfig = "schedule_config"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }
}
