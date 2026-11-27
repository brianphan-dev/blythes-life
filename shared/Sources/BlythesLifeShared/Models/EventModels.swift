import Foundation

public enum EventType: String, Codable, Sendable, CaseIterable, Hashable {
    case sleep
    case feeding
    case pump
    case diaper
    case meal
    case bath
    case medicine
    case note
}

public enum EventSource: String, Codable, Sendable, CaseIterable, Hashable {
    case manual
    case paperScan = "paper_scan"
    case importHuckleberry = "import_huckleberry"
    case controlCenter = "control_center"
}

public enum SleepType: String, Codable, Sendable, CaseIterable, Hashable {
    case nap
    case night
}

public enum SleepLocation: String, Codable, Sendable, CaseIterable, Hashable {
    case crib
    case stroller
    case contact
}

public enum FeedingMethod: String, Codable, Sendable, CaseIterable, Hashable {
    case bottle
    case breast
}

public enum BreastSide: String, Codable, Sendable, CaseIterable, Hashable {
    case left
    case right
    case both
}

public enum FeedingSubstance: String, Codable, Sendable, CaseIterable, Hashable {
    case breastMilk = "breast_milk"
    case formula
    case mixed
}

public enum VolumeUnit: String, Codable, Sendable, CaseIterable, Hashable {
    case oz
    case ml
}

public enum DiaperSize: String, Codable, Sendable, CaseIterable, Hashable {
    case small = "S"
    case medium = "M"
    case large = "L"

    public var shortLabel: String { rawValue }
}

public enum PoopColor: String, Codable, Sendable, CaseIterable, Hashable {
    case yellow
    case brown
    case green
    case orange
    case black
    case red
    case pale
}

public enum PoopConsistency: String, Codable, Sendable, CaseIterable, Hashable {
    case watery
    case runny
    case seedy
    case soft
    case firm
    case hard
    case mucousy
}

public enum MealSlot: String, Codable, Sendable, CaseIterable, Hashable {
    case breakfast
    case lunch
    case dinner
    case snack
}

public enum PortionEaten: String, Codable, Sendable, CaseIterable, Hashable {
    case none
    case some
    case most
}

public enum MedicineCategory: String, Codable, Sendable, CaseIterable, Hashable {
    case medicine
    case supplement
    case topical
}

public enum DoseUnit: String, Codable, Sendable, CaseIterable, Hashable {
    case ml
    case drops
    case mg
}

// MARK: - Concrete Metadata Structs

public struct SleepMetadata: Codable, Sendable, Equatable, Hashable {
    public var sleepType: SleepType
    public var location: SleepLocation?

    public init(sleepType: SleepType = .nap, location: SleepLocation? = nil) {
        self.sleepType = sleepType
        self.location = location
    }

    enum CodingKeys: String, CodingKey {
        case sleepType = "sleep_type"
        case location
    }
}

public struct FeedingMetadata: Codable, Sendable, Equatable, Hashable {
    public var method: FeedingMethod
    public var substance: FeedingSubstance
    public var amountMl: Double?
    public var displayUnit: VolumeUnit
    public var side: BreastSide?
    public var durationMinutes: Double?
    public var leftDurationSeconds: Int?
    public var rightDurationSeconds: Int?
    public var lastSide: BreastSide?

    public init(
        method: FeedingMethod = .bottle,
        substance: FeedingSubstance = .breastMilk,
        amountMl: Double? = nil,
        displayUnit: VolumeUnit = .oz,
        side: BreastSide? = nil,
        durationMinutes: Double? = nil,
        leftDurationSeconds: Int? = nil,
        rightDurationSeconds: Int? = nil,
        lastSide: BreastSide? = nil
    ) {
        self.method = method
        self.substance = substance
        self.amountMl = amountMl
        self.displayUnit = displayUnit
        self.side = side
        self.durationMinutes = durationMinutes
        self.leftDurationSeconds = leftDurationSeconds
        self.rightDurationSeconds = rightDurationSeconds
        self.lastSide = lastSide
    }

