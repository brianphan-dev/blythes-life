import BlythesLifeShared
import Foundation

/// Calm, sentence-case copy and time/volume formatters matching the Blythe's Life design system.
/// Uses middle dot (`·`), en dash (`–`), zero exclamation marks, and zero emoji.
public enum FormattingHelpers: Sendable {
    private static let posixLocale = Locale(identifier: "en_US_POSIX")

    /// Formats a local clock timestamp such as `"10:45 AM"` or `"6:45 AM"`.
    public static func formatClock(_ date: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let hour24 = components.hour ?? 0
        let minute = components.minute ?? 0
        let hour12 = ((hour24 + 11) % 12) + 1
        let meridiem = hour24 < 12 ? "AM" : "PM"
        let paddedMinute = minute < 10 ? "0\(minute)" : "\(minute)"
        return "\(hour12):\(paddedMinute) \(meridiem)"
    }

    /// Formats a minutes-since-midnight value such as `990` -> `"4:30 PM"`.
    public static func formatMinutesFromMidnight(_ minutes: Int) -> String {
        let normalized = ((minutes % 1440) + 1440) % 1440
        let hour24 = normalized / 60
        let minute = normalized % 60
        let hour12 = ((hour24 + 11) % 12) + 1
        let meridiem = hour24 < 12 ? "AM" : "PM"
        let paddedMinute = minute < 10 ? "0\(minute)" : "\(minute)"
        return "\(hour12):\(paddedMinute) \(meridiem)"
    }

    /// Formats a time range with shared meridiem collapsed: `"9:15 – 10:32 AM"` or `"7:10 PM – 6:45 AM"`.
    public static func formatRange(_ start: Date, _ end: Date, timeZone: TimeZone = .current) -> String {
        let startClock = formatClock(start, timeZone: timeZone)
        let endClock = formatClock(end, timeZone: timeZone)
        if startClock.suffix(2) == endClock.suffix(2) {
            let trimmedStart = startClock.dropLast(3)
            return "\(trimmedStart) – \(endClock)"
        }
        return "\(startClock) – \(endClock)"
    }

    /// Formats a minute duration such as `"2h 22m"` or `"34m"`.
    public static func formatDuration(minutes: Double) -> String {
        let total = max(0, Int(minutes.rounded()))
        let hours = total / 60
        let remainder = total % 60
        if hours > 0 {
            return "\(hours)h \(remainder)m"
        }
        return "\(remainder)m"
    }

    /// Formats a live timer duration in `M:SS`, such as `"4:08"` or `"0:00"`.
    public static func formatMMSS(seconds: Int) -> String {
        let clamped = max(0, seconds)
        let mins = clamped / 60
        let secs = clamped % 60
        let paddedSecs = secs < 10 ? "0\(secs)" : "\(secs)"
        return "\(mins):\(paddedSecs)"
    }

    /// Formats wake windows & nap caps cleanly using typographic fractions:
    /// `150` -> `"2½h"`, `195` -> `"3¼h"`, `180` -> `"3h"`, `165` -> `"2¾h"`, `90` -> `"90m"`.
    public static func formatWakeWindowFraction(minutes: Int) -> String {
        let clamped = max(0, minutes)
        if clamped <= 90 {
            return "\(clamped)m"
        }
        let hours = clamped / 60
        let remainder = clamped % 60
        switch remainder {
        case 0:
            return "\(hours)h"
        case 15:
            return "\(hours)¼h"
        case 30:
            return "\(hours)½h"
        case 45:
            return "\(hours)¾h"
        default:
            return "\(hours)h \(remainder)m"
        }
    }

