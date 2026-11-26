import Foundation

public enum PaperScanStatus: String, Codable, Sendable, CaseIterable, Hashable {
    case pendingReview = "pending_review"
    case confirmed
    case discarded
}

public enum ConfidenceLevel: String, Codable, Sendable, CaseIterable, Hashable {
    case high
    case medium
    case low
}

public enum MatchAction: String, Codable, Sendable, CaseIterable, Hashable {
    case create
    case skipDuplicate = "skip_duplicate"
    case updateExisting = "update_existing"
}

/// Normalized bounding box (`0.0...1.0`) in top-left image coordinates.
public struct NormalizedBoundingBox: Codable, Sendable, Equatable, Hashable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

/// Non-recursive companion event suggestion (e.g., `+ VIT D` supplement paired with a bottle row).
public struct CompanionSuggestion: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var draftId: UUID
    public var eventType: EventType
    public var startedAt: Date
    public var endedAt: Date?
    public var notes: String?
    public var metadata: EventMetadata
    public var reason: String?
    public var isSelectedByDefault: Bool

    public var id: UUID { draftId }

    public init(
        draftId: UUID = UUID(),
        eventType: EventType,
        startedAt: Date,
        endedAt: Date? = nil,
        notes: String? = nil,
        metadata: EventMetadata,
        reason: String? = nil,
        isSelectedByDefault: Bool = true
    ) {
        self.draftId = draftId
        self.eventType = eventType
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.notes = notes
        self.metadata = metadata
        self.reason = reason
        self.isSelectedByDefault = isSelectedByDefault
    }

    enum CodingKeys: String, CodingKey {
        case draftId = "draft_id"
        case eventType = "event_type"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case notes
        case metadata
        case reason
        case isSelectedByDefault = "is_selected_by_default"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.draftId = try container.decodeIfPresent(UUID.self, forKey: .draftId) ?? UUID()
        let eventType = try container.decode(EventType.self, forKey: .eventType)
        self.eventType = eventType
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.metadata = try EventMetadata.decode(from: container, forKey: .metadata, eventType: eventType)
        self.reason = try container.decodeIfPresent(String.self, forKey: .reason)
        self.isSelectedByDefault = try container.decodeIfPresent(Bool.self, forKey: .isSelectedByDefault) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(draftId, forKey: .draftId)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(metadata, forKey: .metadata)
        try container.encodeIfPresent(reason, forKey: .reason)
        try container.encode(isSelectedByDefault, forKey: .isSelectedByDefault)
    }

    public func toDraft(
        confidence: ConfidenceLevel = .medium,
        rawOcrText: String? = nil,
        boundingBox: NormalizedBoundingBox? = nil,
        suggestedByDraftId: UUID? = nil
    ) -> ExtractedEventDraft {
        ExtractedEventDraft(
            draftId: draftId,
            eventType: eventType,
            startedAt: startedAt,
            endedAt: endedAt,
            notes: notes,
            metadata: metadata,
            confidence: confidence,
            ambiguityReason: reason,
            rawOcrText: rawOcrText,
            boundingBox: boundingBox,
            matchAction: .create,
            matchedEventId: nil,
            suggestedCompanion: nil,
            suggestedByDraftId: suggestedByDraftId
        )
    }
}