    public init(
        method: FeedingMethod = .bottle,
        substance: FeedingSubstance = .breastMilk,
        amountOz: Double
    ) {
        self.method = method
        self.substance = substance
        self.amountMl = UnitConversion.ozToMl(amountOz)
        self.displayUnit = .oz
        self.side = nil
        self.durationMinutes = nil
        self.leftDurationSeconds = nil
        self.rightDurationSeconds = nil
        self.lastSide = nil
    }

    public var amountOz: Double? {
        amountMl.map(UnitConversion.mlToOz)
    }

    enum CodingKeys: String, CodingKey {
        case method
        case substance
        case amountMl = "amount_ml"
        case displayUnit = "display_unit"
        case side
        case durationMinutes = "duration_minutes"
        case leftDurationSeconds = "left_duration_seconds"
        case rightDurationSeconds = "right_duration_seconds"
        case lastSide = "last_side"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.method = try container.decode(FeedingMethod.self, forKey: .method)
        self.substance = try container.decode(FeedingSubstance.self, forKey: .substance)
        self.amountMl = try container.decodeIfPresent(Double.self, forKey: .amountMl)
        self.displayUnit = try container.decodeIfPresent(VolumeUnit.self, forKey: .displayUnit) ?? .oz
        self.side = try container.decodeIfPresent(BreastSide.self, forKey: .side)
        self.durationMinutes = try container.decodeIfPresent(Double.self, forKey: .durationMinutes)
        self.leftDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .leftDurationSeconds)
        self.rightDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .rightDurationSeconds)
        self.lastSide = try container.decodeIfPresent(BreastSide.self, forKey: .lastSide)
    }
}

public struct PumpMetadata: Codable, Sendable, Equatable, Hashable {
    public var amountMl: Double?
    public var displayUnit: VolumeUnit
    public var side: BreastSide
    public var durationMinutes: Double?
    public var leftAmountMl: Double?
    public var rightAmountMl: Double?
    public var leftDurationSeconds: Int?
    public var rightDurationSeconds: Int?

    public init(
        amountMl: Double? = nil,
        displayUnit: VolumeUnit = .oz,
        side: BreastSide = .both,
        durationMinutes: Double? = nil,
        leftAmountMl: Double? = nil,
        rightAmountMl: Double? = nil,
        leftDurationSeconds: Int? = nil,
        rightDurationSeconds: Int? = nil
    ) {
        self.amountMl = amountMl
        self.displayUnit = displayUnit
        self.side = side
        self.durationMinutes = durationMinutes
        self.leftAmountMl = leftAmountMl
        self.rightAmountMl = rightAmountMl
        self.leftDurationSeconds = leftDurationSeconds
        self.rightDurationSeconds = rightDurationSeconds
    }

    public init(
        amountOz: Double,
        side: BreastSide = .both,
        durationMinutes: Double? = nil,
        leftAmountOz: Double? = nil,
        rightAmountOz: Double? = nil,
        leftDurationSeconds: Int? = nil,
        rightDurationSeconds: Int? = nil
    ) {
        self.amountMl = UnitConversion.ozToMl(amountOz)
        self.displayUnit = .oz
        self.side = side
        self.durationMinutes = durationMinutes
        self.leftAmountMl = leftAmountOz.map(UnitConversion.ozToMl)
        self.rightAmountMl = rightAmountOz.map(UnitConversion.ozToMl)
        self.leftDurationSeconds = leftDurationSeconds
        self.rightDurationSeconds = rightDurationSeconds
    }

    public var amountOz: Double? {
        amountMl.map(UnitConversion.mlToOz)
    }

    public var leftAmountOz: Double? {
        leftAmountMl.map(UnitConversion.mlToOz)
    }

    public var rightAmountOz: Double? {
        rightAmountMl.map(UnitConversion.mlToOz)
    }

