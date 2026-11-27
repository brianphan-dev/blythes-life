import BlythesLifeShared
import Foundation

public enum DataPortabilityError: Error, Sendable, Equatable, LocalizedError {
    case unsupportedSchemaVersion(Int)
    case invalidJSON(String)

    public var errorDescription: String? {
        switch self {
        case .unsupportedSchemaVersion(let version):
            return "Unsupported export schema version (\(version))."
        case .invalidJSON(let message):
            return "Could not read export bundle: \(message)"
        }
    }
}

/// Lossless JSON backup/restore (`LosslessExportBundleV1`) and clean pediatrician CSV export.
public enum DataPortabilityService: Sendable {
    /// Encodes a single-profile lossless `LosslessExportBundleV1` JSON document.
    public static func exportLosslessJSON(
        household: HouseholdDTO,
        profile: ProfileDTO,
        events: [EventDTO],
        exportedAt: Date = Date()
    ) throws -> Data {
        try exportLosslessJSON(
            household: household,
            profiles: [profile],
            events: events,
            exportedAt: exportedAt
        )
    }

    /// Encodes a multi-profile lossless `LosslessExportBundleV1` JSON document.
    public static func exportLosslessJSON(
        household: HouseholdDTO,
        profiles: [ProfileDTO],
        events: [EventDTO],
        exportedAt: Date = Date()
    ) throws -> Data {
        let sortedEvents = events.sorted { lhs, rhs in
            if lhs.startedAt != rhs.startedAt {
                return lhs.startedAt < rhs.startedAt
            }
            return lhs.id.uuidString < rhs.id.uuidString
        }
        let bundle = LosslessExportBundleV1(
            schemaVersion: LosslessExportBundleV1.currentSchemaVersion,
            exportedAt: exportedAt,
            household: household,
            profiles: profiles,
            events: sortedEvents
        )
        return try BlythesLifeJSONCoding.makeEncoder(prettyPrinted: true, sortedKeys: true).encode(bundle)
    }

    /// Decodes and validates a `LosslessExportBundleV1` JSON payload.
    public static func importLosslessJSON(_ data: Data) throws -> LosslessExportBundleV1 {
        let bundle: LosslessExportBundleV1
        do {
            bundle = try BlythesLifeJSONCoding.makeDecoder().decode(LosslessExportBundleV1.self, from: data)
        } catch {
            throw DataPortabilityError.invalidJSON(error.localizedDescription)
        }
        guard bundle.schemaVersion == LosslessExportBundleV1.currentSchemaVersion else {
            throw DataPortabilityError.unsupportedSchemaVersion(bundle.schemaVersion)
        }
        return bundle
    }

    /// Exports non-deleted events to a human/pediatrician-readable RFC 4180 CSV string.
    /// Columns: `Date,Time,Type,Details,Duration,Notes,Source`
    public static func exportPediatricianCSV(
        events: [EventDTO],
        timezone: String = TimeZone.current.identifier,
        preferredUnit: VolumeUnit = .oz
    ) -> String {
        let tz = TimeZone(identifier: timezone) ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tz

        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.calendar = calendar
        dateFormatter.timeZone = tz
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let active = events
            .filter { $0.deletedAt == nil }
            .sorted { lhs, rhs in
                if lhs.startedAt != rhs.startedAt {
                    return lhs.startedAt < rhs.startedAt
                }
                return lhs.createdAt < rhs.createdAt
            }

        // Precompute chronological per-day nap numbers so CSV rows read "Nap 1", "Nap 2", etc.
        var napCountsByDay: [String: Int] = [:]
        var napNumbers: [UUID: Int] = [:]
        for event in active {
            if case .sleep(let meta) = event.metadata, meta.sleepType == .nap {
                let dayKey = dateFormatter.string(from: event.startedAt)
                let nextNumber = (napCountsByDay[dayKey] ?? 0) + 1
                napCountsByDay[dayKey] = nextNumber
                napNumbers[event.id] = nextNumber
            }
        }

        var lines: [String] = ["Date,Time,Type,Details,Duration,Notes,Source"]

        for event in active {
            let dateText = dateFormatter.string(from: event.startedAt)
            let timeText = FormattingHelpers.formatClock(event.startedAt, timeZone: tz)
            let typeText = FormattingHelpers.eventTitle(event, napNumber: napNumbers[event.id])
            let detailsText = FormattingHelpers.eventDetail(event, preferredUnit: preferredUnit, timeZone: tz)
            let durationText = csvDurationText(for: event)
            let notesText = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let sourceText = readableSource(event.source)

            let fields = [dateText, timeText, typeText, detailsText, durationText, notesText, sourceText]
            lines.append(fields.map(csvEscape).joined(separator: ","))
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func csvDurationText(for event: EventDTO) -> String {
        switch event.metadata {
        case .feeding(let meta) where meta.method == .breast:
            if let minutes = meta.durationMinutes, minutes > 0 {
                return FormattingHelpers.formatDuration(minutes: minutes)
            }
            let totalSeconds = (meta.leftDurationSeconds ?? 0) + (meta.rightDurationSeconds ?? 0)
            if totalSeconds > 0 {
                return FormattingHelpers.formatDuration(minutes: max(1.0, Double(totalSeconds) / 60.0))
            }
            if let endedAt = event.endedAt, endedAt > event.startedAt {
                let minutes = endedAt.timeIntervalSince(event.startedAt) / 60.0
                return FormattingHelpers.formatDuration(minutes: minutes)
            }
            return ""
        case .pump(let meta):
            if let minutes = meta.durationMinutes, minutes > 0 {
                return FormattingHelpers.formatDuration(minutes: minutes)
            }
            if let endedAt = event.endedAt, endedAt > event.startedAt {
                let minutes = endedAt.timeIntervalSince(event.startedAt) / 60.0
                return FormattingHelpers.formatDuration(minutes: minutes)
            }
            return ""
        default:
            if let endedAt = event.endedAt, endedAt > event.startedAt {
                let minutes = endedAt.timeIntervalSince(event.startedAt) / 60.0
                return FormattingHelpers.formatDuration(minutes: minutes)
            }
            return ""
        }
    }

    private static func readableSource(_ source: EventSource) -> String {
        switch source {
        case .manual: "Manual"
        case .paperScan: "Paper scan"
        case .importHuckleberry: "Huckleberry import"
        case .controlCenter: "Control Center"
        }
    }

    private static func csvEscape(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") || field.contains("\r") {
            let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return field
    }
}