public struct ExtractedEventDraft: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var draftId: UUID
    public var eventType: EventType
    public var startedAt: Date
    public var endedAt: Date?
    public var notes: String?
    public var metadata: EventMetadata
    public var confidence: ConfidenceLevel
    public var ambiguityReason: String?
    public var rawOcrText: String?
    public var boundingBox: NormalizedBoundingBox?
    public var matchAction: MatchAction
    public var matchedEventId: UUID?
    public var suggestedCompanion: CompanionSuggestion?
    public var suggestedByDraftId: UUID?

    public var id: UUID { draftId }

    public init(
        draftId: UUID = UUID(),
        eventType: EventType,
        startedAt: Date,
        endedAt: Date? = nil,
        notes: String? = nil,
        metadata: EventMetadata,
        confidence: ConfidenceLevel = .high,
        ambiguityReason: String? = nil,
        rawOcrText: String? = nil,
        boundingBox: NormalizedBoundingBox? = nil,
        matchAction: MatchAction = .create,
        matchedEventId: UUID? = nil,
        suggestedCompanion: CompanionSuggestion? = nil,
        suggestedByDraftId: UUID? = nil
    ) {
        self.draftId = draftId
        self.eventType = eventType
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.notes = notes
        self.metadata = metadata
        self.confidence = confidence
        self.ambiguityReason = ambiguityReason
        self.rawOcrText = rawOcrText
        self.boundingBox = boundingBox
        self.matchAction = matchAction
        self.matchedEventId = matchedEventId
        self.suggestedCompanion = suggestedCompanion
        self.suggestedByDraftId = suggestedByDraftId
    }

    enum CodingKeys: String, CodingKey {
        case draftId = "draft_id"
        case eventType = "event_type"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case notes
        case metadata
        case confidence
        case ambiguityReason = "ambiguity_reason"
        case rawOcrText = "raw_ocr_text"
        case boundingBox = "bounding_box"
        case matchAction = "match_action"
        case matchedEventId = "matched_event_id"
        case suggestedCompanion = "suggested_companion"
        case companionSuggestion = "companion_suggestion"
        case suggestedByDraftId = "suggested_by_draft_id"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.draftId = try container.decodeIfPresent(UUID.self, forKey: .draftId) ?? UUID()
        let eventType = try container.decode(EventType.self, forKey: .eventType)
        self.eventType = eventType
        self.startedAt = try container.decode(Date.self, forKey: .startedAt)
        self.endedAt = try container.decodeIfPresent(Date.self, forKey: .endedAt)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
        self.metadata = try EventMetadata.decode(from: container, forKey: .metadata, eventType: eventType)
        self.confidence = try container.decodeIfPresent(ConfidenceLevel.self, forKey: .confidence) ?? .medium
        self.ambiguityReason = try container.decodeIfPresent(String.self, forKey: .ambiguityReason)
        self.rawOcrText = try container.decodeIfPresent(String.self, forKey: .rawOcrText)
        self.boundingBox = try container.decodeIfPresent(NormalizedBoundingBox.self, forKey: .boundingBox)
        self.matchAction = try container.decodeIfPresent(MatchAction.self, forKey: .matchAction) ?? .create
        self.matchedEventId = try container.decodeIfPresent(UUID.self, forKey: .matchedEventId)
        if let suggested = try container.decodeIfPresent(CompanionSuggestion.self, forKey: .suggestedCompanion) {
            self.suggestedCompanion = suggested
        } else {
            self.suggestedCompanion = try container.decodeIfPresent(CompanionSuggestion.self, forKey: .companionSuggestion)
        }
        self.suggestedByDraftId = try container.decodeIfPresent(UUID.self, forKey: .suggestedByDraftId)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(draftId, forKey: .draftId)
        try container.encode(eventType, forKey: .eventType)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encodeIfPresent(endedAt, forKey: .endedAt)
        try container.encodeIfPresent(notes, forKey: .notes)
        try container.encode(metadata, forKey: .metadata)
        try container.encode(confidence, forKey: .confidence)
        try container.encodeIfPresent(ambiguityReason, forKey: .ambiguityReason)
        try container.encodeIfPresent(rawOcrText, forKey: .rawOcrText)
        try container.encodeIfPresent(boundingBox, forKey: .boundingBox)
        try container.encode(matchAction, forKey: .matchAction)
        try container.encodeIfPresent(matchedEventId, forKey: .matchedEventId)
        try container.encodeIfPresent(suggestedCompanion, forKey: .suggestedCompanion)
        try container.encodeIfPresent(suggestedByDraftId, forKey: .suggestedByDraftId)
    }
}

public struct PaperScanExtraction: Codable, Sendable, Equatable, Hashable {
    /// Detected sheet date in `YYYY-MM-DD` format if legible on the page.
    public var detectedDate: String?
    public var timezone: String
    public var sheetNotes: String?
    public var ignoredTargetNotes: [String]
    public var events: [ExtractedEventDraft]

    public init(
        detectedDate: String? = nil,
        timezone: String,
        sheetNotes: String? = nil,
        ignoredTargetNotes: [String] = [],
        events: [ExtractedEventDraft] = []
    ) {
        self.detectedDate = detectedDate
        self.timezone = timezone
        self.sheetNotes = sheetNotes
        self.ignoredTargetNotes = ignoredTargetNotes
        self.events = events
    }

    enum CodingKeys: String, CodingKey {
        case detectedDate = "detected_date"
        case timezone
        case sheetNotes = "sheet_notes"
        case ignoredTargetNotes = "ignored_target_notes"
        case events
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.detectedDate = try container.decodeIfPresent(String.self, forKey: .detectedDate)
        self.timezone = try container.decode(String.self, forKey: .timezone)
        self.sheetNotes = try container.decodeIfPresent(String.self, forKey: .sheetNotes)
        self.ignoredTargetNotes = try container.decodeIfPresent([String].self, forKey: .ignoredTargetNotes) ?? []
        self.events = try container.decodeIfPresent([ExtractedEventDraft].self, forKey: .events) ?? []
    }
}