    enum CodingKeys: String, CodingKey {
        case amountMl = "amount_ml"
        case displayUnit = "display_unit"
        case side
        case durationMinutes = "duration_minutes"
        case leftAmountMl = "left_amount_ml"
        case rightAmountMl = "right_amount_ml"
        case leftDurationSeconds = "left_duration_seconds"
        case rightDurationSeconds = "right_duration_seconds"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.amountMl = try container.decodeIfPresent(Double.self, forKey: .amountMl)
        self.displayUnit = try container.decodeIfPresent(VolumeUnit.self, forKey: .displayUnit) ?? .oz
        self.side = try container.decodeIfPresent(BreastSide.self, forKey: .side) ?? .both
        self.durationMinutes = try container.decodeIfPresent(Double.self, forKey: .durationMinutes)
        self.leftAmountMl = try container.decodeIfPresent(Double.self, forKey: .leftAmountMl)
        self.rightAmountMl = try container.decodeIfPresent(Double.self, forKey: .rightAmountMl)
        self.leftDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .leftDurationSeconds)
        self.rightDurationSeconds = try container.decodeIfPresent(Int.self, forKey: .rightDurationSeconds)
    }
}

public struct DiaperMetadata: Codable, Sendable, Equatable, Hashable {
    public var peeSize: DiaperSize?
    public var poopSize: DiaperSize?
    public var rash: Bool
    public var poopColor: PoopColor?
    public var poopConsistency: PoopConsistency?

    public init(
        peeSize: DiaperSize? = nil,
        poopSize: DiaperSize? = nil,
        rash: Bool = false,
        poopColor: PoopColor? = nil,
        poopConsistency: PoopConsistency? = nil
    ) {
        self.peeSize = peeSize
        self.poopSize = poopSize
        self.rash = rash
        self.poopColor = poopColor
        self.poopConsistency = poopConsistency
    }

    enum CodingKeys: String, CodingKey {
        case peeSize = "pee_size"
        case poopSize = "poop_size"
        case rash
        case poopColor = "poop_color"
        case poopConsistency = "poop_consistency"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.peeSize = try container.decodeIfPresent(DiaperSize.self, forKey: .peeSize)
        self.poopSize = try container.decodeIfPresent(DiaperSize.self, forKey: .poopSize)
        self.rash = try container.decodeIfPresent(Bool.self, forKey: .rash) ?? false
        self.poopColor = try container.decodeIfPresent(PoopColor.self, forKey: .poopColor)
        self.poopConsistency = try container.decodeIfPresent(PoopConsistency.self, forKey: .poopConsistency)
    }
}

public struct MealMetadata: Codable, Sendable, Equatable, Hashable {
    public var mealSlot: MealSlot?
    public var portionEaten: PortionEaten?

    public init(mealSlot: MealSlot? = nil, portionEaten: PortionEaten? = nil) {
        self.mealSlot = mealSlot
        self.portionEaten = portionEaten
    }

    enum CodingKeys: String, CodingKey {
        case mealSlot = "meal_slot"
        case portionEaten = "portion_eaten"
    }
}

public struct BathMetadata: Codable, Sendable, Equatable, Hashable {
    public var washedHair: Bool

    public init(washedHair: Bool = false) {
        self.washedHair = washedHair
    }

    enum CodingKeys: String, CodingKey {
        case washedHair = "washed_hair"
    }
}

public struct MedicineMetadata: Codable, Sendable, Equatable, Hashable {
    public var name: String
    public var category: MedicineCategory
    public var dose: Double?
    public var unit: DoseUnit?

    public init(
        name: String,
        category: MedicineCategory,
        dose: Double? = nil,
        unit: DoseUnit? = nil
    ) {
        self.name = name
        self.category = category
        self.dose = dose
        self.unit = unit
    }

    enum CodingKeys: String, CodingKey {
        case name
        case category
        case dose
        case unit
    }
}

public struct NoteMetadata: Codable, Sendable, Equatable, Hashable {
    public init() {}
}

// MARK: - EventMetadata Union

