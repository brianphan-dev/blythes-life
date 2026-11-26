import Foundation

public struct SyncPushRequest: Codable, Sendable, Equatable, Hashable {
    public var events: [EventDTO]
    public var profiles: [ProfileDTO]?

    public init(events: [EventDTO] = [], profiles: [ProfileDTO]? = nil) {
        self.events = events
        self.profiles = profiles
    }
}

public struct SyncRejectedItem: Codable, Sendable, Equatable, Hashable {
    public var id: UUID
    public var reason: String

    public init(id: UUID, reason: String) {
        self.id = id
        self.reason = reason
    }
}

public struct SyncPushResponse: Codable, Sendable, Equatable, Hashable {
    public var acceptedEventIds: [UUID]
    public var acceptedProfileIds: [UUID]
    public var rejected: [SyncRejectedItem]
    public var serverWatermark: Date

    public init(
        acceptedEventIds: [UUID],
        acceptedProfileIds: [UUID],
        rejected: [SyncRejectedItem] = [],
        serverWatermark: Date
    ) {
        self.acceptedEventIds = acceptedEventIds
        self.acceptedProfileIds = acceptedProfileIds
        self.rejected = rejected
        self.serverWatermark = serverWatermark
    }

    enum CodingKeys: String, CodingKey {
        case acceptedEventIds = "accepted_event_ids"
        case acceptedProfileIds = "accepted_profile_ids"
        case rejected
        case serverWatermark = "server_watermark"
    }
}

public struct SyncPullResponse: Codable, Sendable, Equatable, Hashable {
    public var events: [EventDTO]
    public var profiles: [ProfileDTO]
    public var serverWatermark: Date
    public var hasMore: Bool

    public init(
        events: [EventDTO],
        profiles: [ProfileDTO],
        serverWatermark: Date,
        hasMore: Bool
    ) {
        self.events = events
        self.profiles = profiles
        self.serverWatermark = serverWatermark
        self.hasMore = hasMore
    }

    enum CodingKeys: String, CodingKey {
        case events
        case profiles
        case serverWatermark = "server_watermark"
        case hasMore = "has_more"
    }
}

public struct SyncStreamNotification: Codable, Sendable, Equatable, Hashable {
    public var householdId: UUID
    public var profileId: UUID?
    public var entityType: String
    public var entityId: UUID
    public var updatedAt: Date

    public init(
        householdId: UUID,
        profileId: UUID? = nil,
        entityType: String,
        entityId: UUID,
        updatedAt: Date
    ) {
        self.householdId = householdId
        self.profileId = profileId
        self.entityType = entityType
        self.entityId = entityId
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case householdId = "household_id"
        case profileId = "profile_id"
        case entityType = "entity_type"
        case entityId = "entity_id"
        case updatedAt = "updated_at"
    }
}
