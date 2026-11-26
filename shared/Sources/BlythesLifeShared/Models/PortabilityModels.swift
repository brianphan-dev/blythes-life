import Foundation

public struct LosslessExportBundleV1: Codable, Sendable, Equatable, Hashable {
    public static let currentSchemaVersion = 1

    public var schemaVersion: Int
    public var exportedAt: Date
    public var household: HouseholdDTO
    public var profiles: [ProfileDTO]
    public var events: [EventDTO]

    public init(
        schemaVersion: Int = LosslessExportBundleV1.currentSchemaVersion,
        exportedAt: Date = Date(),
        household: HouseholdDTO,
        profiles: [ProfileDTO],
        events: [EventDTO]
    ) {
        self.schemaVersion = schemaVersion
        self.exportedAt = exportedAt
        self.household = household
        self.profiles = profiles
        self.events = events
    }

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case exportedAt = "exported_at"
        case household
        case profiles
        case events
    }
}

/// Shared ISO-8601 fractional-second JSON coding helpers used across Apple clients and Linux VPS server.
public enum BlythesLifeJSONCoding: Sendable {
    public static func formatISO8601(_ date: Date) -> String {
        Date.ISO8601FormatStyle(includingFractionalSeconds: true).format(date)
    }

    public static func parseISO8601(_ value: String) -> Date? {
        if let parsed = try? Date.ISO8601FormatStyle(includingFractionalSeconds: true).parse(value) {
            return parsed
        }
        if let parsed = try? Date.ISO8601FormatStyle(includingFractionalSeconds: false).parse(value) {
            return parsed
        }

        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let parsed = fractionalFormatter.date(from: value) {
            return parsed
        }

        let plainFormatter = ISO8601DateFormatter()
        plainFormatter.formatOptions = [.withInternetDateTime]
        return plainFormatter.date(from: value)
    }

    public static func makeEncoder(
        prettyPrinted: Bool = false,
        sortedKeys: Bool = false
    ) -> JSONEncoder {
        let encoder = JSONEncoder()
        var formatting: JSONEncoder.OutputFormatting = [.withoutEscapingSlashes]
        if prettyPrinted {
            formatting.insert(.prettyPrinted)
        }
        if sortedKeys {
            formatting.insert(.sortedKeys)
        }
        encoder.outputFormatting = formatting
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(formatISO8601(date))
        }
        return encoder
    }

    public static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            guard let date = parseISO8601(string) else {
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Invalid ISO-8601 date string: \(string)"
                )
            }
            return date
        }
        return decoder
    }
}