/// Type-safe flat JSON representation matching canonical `events.metadata` JSONB conventions.
public enum EventMetadata: Codable, Sendable, Equatable, Hashable {
    case sleep(SleepMetadata)
    case feeding(FeedingMetadata)
    case pump(PumpMetadata)
    case diaper(DiaperMetadata)
    case meal(MealMetadata)
    case bath(BathMetadata)
    case medicine(MedicineMetadata)
    case note(NoteMetadata)

    public var eventType: EventType {
        switch self {
        case .sleep: .sleep
        case .feeding: .feeding
        case .pump: .pump
        case .diaper: .diaper
        case .meal: .meal
        case .bath: .bath
        case .medicine: .medicine
        case .note: .note
        }
    }

    private enum DiscriminatorKeys: String, CodingKey {
        case sleepType = "sleep_type"
        case method
        case substance
        case side
        case lastSide = "last_side"
        case amountMl = "amount_ml"
        case leftAmountMl = "left_amount_ml"
        case rightAmountMl = "right_amount_ml"
        case displayUnit = "display_unit"
        case peeSize = "pee_size"
        case poopSize = "poop_size"
        case poopColor = "poop_color"
        case poopConsistency = "poop_consistency"
        case rash
        case mealSlot = "meal_slot"
        case portionEaten = "portion_eaten"
        case washedHair = "washed_hair"
        case name
        case category
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: DiscriminatorKeys.self)

        if container.contains(.sleepType) {
            self = .sleep(try SleepMetadata(from: decoder))
        } else if container.contains(.method) || container.contains(.substance) || container.contains(.lastSide) {
            self = .feeding(try FeedingMetadata(from: decoder))
        } else if container.contains(.side) || container.contains(.leftAmountMl) || container.contains(.rightAmountMl) {
            self = .pump(try PumpMetadata(from: decoder))
        } else if container.contains(.amountMl) || container.contains(.displayUnit) {
            self = .feeding(try FeedingMetadata(from: decoder))
        } else if container.contains(.washedHair) {
            self = .bath(try BathMetadata(from: decoder))
        } else if container.contains(.name) || container.contains(.category) {
            self = .medicine(try MedicineMetadata(from: decoder))
        } else if container.contains(.peeSize) || container.contains(.poopSize) || container.contains(.poopColor) || container.contains(.poopConsistency) || container.contains(.rash) {
            self = .diaper(try DiaperMetadata(from: decoder))
        } else if container.contains(.mealSlot) || container.contains(.portionEaten) {
            self = .meal(try MealMetadata(from: decoder))
        } else {
            self = .note(NoteMetadata())
        }
    }

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .sleep(let metadata):
            try metadata.encode(to: encoder)
        case .feeding(let metadata):
            try metadata.encode(to: encoder)
        case .pump(let metadata):
            try metadata.encode(to: encoder)
        case .diaper(let metadata):
            try metadata.encode(to: encoder)
        case .meal(let metadata):
            try metadata.encode(to: encoder)
        case .bath(let metadata):
            try metadata.encode(to: encoder)
        case .medicine(let metadata):
            try metadata.encode(to: encoder)
        case .note(let metadata):
            try metadata.encode(to: encoder)
        }
    }

    /// Decodes a flat metadata JSON payload using the authoritative sibling `EventType`.
    public static func decode(
        from data: Data,
        as eventType: EventType,
        using decoder: JSONDecoder = BlythesLifeJSONCoding.makeDecoder()
    ) throws -> EventMetadata {
        switch eventType {
        case .sleep:
            .sleep(try decoder.decode(SleepMetadata.self, from: data))
        case .feeding:
            .feeding(try decoder.decode(FeedingMetadata.self, from: data))
        case .pump:
            .pump(try decoder.decode(PumpMetadata.self, from: data))
        case .diaper:
            .diaper(try decoder.decode(DiaperMetadata.self, from: data))
        case .meal:
            .meal(try decoder.decode(MealMetadata.self, from: data))
        case .bath:
            .bath(try decoder.decode(BathMetadata.self, from: data))
        case .medicine:
            .medicine(try decoder.decode(MedicineMetadata.self, from: data))
        case .note:
            .note(try decoder.decode(NoteMetadata.self, from: data))
        }
    }

    static func decode<K: CodingKey>(
        from container: KeyedDecodingContainer<K>,
        forKey key: K,
        eventType: EventType
    ) throws -> EventMetadata {
        switch eventType {
        case .sleep:
            .sleep(try container.decode(SleepMetadata.self, forKey: key))
        case .feeding:
            .feeding(try container.decode(FeedingMetadata.self, forKey: key))
        case .pump:
            .pump(try container.decode(PumpMetadata.self, forKey: key))
        case .diaper:
            .diaper(try container.decode(DiaperMetadata.self, forKey: key))
        case .meal:
            .meal(try container.decode(MealMetadata.self, forKey: key))
        case .bath:
            .bath(try container.decode(BathMetadata.self, forKey: key))
        case .medicine:
            .medicine(try container.decode(MedicineMetadata.self, forKey: key))
        case .note:
            .note((try container.decodeIfPresent(NoteMetadata.self, forKey: key)) ?? NoteMetadata())
        }
    }
}

