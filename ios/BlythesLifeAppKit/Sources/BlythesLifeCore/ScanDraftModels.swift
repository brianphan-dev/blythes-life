import BlythesLifeShared
import Foundation

/// A single extracted candidate row presented in the Scan Review & Confirm screen.
public struct ScanReviewDraftItem: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var id: String
    public var rowKey: String
    public var eventType: EventType
    public var startedAt: Date
    public var endedAt: Date?
    public var title: String
    public var detail: String
    public var savedDetail: String?
    public var metadata: EventMetadata
    public var notes: String?
    public var matchAction: MatchAction
    public var isSuggestion: Bool
    public var ambiguityQuestion: String?
    public var ambiguityOptions: [String]
    public var ambiguityOptionDates: [String: Date]
    public var resolvedOption: String?
    public var isIncluded: Bool
    public var boundingBox: NormalizedBoundingBox?

    public init(
        id: String,
        rowKey: String,
        eventType: EventType,
        startedAt: Date,
        endedAt: Date? = nil,
        title: String,
        detail: String,
        savedDetail: String? = nil,
        metadata: EventMetadata,
        notes: String? = nil,
        matchAction: MatchAction = .create,
        isSuggestion: Bool = false,
        ambiguityQuestion: String? = nil,
        ambiguityOptions: [String] = [],
        ambiguityOptionDates: [String: Date] = [:],
        resolvedOption: String? = nil,
        isIncluded: Bool? = nil,
        boundingBox: NormalizedBoundingBox? = nil
    ) {
        self.id = id
        self.rowKey = rowKey
        self.eventType = eventType
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.title = title
        self.detail = detail
        self.savedDetail = savedDetail
        self.metadata = metadata
        self.notes = notes
        self.matchAction = matchAction
        self.isSuggestion = isSuggestion
        self.ambiguityQuestion = ambiguityQuestion
        self.ambiguityOptions = ambiguityOptions
        self.ambiguityOptionDates = ambiguityOptionDates
        self.resolvedOption = resolvedOption
        self.isIncluded = isIncluded ?? (matchAction == .create && !isSuggestion)
        self.boundingBox = boundingBox
    }

    /// True when this draft is selected for saving and still requires a caregiver disambiguation choice.
    public var hasUnresolvedAmbiguity: Bool {
        isIncluded && !ambiguityOptions.isEmpty && resolvedOption == nil
    }

    /// The confirmed start timestamp, reflecting any chosen ambiguity option.
    public var effectiveStartedAt: Date {
        if let resolvedOption, let mapped = ambiguityOptionDates[resolvedOption] {
            return mapped
        }
        return startedAt
    }

    /// Display sort rank matching the design system review list:
    /// ambiguous first (0), new entries (1), optional suggestions (2), duplicates last (3).
    public var reviewSortRank: Int {
        if !ambiguityOptions.isEmpty { return 0 }
        if matchAction == .skipDuplicate { return 3 }
        if isSuggestion { return 2 }
        return 1
    }

    public var badgeTitle: String {
        if isSuggestion {
            return "Suggested"
        }
        switch matchAction {
        case .create: return "New"
        case .skipDuplicate: return "Already logged"
        case .updateExisting: return "Updates entry"
        }
    }

    /// Converts a server-extracted `ExtractedEventDraft` (plus optional companion suggestion) into UI review drafts.
    public static func from(
        extractedDraft: ExtractedEventDraft,
        rowKey: String,
        timeZone: TimeZone = .current,
        preferredUnit: VolumeUnit = .oz
    ) -> [ScanReviewDraftItem] {
        let syntheticEvent = EventDTO(
            id: extractedDraft.draftId,
            profileId: UUID(),
            eventType: extractedDraft.eventType,
            startedAt: extractedDraft.startedAt,
            endedAt: extractedDraft.endedAt,
            timezone: timeZone.identifier,
            notes: extractedDraft.notes,
            metadata: extractedDraft.metadata,
            source: .paperScan,
            createdBy: UUID(),
            updatedBy: UUID()
        )

        let primary = ScanReviewDraftItem(
            id: extractedDraft.draftId.uuidString,
            rowKey: rowKey,
            eventType: extractedDraft.eventType,
            startedAt: extractedDraft.startedAt,
            endedAt: extractedDraft.endedAt,
            title: FormattingHelpers.eventTitle(syntheticEvent),
            detail: FormattingHelpers.eventDetail(syntheticEvent, preferredUnit: preferredUnit, timeZone: timeZone),
            savedDetail: nil,
            metadata: extractedDraft.metadata,
            notes: extractedDraft.notes,
            matchAction: extractedDraft.matchAction,
            isSuggestion: extractedDraft.suggestedByDraftId != nil,
            ambiguityQuestion: extractedDraft.ambiguityReason,
            ambiguityOptions: [],
            ambiguityOptionDates: [:],
            resolvedOption: nil,
            isIncluded: extractedDraft.matchAction == .create && extractedDraft.suggestedByDraftId == nil,
            boundingBox: extractedDraft.boundingBox
        )

        var items = [primary]
        if let companion = extractedDraft.suggestedCompanion {
            let companionEvent = EventDTO(
                id: companion.draftId,
                profileId: UUID(),
                eventType: companion.eventType,
                startedAt: companion.startedAt,
                endedAt: companion.endedAt,
                timezone: timeZone.identifier,
                notes: companion.notes,
                metadata: companion.metadata,
                source: .paperScan,
                createdBy: UUID(),
                updatedBy: UUID()
            )
            let saved = FormattingHelpers.eventDetail(companionEvent, preferredUnit: preferredUnit, timeZone: timeZone)
            let suggestionDraft = ScanReviewDraftItem(
                id: companion.draftId.uuidString,
                rowKey: rowKey,
                eventType: companion.eventType,
                startedAt: companion.startedAt,
                endedAt: companion.endedAt,
                title: FormattingHelpers.eventTitle(companionEvent),
                detail: companion.reason ?? saved,
                savedDetail: saved,
                metadata: companion.metadata,
                notes: companion.notes,
                matchAction: .create,
                isSuggestion: true,
                ambiguityQuestion: nil,
                ambiguityOptions: [],
                ambiguityOptionDates: [:],
                resolvedOption: nil,
                isIncluded: false,
                boundingBox: extractedDraft.boundingBox
            )
            items.append(suggestionDraft)
        }
        return items
    }
}

