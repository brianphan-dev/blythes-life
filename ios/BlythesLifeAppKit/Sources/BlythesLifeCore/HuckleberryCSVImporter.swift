import BlythesLifeShared
import CryptoKit
import Foundation

/// Idempotent importer for Huckleberry 8–9 column CSV exports.
/// Generates deterministic `externalId = "hb:<16-hex>"` keys using SHA-256 so overlapping re-imports never duplicate.
public enum HuckleberryCSVImporter: Sendable {
    public struct ParseSummary: Sendable, Equatable {
        public var events: [EventDTO]
        public var skippedRowCount: Int

        public init(events: [EventDTO], skippedRowCount: Int) {
            self.events = events
            self.skippedRowCount = skippedRowCount
        }
    }

    /// Parses a Huckleberry CSV export string into canonical `EventDTO`s with deterministic `hb:<16-hex>` external IDs.
    public static func parse(
        csvString: String,
        profileId: UUID,
        userId: UUID,
        timezone: String = TimeZone.current.identifier
    ) -> [EventDTO] {
        parseDetailed(
            csvString: csvString,
            profileId: profileId,
            userId: userId,
            timezone: timezone
        ).events
    }

    public static func parseDetailed(
        csvString: String,
        profileId: UUID,
        userId: UUID,
        timezone: String = TimeZone.current.identifier
    ) -> ParseSummary {
        let cleaned = stripUTF8BOM(csvString)
        let rows = parseCSVRows(cleaned)
        guard let headerRow = rows.first else {
            return ParseSummary(events: [], skippedRowCount: 0)
        }

        let columns = ColumnMap(header: headerRow)
        let tz = TimeZone(identifier: timezone) ?? .current
        let now = Date()

        var events: [EventDTO] = []
        var skipped = 0
        var seenExternalIds: Set<String> = []

        for row in rows.dropFirst() {
            if row.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                continue
            }

            let rawType = columns.value(in: row, key: .type)
            let rawStart = columns.value(in: row, key: .start)
            let rawEnd = columns.value(in: row, key: .end)
            let rawDuration = columns.value(in: row, key: .duration)
            let rawStartCondition = columns.value(in: row, key: .startCondition)
            let rawStartLocation = columns.value(in: row, key: .startLocation)
            let rawEndCondition = columns.value(in: row, key: .endCondition)
            let rawEndLocation = columns.value(in: row, key: .endLocation)
            let rawNotes = columns.value(in: row, key: .notes)

            guard !rawType.isEmpty, let startedAt = parseTimestamp(rawStart, timeZone: tz) else {
                skipped += 1
                continue
            }

            let parsedEnd = parseTimestamp(rawEnd, timeZone: tz)
            let durationMinutes = parseDurationMinutes(rawDuration)
            let effectiveEnd: Date? = {
                if let parsedEnd, parsedEnd >= startedAt {
                    return parsedEnd
                }
                if let durationMinutes, durationMinutes > 0 {
                    return startedAt.addingTimeInterval(durationMinutes * 60)
                }
                return nil
            }()

            let externalId = makeExternalId(
                profileId: profileId,
                rawType: rawType,
                startedAt: startedAt,
                endedAt: effectiveEnd,
                startCondition: rawStartCondition,
                startLocation: rawStartLocation,
                endCondition: rawEndCondition,
                endLocation: rawEndLocation,
                notes: rawNotes
            )

            guard seenExternalIds.insert(externalId).inserted else {
                skipped += 1
                continue
            }

            let trimmedNotes = nonEmpty(rawNotes)
            guard let built = buildEventMetadata(
                rawType: rawType,
                startedAt: startedAt,
                endedAt: effectiveEnd,
                durationMinutes: durationMinutes,
                startCondition: rawStartCondition,
                startLocation: rawStartLocation,
                endCondition: rawEndCondition,
                endLocation: rawEndLocation,
                notes: trimmedNotes,
                timeZone: tz
            ) else {
                skipped += 1
                continue
            }

            let event = EventDTO(
                id: UUID(),
                profileId: profileId,
                eventType: built.type,
                startedAt: startedAt,
                endedAt: built.endedAt,
                timezone: timezone,
                notes: built.notes,
                metadata: built.metadata,
                source: .importHuckleberry,
                scanId: nil,
                externalId: externalId,
                createdBy: userId,
                updatedBy: userId,
                createdAt: now,
                updatedAt: now,
                deletedAt: nil
            )
            events.append(event)
        }