    /// Formats a decimal without trailing `.0` zeros (`3.25` -> `"3.25"`, `4.0` -> `"4"`, `2.50` -> `"2.5"`).
    public static func formatNumber(_ value: Double, maxFractionDigits: Int = 2) -> String {
        let safe = value.isFinite ? (value == 0 ? 0 : value) : 0
        let formatter = NumberFormatter()
        formatter.locale = posixLocale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = maxFractionDigits
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: safe)) ?? "\(safe)"
    }

    /// Formats a bottle or pump volume (`3.25 oz`, `95 mL`, `4 oz`), stripping trailing `.0`.
    public static func formatAmount(_ value: Double, unit: VolumeUnit) -> String {
        switch unit {
        case .oz:
            return "\(formatNumber(value, maxFractionDigits: 2)) oz"
        case .ml:
            return "\(formatNumber(value, maxFractionDigits: 1)) mL"
        }
    }

    /// Formats a 6-digit household invite code cleanly as `"482 913"`.
    public static func formatInviteCode(_ code: String?) -> String {
        guard let code else { return "—" }
        let cleaned = code.filter { !$0.isWhitespace }
        guard cleaned.count == 6 else { return cleaned }
        let mid = cleaned.index(cleaned.startIndex, offsetBy: 3)
        return "\(cleaned[..<mid]) \(cleaned[mid...])"
    }

    /// Formats the Today screen date header (e.g. `"Wednesday, Nov 25"`).
    public static func formatHeaderDate(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = posixLocale
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = timeZone
        formatter.dateFormat = "EEEE, MMM d"
        return formatter.string(from: date)
    }

    /// Formats a 7-day Rhythm week range header (e.g. `"Nov 19 – 25"` or `"Nov 28 – Dec 4"`).
    public static func formatWeekRange(start: Date, end: Date, timeZone: TimeZone = .current) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let monthDay = DateFormatter()
        monthDay.locale = posixLocale
        monthDay.calendar = calendar
        monthDay.timeZone = timeZone
        monthDay.dateFormat = "MMM d"

        let startComps = calendar.dateComponents([.month, .day], from: start)
        let endComps = calendar.dateComponents([.month, .day], from: end)
        if startComps.month == endComps.month, let endDay = endComps.day {
            return "\(monthDay.string(from: start)) – \(endDay)"
        }
        return "\(monthDay.string(from: start)) – \(monthDay.string(from: end))"
    }

    /// Computes a calm age string from `YYYY-MM-DD` (e.g. `"8 months"`).
    public static func formatAge(birthDate: String?, asOf referenceDate: Date, timeZone: TimeZone = .current) -> String {
        guard let birthDate else { return "" }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let parts = birthDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3,
              let born = calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
        else {
            return ""
        }
        let comps = calendar.dateComponents([.year, .month, .day], from: born, to: referenceDate)
        let totalMonths = max(0, (comps.year ?? 0) * 12 + (comps.month ?? 0))
        if totalMonths == 0 {
            let days = max(0, comps.day ?? 0)
            let weeks = days / 7
            if weeks >= 2 {
                return "\(weeks) weeks"
            }
            return days == 1 ? "1 day" : "\(days) days"
        }
        if totalMonths < 24 {
            return totalMonths == 1 ? "1 month" : "\(totalMonths) months"
        }
        let years = totalMonths / 12
        let remMonths = totalMonths % 12
        if remMonths == 0 {
            return years == 1 ? "1 year" : "\(years) years"
        }
        return "\(years)y \(remMonths)m"
    }

    /// Formats a breast side label (`"Left side"`, `"Right side"`, `"Both sides"`).
    public static func formatSide(_ side: BreastSide) -> String {
        switch side {
        case .left: "Left side"
        case .right: "Right side"
        case .both: "Both sides"
        }
    }

    /// Returns the display title for a logged event, matching the design system voice.
    public static func eventTitle(_ event: EventDTO, napNumber: Int? = nil) -> String {
        switch event.metadata {
        case .sleep(let meta):
            if meta.sleepType == .night {
                return "Night sleep"
            }
            if let napNumber {
                return "Nap \(napNumber)"
            }
            return "Nap"
        case .feeding(let meta):
            return meta.method == .breast ? "Nursing" : "Bottle"
        case .pump:
            return "Pump"
        case .diaper:
            return "Diaper"
        case .meal(let meta):
            switch meta.mealSlot {
            case .breakfast: return "Breakfast"
            case .lunch: return "Lunch"
            case .dinner: return "Dinner"
            case .snack: return "Snack"
            case .none: return "Meal"
            }
        case .bath:
            return "Bath"
        case .medicine(let meta):
            let trimmed = meta.name.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Meds & care" : trimmed
        case .note:
            return "Note"
        }
    }

    /// Returns the calm single-line event detail subtitle matching the design system voice.
    public static func eventDetail(
        _ event: EventDTO,
        preferredUnit: VolumeUnit = .oz,
        timeZone: TimeZone? = nil
    ) -> String {
        let tz = timeZone ?? TimeZone(identifier: event.timezone) ?? .current
        let noteText = event.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        let nonEmptyNote = (noteText?.isEmpty == false) ? noteText : nil

        switch event.metadata {
        case .sleep(let meta):
            var parts: [String] = []
            if let endedAt = event.endedAt {
                let minutes = max(0, endedAt.timeIntervalSince(event.startedAt) / 60.0)
                parts.append(formatRange(event.startedAt, endedAt, timeZone: tz))
                parts.append(formatDuration(minutes: minutes))
            } else {
                parts.append("Since \(formatClock(event.startedAt, timeZone: tz))")
            }
            if let location = meta.location {
                parts.append(location.rawValue.capitalized)
            }
            return parts.joined(separator: " · ")

        case .feeding(let meta):
            if meta.method == .breast {
                let leftSec = meta.leftDurationSeconds ?? 0
                let rightSec = meta.rightDurationSeconds ?? 0
                let fallbackMinutes: Double = {
                    if let durationMinutes = meta.durationMinutes {
                        return durationMinutes
                    }
                    if let endedAt = event.endedAt {
                        return max(0, endedAt.timeIntervalSince(event.startedAt) / 60.0)
                    }
                    return Double(leftSec + rightSec) / 60.0
                }()
                if leftSec > 0 && rightSec > 0 {
                    let lm = max(1, Int((Double(leftSec) / 60.0).rounded()))
                    let rm = max(1, Int((Double(rightSec) / 60.0).rounded()))
                    let total = max(Int(fallbackMinutes.rounded()), lm + rm)
                    return "\(total)m · Left \(lm)m, Right \(rm)m"
                }
                let total = max(1, Int(fallbackMinutes.rounded()))
                let side = meta.side ?? (leftSec > 0 ? .left : (rightSec > 0 ? .right : .both))
                return "\(total)m · \(formatSide(side))"
            }

            let amountText: String
            if let amountMl = meta.amountMl {
                let displayValue = preferredUnit == .oz ? UnitConversion.mlToOz(amountMl) : amountMl
                amountText = formatAmount(displayValue, unit: preferredUnit)
            } else {
                amountText = formatAmount(0, unit: preferredUnit)
            }
            let substanceText: String = switch meta.substance {
            case .formula: "formula"
            case .breastMilk: "breast milk"
            case .mixed: "mixed"
            }
            return "\(amountText) \(substanceText)"

        case .pump(let meta):
            let amountText: String
            if let amountMl = meta.amountMl {
                let displayValue = preferredUnit == .oz ? UnitConversion.mlToOz(amountMl) : amountMl
                amountText = formatAmount(displayValue, unit: preferredUnit)
            } else {
                amountText = formatAmount(0, unit: preferredUnit)
            }
            return "\(amountText) · \(formatSide(meta.side))"

        case .diaper(let meta):
            var parts: [String] = []
            if let pee = meta.peeSize {
                parts.append("Pee \(pee.shortLabel)")
            }
            if let poop = meta.poopSize {
                parts.append("Poop \(poop.shortLabel)")
            }
            if meta.rash {
                parts.append("Rash")
            }
            return parts.isEmpty ? "Dry" : parts.joined(separator: " · ")

        case .meal(let meta):
            var parts: [String] = []
            if let nonEmptyNote {
                parts.append(nonEmptyNote)
            }
            if let portion = meta.portionEaten {
                let portionLabel: String = switch portion {
                case .none: "None eaten"
                case .some: "Some eaten"
                case .most: "Most eaten"
                }
                parts.append(portionLabel)
            }
            return parts.isEmpty ? "Logged" : parts.joined(separator: " · ")

        case .bath(let meta):
            var parts = [meta.washedHair ? "Hair shampooed" : "No shampoo"]
            if let nonEmptyNote {
                parts.append(nonEmptyNote)
            }
            return parts.joined(separator: " · ")

        case .medicine(let meta):
            if meta.category == .topical {
                var parts = ["Topical"]
                if let nonEmptyNote {
                    parts.append(nonEmptyNote)
                }
                return parts.joined(separator: " · ")
            }
            guard let doseValue = meta.dose else {
                var parts = [meta.category.rawValue.capitalized]
                if let nonEmptyNote {
                    parts.append(nonEmptyNote)
                }
                return parts.joined(separator: " · ")
            }
            let doseNumber = formatNumber(doseValue, maxFractionDigits: 2)
            let unitLabel = formatDoseUnit(dose: doseValue, unit: meta.unit)
            let doseSegment = unitLabel.isEmpty ? doseNumber : "\(doseNumber) \(unitLabel)"
            return "\(doseSegment) · \(meta.category.rawValue)"

        case .note:
            return nonEmptyNote ?? "No text"
        }
    }

    public static func formatDoseUnit(dose: Double, unit: DoseUnit?) -> String {
        guard let unit else { return "" }
        switch unit {
        case .ml: return "mL"
        case .drops: return abs(dose - 1.0) < 0.0001 ? "drop" : "drops"
        case .mg: return "mg"
        }
    }
}