/// Stand-in paper row descriptor for simulator/demo sheets when no camera JPEG bytes are attached.
public struct ScannedSheetLinePreview: Codable, Sendable, Identifiable, Equatable, Hashable {
    public var id: String
    public var label: String
    public var pills: [String]
    public var targetText: String?
    public var handwrittenText: String
    public var overwrittenDigits: String?

    public init(
        id: String,
        label: String,
        pills: [String] = [],
        targetText: String? = nil,
        handwrittenText: String,
        overwrittenDigits: String? = nil
    ) {
        self.id = id
        self.label = label
        self.pills = pills
        self.targetText = targetText
        self.handwrittenText = handwrittenText
        self.overwrittenDigits = overwrittenDigits
    }
}

/// A scanned paper log sheet tracked in the Sheets tab and linked to Review & Confirm.
public struct ScannedSheetRecord: Codable, Sendable, Identifiable, Equatable {
    public var id: UUID
    public var title: String
    public var subtitle: String
    public var listLabel: String
    public var scannedAt: Date
    public var status: PaperScanStatus
    public var drafts: [ScanReviewDraftItem]
    public var previewLines: [ScannedSheetLinePreview]
    public var imageData: Data?
    public var confirmedEntryCount: Int

    public init(
        id: UUID = UUID(),
        title: String,
        subtitle: String,
        listLabel: String? = nil,
        scannedAt: Date,
        status: PaperScanStatus = .pendingReview,
        drafts: [ScanReviewDraftItem] = [],
        previewLines: [ScannedSheetLinePreview] = [],
        imageData: Data? = nil,
        confirmedEntryCount: Int = 0
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.listLabel = listLabel ?? title
        self.scannedAt = scannedAt
        self.status = status
        self.drafts = drafts
        self.previewLines = previewLines
        self.imageData = imageData
        self.confirmedEntryCount = confirmedEntryCount
    }

    public var orderedDrafts: [ScanReviewDraftItem] {
        drafts.sorted { lhs, rhs in
            if lhs.reviewSortRank != rhs.reviewSortRank {
                return lhs.reviewSortRank < rhs.reviewSortRank
            }
            return lhs.startedAt < rhs.startedAt
        }
    }

    public var newDraftCount: Int {
        drafts.filter { $0.matchAction == .create && !$0.isSuggestion }.count
    }

    public var duplicateDraftCount: Int {
        drafts.filter { $0.matchAction == .skipDuplicate }.count
    }

    public var includedDraftCount: Int {
        drafts.filter(\.isIncluded).count
    }

    public var unresolvedAmbiguityCount: Int {
        drafts.filter(\.hasUnresolvedAmbiguity).count
    }

    public var canConfirm: Bool {
        includedDraftCount > 0 && unresolvedAmbiguityCount == 0
    }
}
