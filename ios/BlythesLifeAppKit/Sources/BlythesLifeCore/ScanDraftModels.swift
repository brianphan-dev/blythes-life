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
    public var matchedEventId: UUID?

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
        boundingBox: NormalizedBoundingBox? = nil,
        matchedEventId: UUID? = nil
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
        self.isIncluded = isIncluded ?? ((matchAction == .create || matchAction == .updateExisting) && !isSuggestion)
        self.boundingBox = boundingBox
        self.matchedEventId = matchedEventId
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
        var scanCalendar = Calendar(identifier: .gregorian)
        scanCalendar.timeZone = timeZone

        let normalizedMetadata = Self.resolvedMetadata(
            extractedDraft.metadata,
            startedAt: extractedDraft.startedAt,
            calendar: scanCalendar
        )

        let syntheticEvent = EventDTO(
            id: extractedDraft.draftId,
            profileId: UUID(),
            eventType: extractedDraft.eventType,
            startedAt: extractedDraft.startedAt,
            endedAt: extractedDraft.endedAt,
            timezone: timeZone.identifier,
            notes: extractedDraft.notes,
            metadata: normalizedMetadata,
            source: .paperScan,
            createdBy: UUID(),
            updatedBy: UUID()
        )

        let trimmedAmbiguity = extractedDraft.ambiguityReason?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let ambiguityQuestion = (trimmedAmbiguity?.isEmpty == false) ? trimmedAmbiguity : nil
        let (ambiguityOptions, ambiguityOptionDates) = Self.parseAmbiguityOptions(
            question: ambiguityQuestion,
            confidence: extractedDraft.confidence,
            anchorDate: extractedDraft.startedAt,
            timeZone: timeZone
        )

        let shouldIncludePrimary =
            (extractedDraft.matchAction == .create || extractedDraft.matchAction == .updateExisting)
            && extractedDraft.suggestedByDraftId == nil

        let primary = ScanReviewDraftItem(
            id: extractedDraft.draftId.uuidString,
            rowKey: rowKey,
            eventType: extractedDraft.eventType,
            startedAt: extractedDraft.startedAt,
            endedAt: extractedDraft.endedAt,
            title: FormattingHelpers.eventTitle(syntheticEvent),
            detail: FormattingHelpers.eventDetail(syntheticEvent, preferredUnit: preferredUnit, timeZone: timeZone),
            savedDetail: nil,
            metadata: normalizedMetadata,
            notes: extractedDraft.notes,
            matchAction: extractedDraft.matchAction,
            isSuggestion: extractedDraft.suggestedByDraftId != nil,
            ambiguityQuestion: ambiguityQuestion,
            ambiguityOptions: ambiguityOptions,
            ambiguityOptionDates: ambiguityOptionDates,
            resolvedOption: nil,
            isIncluded: shouldIncludePrimary,
            boundingBox: extractedDraft.boundingBox,
            matchedEventId: extractedDraft.matchedEventId
        )

        var items = [primary]
        if let companion = extractedDraft.suggestedCompanion {
            let normalizedCompanionMetadata = Self.resolvedMetadata(
                companion.metadata,
                startedAt: companion.startedAt,
                calendar: scanCalendar
            )
            let companionEvent = EventDTO(
                id: companion.draftId,
                profileId: UUID(),
                eventType: companion.eventType,
                startedAt: companion.startedAt,
                endedAt: companion.endedAt,
                timezone: timeZone.identifier,
                notes: companion.notes,
                metadata: normalizedCompanionMetadata,
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
                metadata: normalizedCompanionMetadata,
                notes: companion.notes,
                matchAction: .create,
                isSuggestion: true,
                ambiguityQuestion: nil,
                ambiguityOptions: [],
                ambiguityOptionDates: [:],
                resolvedOption: nil,
                isIncluded: false,
                boundingBox: extractedDraft.boundingBox,
                matchedEventId: nil
            )
            items.append(suggestionDraft)
        }
        return items
    }

    private static func resolvedMetadata(
        _ metadata: EventMetadata,
        startedAt: Date,
        calendar: Calendar
    ) -> EventMetadata {
        if case .meal(var meta) = metadata, meta.mealSlot == nil {
            meta.mealSlot = MealSlotClassifier.classify(date: startedAt, calendar: calendar)
            return .meal(meta)
        }
        return metadata
    }

    // MARK: - Ambiguity Candidate Parser

    /// Extracts interactive resolution chips from VLM `ambiguity_reason` strings.
    /// When 2+ plausible clock times appear (e.g. `"could be 11:20 or 11:30"`), builds time options mapped to `Date`s;
    /// otherwise surfaces a single `"Looks right"` confirmation chip for medium/low confidence ambiguities.
    private static func parseAmbiguityOptions(
        question: String?,
        confidence: ConfidenceLevel,
        anchorDate: Date,
        timeZone: TimeZone
    ) -> (options: [String], dates: [String: Date]) {
        guard let question, !question.isEmpty else {
            return ([], [:])
        }

        let pattern = #"\b(\d{1,2}):(\d{2})(?:\s*([AaPp][Mm]))?\b"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return (["Looks right"], ["Looks right": anchorDate])
        }

        let nsRange = NSRange(question.startIndex ..< question.endIndex, in: question)
        let matches = regex.matches(in: question, range: nsRange)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let dayComps = calendar.dateComponents([.year, .month, .day], from: anchorDate)

        var options: [String] = []
        var optionDates: [String: Date] = [:]

        for match in matches {
            guard let hourRange = Range(match.range(at: 1), in: question),
                  let minuteRange = Range(match.range(at: 2), in: question),
                  let rawHour = Int(question[hourRange]),
                  let minute = Int(question[minuteRange]),
                  (0 ... 59).contains(minute)
            else {
                continue
            }

            let meridiem: String? = {
                guard match.range(at: 3).location != NSNotFound,
                      let mRange = Range(match.range(at: 3), in: question)
                else {
                    return nil
                }
                return question[mRange].uppercased()
            }()

            let candidateDate: Date?
            if let meridiem, (1 ... 12).contains(rawHour) {
                var hour24 = rawHour % 12
                if meridiem == "PM" { hour24 += 12 }
                candidateDate = calendar.date(
                    from: DateComponents(
                        timeZone: timeZone,
                        year: dayComps.year,
                        month: dayComps.month,
                        day: dayComps.day,
                        hour: hour24,
                        minute: minute
                    )
                )
            } else if (13 ... 23).contains(rawHour) || rawHour == 0 {
                candidateDate = calendar.date(
                    from: DateComponents(
                        timeZone: timeZone,
                        year: dayComps.year,
                        month: dayComps.month,
                        day: dayComps.day,
                        hour: rawHour,
                        minute: minute
                    )
                )
            } else if (1 ... 12).contains(rawHour) {
                let amHour = rawHour % 12
                let pmHour = amHour + 12
                let amDate = calendar.date(
                    from: DateComponents(
                        timeZone: timeZone,
                        year: dayComps.year,
                        month: dayComps.month,
                        day: dayComps.day,
                        hour: amHour,
                        minute: minute
                    )
                )
                let pmDate = calendar.date(
                    from: DateComponents(
                        timeZone: timeZone,
                        year: dayComps.year,
                        month: dayComps.month,
                        day: dayComps.day,
                        hour: pmHour,
                        minute: minute
                    )
                )
                if let amDate, let pmDate {
                    candidateDate = abs(amDate.timeIntervalSince(anchorDate)) <= abs(pmDate.timeIntervalSince(anchorDate))
                        ? amDate
                        : pmDate
                } else {
                    candidateDate = amDate ?? pmDate
                }
            } else {
                candidateDate = nil
            }

            if let candidateDate {
                let label = FormattingHelpers.formatClock(candidateDate, timeZone: timeZone)
                if optionDates[label] == nil {
                    options.append(label)
                    optionDates[label] = candidateDate
                }
            }
        }

        if options.count >= 2 {
            return (options, optionDates)
        }

        if confidence != .high || !question.isEmpty {
            return (["Looks right"], ["Looks right": anchorDate])
        }

        return ([], [:])
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
    public var scanDate: String?
    public var sheetNotes: String?

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
        confirmedEntryCount: Int = 0,
        scanDate: String? = nil,
        sheetNotes: String? = nil
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
        self.scanDate = scanDate
        self.sheetNotes = sheetNotes
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
