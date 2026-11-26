import Foundation

public enum IdentityProvider: String, Codable, Sendable, CaseIterable, Hashable {
    case apple
    case google
}

public struct UserDTO: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var displayName: String
    public var primaryEmail: String?
    public var createdAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        displayName: String,
        primaryEmail: String? = nil,
        createdAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.primaryEmail = primaryEmail
        self.createdAt = createdAt
        self.deletedAt = deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case primaryEmail = "primary_email"
        case createdAt = "created_at"
        case deletedAt = "deleted_at"
    }
}

public struct AppleAuthRequest: Codable, Sendable, Equatable, Hashable {
    public var identityToken: String
    public var rawNonce: String
    public var authorizationCode: String?
    public var displayName: String?
    public var deviceId: String
    public var deviceName: String
    public var platform: String

    public init(
        identityToken: String,
        rawNonce: String,
        authorizationCode: String? = nil,
        displayName: String? = nil,
        deviceId: String,
        deviceName: String,
        platform: String
    ) {
        self.identityToken = identityToken
        self.rawNonce = rawNonce
        self.authorizationCode = authorizationCode
        self.displayName = displayName
        self.deviceId = deviceId
        self.deviceName = deviceName
        self.platform = platform
    }

    enum CodingKeys: String, CodingKey {
        case identityToken = "identity_token"
        case rawNonce = "raw_nonce"
        case authorizationCode = "authorization_code"
        case displayName = "display_name"
        case deviceId = "device_id"
        case deviceName = "device_name"
        case platform
    }
}

public struct RefreshTokenRequest: Codable, Sendable, Equatable, Hashable {
    public var refreshToken: String
    public var deviceId: String

    public init(refreshToken: String, deviceId: String) {
        self.refreshToken = refreshToken
        self.deviceId = deviceId
    }

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case deviceId = "device_id"
    }
}

public struct LogoutRequest: Codable, Sendable, Equatable, Hashable {
    public var refreshToken: String?
    public var deviceId: String?
    public var revokeAllDevices: Bool

    public init(
        refreshToken: String? = nil,
        deviceId: String? = nil,
        revokeAllDevices: Bool = false
    ) {
        self.refreshToken = refreshToken
        self.deviceId = deviceId
        self.revokeAllDevices = revokeAllDevices
    }

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
        case deviceId = "device_id"
        case revokeAllDevices = "revoke_all_devices"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.refreshToken = try container.decodeIfPresent(String.self, forKey: .refreshToken)
        self.deviceId = try container.decodeIfPresent(String.self, forKey: .deviceId)
        self.revokeAllDevices = try container.decodeIfPresent(Bool.self, forKey: .revokeAllDevices) ?? false
    }
}

public struct AuthSessionResponse: Codable, Sendable, Equatable, Hashable {
    public var accessToken: String
    public var expiresIn: Int
    public var refreshToken: String
    public var user: UserDTO
    public var households: [HouseholdDTO]

    public init(
        accessToken: String,
        expiresIn: Int,
        refreshToken: String,
        user: UserDTO,
        households: [HouseholdDTO]
    ) {
        self.accessToken = accessToken
        self.expiresIn = expiresIn
        self.refreshToken = refreshToken
        self.user = user
        self.households = households
    }

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case expiresIn = "expires_in"
        case refreshToken = "refresh_token"
        case user
        case households
    }
}

public struct CreateHouseholdRequest: Codable, Sendable, Equatable, Hashable {
    public var name: String

    public init(name: String) {
        self.name = name
    }
}

public struct JoinHouseholdRequest: Codable, Sendable, Equatable, Hashable {
    public var inviteCode: String
    public var displayName: String?

    public init(inviteCode: String, displayName: String? = nil) {
        self.inviteCode = inviteCode
        self.displayName = displayName
    }

    enum CodingKeys: String, CodingKey {
        case inviteCode = "invite_code"
        case displayName = "display_name"
    }
}

public struct CreateProfileRequest: Codable, Sendable, Equatable, Hashable {
    public var id: UUID?
    public var householdId: UUID
    public var displayName: String
    public var birthDate: String?
    public var defaultTimezone: String
    public var scheduleConfig: ScheduleConfig?

    public init(
        id: UUID? = nil,
        householdId: UUID,
        displayName: String,
        birthDate: String? = nil,
        defaultTimezone: String = "America/Los_Angeles",
        scheduleConfig: ScheduleConfig? = nil
    ) {
        self.id = id
        self.householdId = householdId
        self.displayName = displayName
        self.birthDate = birthDate
        self.defaultTimezone = defaultTimezone
        self.scheduleConfig = scheduleConfig
    }

    enum CodingKeys: String, CodingKey {
        case id
        case householdId = "household_id"
        case displayName = "display_name"
        case birthDate = "birth_date"
        case defaultTimezone = "default_timezone"
        case scheduleConfig = "schedule_config"
    }
}

public struct UpdateProfileRequest: Codable, Sendable, Equatable, Hashable {
    public var displayName: String?
    public var birthDate: String?
    public var defaultTimezone: String?
    public var scheduleConfig: ScheduleConfig?

    public init(
        displayName: String? = nil,
        birthDate: String? = nil,
        defaultTimezone: String? = nil,
        scheduleConfig: ScheduleConfig? = nil
    ) {
        self.displayName = displayName
        self.birthDate = birthDate
        self.defaultTimezone = defaultTimezone
        self.scheduleConfig = scheduleConfig
    }

    enum CodingKeys: String, CodingKey {
        case displayName = "display_name"
        case birthDate = "birth_date"
        case defaultTimezone = "default_timezone"
        case scheduleConfig = "schedule_config"
    }
}