        return ParseSummary(events: events, skippedRowCount: skipped)
    }

    // MARK: - Deterministic External ID

    public static func makeExternalId(
        profileId: UUID,
        rawType: String,
        startedAt: Date,
        endedAt: Date?,
        startCondition: String,
        startLocation: String,
        endCondition: String,
        endLocation: String,
        notes: String
    ) -> String {
        let isoStart = BlythesLifeJSONCoding.formatISO8601(startedAt)
        let isoEnd = endedAt.map(BlythesLifeJSONCoding.formatISO8601) ?? ""
        let canonical = [
            profileId.uuidString.lowercased(),
            rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            isoStart,
            isoEnd,
            startCondition.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            startLocation.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            endCondition.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            endLocation.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
            notes.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        ].joined(separator: "|")

        let digest = SHA256.hash(data: Data(canonical.utf8))
        let hex = digest.prefix(8).map { String(format: "%02x", $0) }.joined()
        return "hb:\(hex)"
    }

    // MARK: - Row Type Mapping

    private struct BuiltEvent {
        var type: EventType
        var metadata: EventMetadata
        var endedAt: Date?
        var notes: String?
    }

    private static func buildEventMetadata(
        rawType: String,
        startedAt: Date,
        endedAt: Date?,
        durationMinutes: Double?,
        startCondition: String,
        startLocation: String,
        endCondition: String,
        endLocation: String,
        notes: String?,
        timeZone: TimeZone
    ) -> BuiltEvent? {
        let normalizedType = rawType.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        switch normalizedType {
        case "sleep":
            return buildSleep(
                startedAt: startedAt,
                endedAt: endedAt,
                startCondition: startCondition,
                startLocation: startLocation,
                notes: notes,
                timeZone: timeZone
            )

        case "feed", "feeding", "bottle", "nursing", "breast":
            return buildFeed(
                rawType: normalizedType,
                startedAt: startedAt,
                endedAt: endedAt,
                durationMinutes: durationMinutes,
                startCondition: startCondition,
                startLocation: startLocation,
                endCondition: endCondition,
                endLocation: endLocation,
                notes: notes
            )

        case "pump", "pumping":
            return buildPump(
                endedAt: endedAt,
                durationMinutes: durationMinutes,
                startCondition: startCondition,
                startLocation: startLocation,
                endCondition: endCondition,
                endLocation: endLocation,
                notes: notes
            )

        case "diaper":
            return buildDiaper(
                startCondition: startCondition,
                startLocation: startLocation,
                endCondition: endCondition,
                notes: notes
            )

        case "solids", "solid", "meal", "food":
            return buildMeal(
                startedAt: startedAt,
                startCondition: startCondition,
                startLocation: startLocation,
                endCondition: endCondition,
                notes: notes,
                timeZone: timeZone
            )

        case "meds", "med", "medicine", "medication", "supplement", "care":
            return buildMedicine(
                startCondition: startCondition,
                startLocation: startLocation,
                endCondition: endCondition,
                notes: notes
            )

        case "bath":
            let combined = [startCondition, startLocation, endCondition, notes ?? ""].joined(separator: " ").lowercased()
            let washedHair = combined.contains("shampoo") || combined.contains("hair")
            return BuiltEvent(
                type: .bath,
                metadata: .bath(BathMetadata(washedHair: washedHair)),
                endedAt: endedAt,
                notes: notes
            )

        case "note", "notes", "activity":
            let fallbackText = [startCondition, endCondition, notes ?? ""]
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .joined(separator: " · ")
            return BuiltEvent(
                type: .note,
                metadata: .note(NoteMetadata()),
                endedAt: nil,
                notes: nonEmpty(fallbackText)
            )

        default:
            return nil
        }
    }

    private static func buildSleep(
        startedAt: Date,
        endedAt: Date?,
        startCondition: String,
        startLocation: String,
        notes: String?,
        timeZone: TimeZone
    ) -> BuiltEvent {
        let combined = [startCondition, startLocation, notes ?? ""].joined(separator: " ").lowercased()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let startHour = calendar.component(.hour, from: startedAt)
        let durationMin = endedAt.map { $0.timeIntervalSince(startedAt) / 60.0 } ?? 0

        let sleepType: SleepType
        if combined.contains("night") || combined.contains("bedtime") {
            sleepType = .night
        } else if combined.contains("nap") {
            sleepType = .nap
        } else if durationMin >= 240 || startHour >= 19 || startHour < 6 {
            sleepType = .night
        } else {
            sleepType = .nap
        }

        let location: SleepLocation?
        if combined.contains("crib") || combined.contains("bassinet") {
            location = .crib
        } else if combined.contains("stroller") || combined.contains("car") {
            location = .stroller
        } else if combined.contains("contact") || combined.contains("held") || combined.contains("carrier") {
            location = .contact
        } else {
            location = nil
        }

        return BuiltEvent(
            type: .sleep,
            metadata: .sleep(SleepMetadata(sleepType: sleepType, location: location)),
            endedAt: endedAt,
            notes: notes
        )
    }

    private static func buildFeed(
        rawType: String,
        startedAt: Date,
        endedAt: Date?,
        durationMinutes: Double?,
        startCondition: String,
        startLocation: String,
        endCondition: String,
        endLocation: String,
        notes: String?
    ) -> BuiltEvent {
        let fields = [startCondition, startLocation, endCondition, endLocation]
        let combined = fields.joined(separator: " ").lowercased()

        // Detect bottle volume across condition/location columns (Huckleberry varies by export version).
        let volume = fields.compactMap { parseVolumeFromField($0) }.first
        let looksLikeBottle = rawType == "bottle"
            || combined.contains("bottle")
            || combined.contains("formula")
            || combined.contains("mixed")
            || volume != nil

        let looksLikeNursing = rawType == "nursing"
            || rawType == "breast"
            || (!looksLikeBottle && (
                combined.contains("left")
                    || combined.contains("right")
                    || combined.contains("breast")
                    || combined.contains("nurse")
                    || combined.contains("nursing")
                    || durationMinutes != nil
            ))

        if looksLikeNursing {
            let leftSeconds = parseSideDurationSeconds(fields: fields, sideToken: "l")
            let rightSeconds = parseSideDurationSeconds(fields: fields, sideToken: "r")

            let side: BreastSide
            if (leftSeconds ?? 0) > 0 && (rightSeconds ?? 0) > 0 {
                side = .both
            } else if combined.contains("both") || (combined.contains("left") && combined.contains("right")) {
                side = .both
            } else if combined.contains("left") || (leftSeconds ?? 0) > 0 {
                side = .left
            } else if combined.contains("right") || (rightSeconds ?? 0) > 0 {
                side = .right
            } else {
                side = .both
            }

            let totalMinutes: Double? = {
                if let durationMinutes, durationMinutes > 0 {
                    return durationMinutes
                }
                if let l = leftSeconds, let r = rightSeconds, (l + r) > 0 {
                    return Double(l + r) / 60.0
                }
                if let endedAt, endedAt > startedAt {
                    return endedAt.timeIntervalSince(startedAt) / 60.0
                }
                return nil
            }()

            return BuiltEvent(
                type: .feeding,
                metadata: .feeding(
                    FeedingMetadata(
                        method: .breast,
                        substance: .breastMilk,
                        amountMl: nil,
                        displayUnit: .oz,
                        side: side,
                        durationMinutes: totalMinutes,
                        leftDurationSeconds: leftSeconds,
                        rightDurationSeconds: rightSeconds
                    )
                ),
                endedAt: endedAt,
                notes: notes
            )
        }

        // Bottle feeding
        let substance: FeedingSubstance
        if combined.contains("mixed") || (combined.contains("formula") && combined.contains("breast")) {
            substance = .mixed
        } else if combined.contains("formula") {
            substance = .formula
        } else {
            substance = .breastMilk
        }

        let displayUnit = volume?.unit ?? .oz
        let amountMl: Double? = volume.map { parsed in
            parsed.unit == .ml ? parsed.value : UnitConversion.ozToMl(parsed.value)
        }

        return BuiltEvent(
            type: .feeding,
            metadata: .feeding(
                FeedingMetadata(
                    method: .bottle,
                    substance: substance,
                    amountMl: amountMl,
                    displayUnit: displayUnit
                )
            ),
            endedAt: endedAt,
            notes: notes
        )
    }

    private static func buildPump(
        endedAt: Date?,
        durationMinutes: Double?,
        startCondition: String,
        startLocation: String,
        endCondition: String,
        endLocation: String,
        notes: String?
    ) -> BuiltEvent {
        let fields = [startCondition, startLocation, endCondition, endLocation]
        let combined = fields.joined(separator: " ").lowercased()

        // Sum left+right pump volumes if multiple volume columns exist (e.g. Start Location = "2 oz", End Condition = "2.5 oz").
        let parsedVolumes = fields.compactMap { parseVolumeFromField($0) }
        let displayUnit = parsedVolumes.first?.unit ?? .oz
        let totalMl: Double?
        if parsedVolumes.isEmpty {
            totalMl = nil
        } else {
            let sumMl = parsedVolumes.reduce(0.0) { acc, item in
                acc + (item.unit == .ml ? item.value : UnitConversion.ozToMl(item.value))
            }
            totalMl = (sumMl * 10.0).rounded() / 10.0
        }

        let side: BreastSide
        if combined.contains("both") || parsedVolumes.count >= 2 || (combined.contains("left") && combined.contains("right")) {
            side = .both
        } else if combined.contains("left") {
            side = .left
        } else if combined.contains("right") {
            side = .right
        } else {
            side = .both
        }

        return BuiltEvent(
            type: .pump,
            metadata: .pump(
                PumpMetadata(
                    amountMl: totalMl,
                    displayUnit: displayUnit,
                    side: side,
                    durationMinutes: durationMinutes
                )
            ),
            endedAt: endedAt,
            notes: notes
        )
    }

    private static func buildDiaper(
        startCondition: String,
        startLocation: String,
        endCondition: String,
        notes: String?
    ) -> BuiltEvent {
        let combined = [startCondition, startLocation, endCondition, notes ?? ""].joined(separator: " ").lowercased()
        let hasBoth = combined.contains("both") || combined.contains("mixed")
        let hasPee = hasBoth || combined.contains("pee") || combined.contains("wet")
        let hasPoop = hasBoth || combined.contains("poo") || combined.contains("poop") || combined.contains("dirty")
        let rash = combined.contains("rash")

        let detectedSize = parseDiaperSize(in: [endCondition, startLocation, startCondition].joined(separator: " "))
        let peeSize = hasPee ? (parseDiaperSize(after: "pee", in: combined) ?? detectedSize ?? .medium) : nil
        let poopSize = hasPoop ? (parseDiaperSize(after: "poo", in: combined) ?? detectedSize ?? .medium) : nil

        return BuiltEvent(
            type: .diaper,
            metadata: .diaper(DiaperMetadata(peeSize: peeSize, poopSize: poopSize, rash: rash)),
            endedAt: nil,
            notes: notes
        )
    }

    private static func buildMeal(
        startedAt: Date,
        startCondition: String,
        startLocation: String,
        endCondition: String,
        notes: String?,
        timeZone: TimeZone
    ) -> BuiltEvent {
        let combined = [startCondition, startLocation, endCondition].joined(separator: " ").lowercased()

        let slot: MealSlot
        if combined.contains("breakfast") {
            slot = .breakfast
        } else if combined.contains("lunch") {
            slot = .lunch
        } else if combined.contains("dinner") {
            slot = .dinner
        } else if combined.contains("snack") {
            slot = .snack
        } else {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let hour = calendar.component(.hour, from: startedAt)
            if hour < 10 { slot = .breakfast }
            else if hour < 15 { slot = .lunch }
            else if hour < 17 { slot = .snack }
            else { slot = .dinner }
        }

        let portion: PortionEaten?
        if combined.contains("most") || combined.contains("all") || combined.contains("loved") {
            portion = .most
        } else if combined.contains("some") || combined.contains("half") || combined.contains("liked") {
            portion = .some
        } else if combined.contains("none") || combined.contains("refused") || combined.contains("disliked") {
            portion = PortionEaten.none
        } else {
            portion = nil
        }

        // Preserve food description from `startCondition` or `notes`.
        let foodFromCondition: String? = {
            let trimmed = startCondition.trimmingCharacters(in: .whitespacesAndNewlines)
            let lowered = trimmed.lowercased()
            guard !trimmed.isEmpty,
                  lowered != "breakfast", lowered != "lunch", lowered != "dinner", lowered != "snack"
            else {
                return nil
            }
            return trimmed
        }()

        let mergedNotes = [foodFromCondition, notes]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")

        return BuiltEvent(
            type: .meal,
            metadata: .meal(MealMetadata(mealSlot: slot, portionEaten: portion)),
            endedAt: nil,
            notes: nonEmpty(mergedNotes)
        )
    }

    private static func buildMedicine(
        startCondition: String,
        startLocation: String,
        endCondition: String,
        notes: String?
    ) -> BuiltEvent {
        let rawName = nonEmpty(startCondition) ?? nonEmpty(startLocation) ?? "Medicine"
        let loweredName = rawName.lowercased()
        let doseSource = nonEmpty(endCondition) ?? nonEmpty(startLocation) ?? ""
        let loweredDose = doseSource.lowercased()

        let category: MedicineCategory
        if loweredName.contains("cream") || loweredName.contains("ointment") || loweredName.contains("topical") {
            category = .topical
        } else if loweredName.contains("vitamin") || loweredName.contains("probiotic") || loweredName.contains("supplement") {
            category = .supplement
        } else {
            category = .medicine
        }

        let doseValue = category == .topical ? nil : UnitConversion.parseFlexibleNumber(doseSource)
        let doseUnit: DoseUnit?
        if category == .topical || doseValue == nil {
            doseUnit = nil
        } else if loweredDose.contains("drop") {
            doseUnit = .drops
        } else if loweredDose.contains("mg") {
            doseUnit = .mg
        } else {
            doseUnit = .ml
        }

        return BuiltEvent(
            type: .medicine,
            metadata: .medicine(
                MedicineMetadata(
                    name: rawName,
                    category: category,
                    dose: doseValue,
                    unit: doseUnit
                )
            ),
            endedAt: nil,
            notes: notes
        )
    }

    // MARK: - Field Parsing Helpers

    private static func parseVolumeFromField(_ field: String) -> (value: Double, unit: VolumeUnit)? {
        let trimmed = field.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let parsed = UnitConversion.parseVolumeAmount(trimmed), let unit = parsed.unit else {
            return nil
        }
        return (parsed.value, unit)
    }

    private static func parseSideDurationSeconds(fields: [String], sideToken: String) -> Int? {
        for raw in fields {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard trimmed.hasSuffix(sideToken) else { continue }
            let core = String(trimmed.dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
            if let minutes = parseDurationMinutes(core) {
                return Int((minutes * 60.0).rounded())
            }
        }
        return nil
    }

    private static func parseDurationMinutes(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }

        // HH:MM or HH:MM:SS
        if trimmed.contains(":") {
            let parts = trimmed.split(separator: ":").compactMap { Double($0) }
            if parts.count == 2 {
                return parts[0] * 60.0 + parts[1]
            }
            if parts.count == 3 {
                return parts[0] * 60.0 + parts[1] + (parts[2] / 60.0)
            }
        }

        // "1h 17m" / "15m"
        var totalMinutes = 0.0
        var matched = false
        let tokens = trimmed.split(whereSeparator: \.isWhitespace)
        for token in tokens {
            if token.hasSuffix("h"), let h = Double(token.dropLast()) {
                totalMinutes += h * 60.0
                matched = true
            } else if token.hasSuffix("m"), let m = Double(token.dropLast()) {
                totalMinutes += m
                matched = true
            }
        }
        if matched {
            return totalMinutes
        }

        return Double(trimmed)
    }

    private static func parseDiaperSize(in text: String) -> DiaperSize? {
        let lowered = text.lowercased()
        if lowered.contains("large") || containsStandaloneToken("l", in: lowered) {
            return .large
        }
        if lowered.contains("medium") || containsStandaloneToken("m", in: lowered) {
            return .medium
        }
        if lowered.contains("small") || containsStandaloneToken("s", in: lowered) {
            return .small
        }
        return nil
    }

    private static func parseDiaperSize(after keyword: String, in text: String) -> DiaperSize? {
        guard let range = text.range(of: keyword) else { return nil }
        let suffix = String(text[range.upperBound...]).prefix(16)
        return parseDiaperSize(in: String(suffix))
    }

    private static func containsStandaloneToken(_ token: String, in text: String) -> Bool {
        let words = text.split { !$0.isLetter && !$0.isNumber }
        return words.contains { $0 == token }
    }

    private static func parseTimestamp(_ raw: String, timeZone: TimeZone) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let iso = BlythesLifeJSONCoding.parseISO8601(trimmed) {
            return iso
        }

        let formats = [
            "yyyy-MM-dd HH:mm:ss",
            "yyyy-MM-dd HH:mm",
            "yyyy/MM/dd HH:mm:ss",
            "yyyy/MM/dd HH:mm",
            "MM/dd/yyyy hh:mm a",
            "MM/dd/yyyy h:mm a",
            "M/d/yyyy h:mm a",
            "MM/dd/yyyy HH:mm:ss",
            "MM/dd/yyyy HH:mm"
        ]

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone

        for format in formats {
            formatter.dateFormat = format
            if let parsed = formatter.date(from: trimmed) {
                return parsed
            }
        }
        return nil
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private static func stripUTF8BOM(_ input: String) -> String {
        if input.hasPrefix("\u{FEFF}") {
            return String(input.dropFirst())
        }
        return input
    }

    // MARK: - RFC 4180 CSV Parsing

    private static func parseCSVRows(_ input: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false
        var index = input.startIndex

        while index < input.endIndex {
            let ch = input[index]
            if inQuotes {
                if ch == "\"" {
                    let next = input.index(after: index)
                    if next < input.endIndex && input[next] == "\"" {
                        currentField.append("\"")
                        index = input.index(after: next)
                        continue
                    } else {
                        inQuotes = false
                    }
                } else {
                    currentField.append(ch)
                }
            } else {
                switch ch {
                case "\"":
                    inQuotes = true
                case ",":
                    currentRow.append(currentField)
                    currentField = ""
                case "\r":
                    let next = input.index(after: index)
                    if next < input.endIndex && input[next] == "\n" {
                        index = next
                    }
                    currentRow.append(currentField)
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                case "\n":
                    currentRow.append(currentField)
                    rows.append(currentRow)
                    currentRow = []
                    currentField = ""
                default:
                    currentField.append(ch)
                }
            }
            index = input.index(after: index)
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }
        return rows
    }

    private struct ColumnMap {
        enum Key {
            case type, start, end, duration, startCondition, startLocation, endCondition, endLocation, notes
        }

        private let indices: [Key: Int]

        init(header: [String]) {
            var map: [Key: Int] = [:]
            for (idx, rawCol) in header.enumerated() {
                let col = rawCol.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                switch col {
                case "type": map[.type] = idx
                case "start": map[.start] = idx
                case "end": map[.end] = idx
                case "duration": map[.duration] = idx
                case "start condition": map[.startCondition] = idx
                case "start location": map[.startLocation] = idx
                case "end condition": map[.endCondition] = idx
                case "end location": map[.endLocation] = idx
                case "notes", "note": map[.notes] = idx
                default: break
                }
            }
            // Positional fallback for standard 8-column Huckleberry header
            if map[.type] == nil { map[.type] = 0 }
            if map[.start] == nil { map[.start] = 1 }
            if map[.end] == nil { map[.end] = 2 }
            if map[.duration] == nil { map[.duration] = 3 }
            if map[.startCondition] == nil { map[.startCondition] = 4 }
            if map[.startLocation] == nil { map[.startLocation] = 5 }
            if map[.endCondition] == nil { map[.endCondition] = 6 }
            if map[.notes] == nil { map[.notes] = header.count >= 9 ? 8 : 7 }
            self.indices = map
        }

        func value(in row: [String], key: Key) -> String {
            guard let idx = indices[key], idx >= 0, idx < row.count else {
                return ""
            }
            return row[idx].trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