public struct PaperScanDTO: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var id: UUID
    public var profileId: UUID
    /// Calendar date in `YYYY-MM-DD` format.
    public var scanDate: String
    public var timezone: String
    public var storageKey: String
    public var imageUrl: String?
    public var modelId: String?
    public var rawExtraction: PaperScanExtraction?
    public var sheetNotes: String?
    public var status: PaperScanStatus
    public var scannedBy: UUID
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        profileId: UUID,
        scanDate: String,
        timezone: String,
        storageKey: String,
        imageUrl: String? = nil,
        modelId: String? = nil,
        rawExtraction: PaperScanExtraction? = nil,
        sheetNotes: String? = nil,
        status: PaperScanStatus = .pendingReview,
        scannedBy: UUID,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.profileId = profileId
        self.scanDate = scanDate
        self.timezone = timezone
        self.storageKey = storageKey
        self.imageUrl = imageUrl
        self.modelId = modelId
        self.rawExtraction = rawExtraction
        self.sheetNotes = sheetNotes
        self.status = status
        self.scannedBy = scannedBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    enum CodingKeys: String, CodingKey {
        case id
        case profileId = "profile_id"
        case scanDate = "scan_date"
        case timezone
        case storageKey = "storage_key"
        case imageUrl = "image_url"
        case modelId = "model_id"
        case rawExtraction = "raw_extraction"
        case sheetNotes = "sheet_notes"
        case status
        case scannedBy = "scanned_by"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

public struct PresignUploadRequest: Codable, Sendable, Equatable, Hashable {
    public var profileId: UUID
    public var contentType: String
    public var fileSizeBytes: Int?

    public init(
        profileId: UUID,
        contentType: String = "image/jpeg",
        fileSizeBytes: Int? = nil
    ) {
        self.profileId = profileId
        self.contentType = contentType
        self.fileSizeBytes = fileSizeBytes
    }

    enum CodingKeys: String, CodingKey {
        case profileId = "profile_id"
        case contentType = "content_type"
        case fileSizeBytes = "file_size_bytes"
    }
}

public struct PresignUploadResponse: Codable, Sendable, Equatable, Hashable {
    public var scanId: UUID
    public var storageKey: String
    public var uploadUrl: String
    public var uploadHeaders: [String: String]
    public var expiresAt: Date

    public init(
        scanId: UUID,
        storageKey: String,
        uploadUrl: String,
        uploadHeaders: [String: String] = [:],
        expiresAt: Date
    ) {
        self.scanId = scanId
        self.storageKey = storageKey
        self.uploadUrl = uploadUrl
        self.uploadHeaders = uploadHeaders
        self.expiresAt = expiresAt
    }

    enum CodingKeys: String, CodingKey {
        case scanId = "scan_id"
        case storageKey = "storage_key"
        case uploadUrl = "upload_url"
        case uploadHeaders = "upload_headers"
        case expiresAt = "expires_at"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.scanId = try container.decode(UUID.self, forKey: .scanId)
        self.storageKey = try container.decode(String.self, forKey: .storageKey)
        self.uploadUrl = try container.decode(String.self, forKey: .uploadUrl)
        self.uploadHeaders = try container.decodeIfPresent([String: String].self, forKey: .uploadHeaders) ?? [:]
        self.expiresAt = try container.decode(Date.self, forKey: .expiresAt)
    }
}

public struct ExtractPaperScanRequest: Codable, Sendable, Equatable, Hashable {
    public var scanId: UUID
    public var profileId: UUID
    public var storageKey: String
    /// Optional calendar date hint (`YYYY-MM-DD`).
    public var scanDate: String?
    public var timezone: String

    public init(
        scanId: UUID,
        profileId: UUID,
        storageKey: String,
        scanDate: String? = nil,
        timezone: String
    ) {
        self.scanId = scanId
        self.profileId = profileId
        self.storageKey = storageKey
        self.scanDate = scanDate
        self.timezone = timezone
    }

    enum CodingKeys: String, CodingKey {
        case scanId = "scan_id"
        case profileId = "profile_id"
        case storageKey = "storage_key"
        case scanDate = "scan_date"
        case timezone
    }
}

public struct ConfirmPaperScanRequest: Codable, Sendable, Equatable, Hashable {
    public var scanId: UUID
    public var profileId: UUID
    /// Confirmed sheet date (`YYYY-MM-DD`).
    public var scanDate: String
    public var sheetNotes: String?
    public var events: [EventDTO]
    public var status: PaperScanStatus

    public init(
        scanId: UUID,
        profileId: UUID,
        scanDate: String,
        sheetNotes: String? = nil,
        events: [EventDTO],
        status: PaperScanStatus = .confirmed
    ) {
        self.scanId = scanId
        self.profileId = profileId
        self.scanDate = scanDate
        self.sheetNotes = sheetNotes
        self.events = events
        self.status = status
    }

    enum CodingKeys: String, CodingKey {
        case scanId = "scan_id"
        case profileId = "profile_id"
        case scanDate = "scan_date"
        case sheetNotes = "sheet_notes"
        case events
        case status
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.scanId = try container.decode(UUID.self, forKey: .scanId)
        self.profileId = try container.decode(UUID.self, forKey: .profileId)
        self.scanDate = try container.decode(String.self, forKey: .scanDate)
        self.sheetNotes = try container.decodeIfPresent(String.self, forKey: .sheetNotes)
        self.events = try container.decode([EventDTO].self, forKey: .events)
        self.status = try container.decodeIfPresent(PaperScanStatus.self, forKey: .status) ?? .confirmed
    }
}