// MARK: - EventDTO

public struct EventDTO: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var profileId: UUID
    public var eventType: EventType
    public var startedAt: Date
    public var endedAt: Date?
    public var timezone: String
    public var notes: String?
    public var metadata: EventMetadata
    public var source: EventSource
    public var scanId: UUID?
    public var externalId: String?
    public var createdBy: UUID
    public var updatedBy: UUID
    public var createdAt: Date
    public var updatedAt: Date
    public var deletedAt: Date?

    public init(
        id: UUID = UUID(),
        profileId: UUID,
        eventType: EventType,
        startedAt: Date,
        endedAt: Date? = nil,
        timezone: String,
        notes: String? = nil,
        metadata: EventMetadata,
        source: EventSource = .manual,
        scanId: UUID? = nil,
        externalId: String? = nil,
        createdBy: UUID,
        updatedBy: UUID,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        deletedAt: Date? = nil
    ) {
        self.id = id
        self.profileId = profileId
        self.eventType = eventType
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.timezone = timezone
        self.notes = notes
        self.metadata = metadata
        self.source = source
        self.scanId = scanId
        self.externalId = externalId
        self.createdBy = createdBy
        self.updatedBy = updatedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.deletedAt = deletedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case eventType = "event_type"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case timezone
        case notes
        case metadata
        case source
        case scanId = "scan_id"
        case externalId = "external_id"
        case createdBy = "created_by"
        case updatedBy = "updated_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.profileId = try container.decode(UUID.self, forKey: .profileId)
        let eventType = try container.decode(EventType.self, forKey: .eventType)
        self.eventType = eventType
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        self.timezone = try container.decode(String.self, forKey: .timezone)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.metadata = try EventMetadata.decode(from: container, forKey: .metadata, eventType: eventType)
        self.source = try container.decode(EventSource.self, forKey: .source)
        self.scanId = try container.decodeIfPresent(UUID.self, forKey: .scanId)
        self.externalId = try container.decodeIfPresent(String.self, forKey: .externalId)
        self.createdBy = try container.decode(UUID.self, forKey: .createdBy)
        self.updatedBy = try container.decode(UUID.self, forKey: .updatedBy)
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.deletedAt = try container.decodeIfPresent(Date.self, forKey: .deletedAt)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(profileId, forKey: .profileId)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encode(timezone, forKey: .timezone)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(source, forKey: .source)
        try container.encodeIfPresent(scanId, forKey: .scanId)
        try container.encodeIfPresent(externalId, forKey: .externalId)
        try container.encode(createdBy, forKey: .createdBy)
        try container.encode(updatedBy, forKey: .updatedBy)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(updatedAt, forKey: .updatedAt)
        try container.encodeIfPresent(deletedAt, forKey: .deletedAt)
    }
}
