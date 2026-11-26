import Foundation

public enum UnitConversion: Sendable {
    /// Exact US fluid ounce to milliliter conversion factor (`1 US fl oz = 29.5735 mL`).
    public static let mlPerUsFluidOunce: Double = 29.5735

    private static let unicodeFractions: [Character: Double] = [
        "½": 0.5,
        "¼": 0.25,
        "¾": 0.75,
        "⅓": 1.0 / 3.0,
        "⅔": 2.0 / 3.0,
        "⅕": 0.2,
        "⅖": 0.4,
        "⅗": 0.6,
        "⅘": 0.8,
        "⅙": 1.0 / 6.0,
        "⅚": 5.0 / 6.0,
        "⅛": 0.125,
        "⅜": 0.375,
        "⅝": 0.625,
        "⅞": 0.875
    ]

    /// Ordered longest-first so multi-word suffixes like `fl. oz.` strip before `oz`.
    private static let recognizedUnitSuffixes: [String] = [
        "milliliters",
        "milliliter",
        "fl. oz.",
        "fl oz.",
        "fl. oz",
        "fl oz",
        "ounces",
        "ounce",
        "drops",
        "drop",
        "tbsp.",
        "tbsp",
        "tsp.",
        "tsp",
        "mcg",
        "oz.",
        "oz",
        "ml.",
        "ml",
        "mg.",
        "mg",
        "cc"
    ]

    /// Converts US fluid ounces to milliliters, rounded cleanly to 1 decimal place (e.g., `3 oz` -> `88.7 mL`).
    public static func ozToMl(_ oz: Double) -> Double {
        let rounded = (oz * mlPerUsFluidOunce * 10.0).rounded() / 10.0
        return rounded == 0 ? 0 : rounded
    }

    /// Converts milliliters to US fluid ounces, rounded cleanly to 2 decimal places (preserving all 2-decimal `oz` inputs losslessly).
    public static func mlToOz(_ ml: Double) -> Double {
        let rounded = (ml / mlPerUsFluidOunce * 100.0).rounded() / 100.0
        return rounded == 0 ? 0 : rounded
    }

    /// Parses arbitrary decimals (`"3.25"`, `"4.7"`, `"85"`), Unicode fractions (`"2½"`, `"3¼"`, `"4¾"`, `"½"`),
    /// ASCII fractions & mixed fractions (`"1/2"`, `"2 1/2"`, `"3 1/4"`, `"2-1/2"`), and optional unit suffixes
    /// (`"2½ oz"`, `"85 mL"`). Rejects ranges like `"2-4 oz"` or `"2–4 oz"`.
    public static func parseFlexibleNumber(_ raw: String) -> Double? {
        var working = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !working.isEmpty else { return nil }

        working = stripRecognizedUnitSuffix(from: working)
        guard !working.isEmpty else { return nil }

        if working.hasPrefix("+") {
            working.removeFirst()
            working = working.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !working.isEmpty else { return nil }
        }

        // Reject en-dash / em-dash ranges immediately (e.g., "2–4").
        if working.contains("–") || working.contains("—") {
            return nil
        }

        // 1. Unicode fraction (standalone like "½" or mixed like "2½", "2 ½").
        if let lastChar = working.last, let fractionValue = unicodeFractions[lastChar] {
            let prefix = working.dropLast().trimmingCharacters(in: .whitespacesAndNewlines)
            if prefix.isEmpty {
                return fractionValue
            }
            guard isAsciiDigits(prefix), let whole = Double(prefix) else {
                return nil
            }
            return whole + fractionValue
        }

        // 2. ASCII fraction or mixed fraction ("1/2", "2 1/2", "3 1/4", "2-1/2").
        if working.contains("/") {
            return parseAsciiFraction(working)
        }

        // 3. Plain decimal ("3.25", "4.7", "85", ".5").
        return parsePlainDecimal(working)
    }

    /// Convenience parser that extracts both the numeric amount and an optional volume unit (`oz` or `ml`).
    public static func parseVolumeAmount(_ raw: String) -> (value: Double, unit: VolumeUnit?)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = parseFlexibleNumber(trimmed) else { return nil }

        let lowered = trimmed.lowercased()
        let unit: VolumeUnit?
        if lowered.hasSuffix("ml") || lowered.hasSuffix("ml.") || lowered.hasSuffix("milliliter") || lowered.hasSuffix("milliliters") {
            unit = .ml
        } else if lowered.hasSuffix("oz") || lowered.hasSuffix("oz.") || lowered.hasSuffix("ounce") || lowered.hasSuffix("ounces") {
            unit = .oz
        } else {
            unit = nil
        }
        return (value, unit)
    }

    private static func stripRecognizedUnitSuffix(from input: String) -> String {
        let lowered = input.lowercased()
        for suffix in recognizedUnitSuffixes {
            guard lowered.hasSuffix(suffix) else { continue }
            let endIndex = input.index(input.endIndex, offsetBy: -suffix.count)
            let prefix = input[..<endIndex]
            // Ensure suffix is separated by whitespace or follows a digit/fraction/dot (not mid-word).
            if let lastPrefixChar = prefix.last,
               lastPrefixChar.isLetter {
                continue
            }
            return prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return input
    }

    private static func parseAsciiFraction(_ text: String) -> Double? {
        let slashParts = text.split(separator: "/", omittingEmptySubsequences: false)
        guard slashParts.count == 2 else { return nil }

        let denominatorText = slashParts[1].trimmingCharacters(in: .whitespacesAndNewlines)
        guard isAsciiDigits(denominatorText),
              let denominator = Double(denominatorText),
              denominator > 0
        else {
            return nil
        }

        let leftSide = slashParts[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard !leftSide.isEmpty else { return nil }

        // Standalone fraction: "3/4"
        if isAsciiDigits(leftSide), let numerator = Double(leftSide) {
            return numerator / denominator
        }

        // Hyphenated mixed fraction: "2-1/2"
        if leftSide.contains("-") {
            let hyphenParts = leftSide.split(separator: "-", omittingEmptySubsequences: false)
            guard hyphenParts.count == 2 else { return nil }
            let wholeText = hyphenParts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let numeratorText = hyphenParts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            guard isAsciiDigits(wholeText), isAsciiDigits(numeratorText),
                  let whole = Double(wholeText), let numerator = Double(numeratorText)
            else {
                return nil
            }
            return whole + (numerator / denominator)
        }

        // Space-separated mixed fraction: "2 1/2"
        let spaceParts = leftSide.split(whereSeparator: \.isWhitespace)
        guard spaceParts.count == 2 else { return nil }
        let wholeText = String(spaceParts[0])
        let numeratorText = String(spaceParts[1])
        guard isAsciiDigits(wholeText), isAsciiDigits(numeratorText),
              let whole = Double(wholeText), let numerator = Double(numeratorText)
        else {
            return nil
        }
        return whole + (numerator / denominator)
    }

    private static func parsePlainDecimal(_ text: String) -> Double? {
        var sawDot = false
        var sawDigit = false
        for character in text {
            if character >= "0" && character <= "9" {
                sawDigit = true
            } else if character == "." && !sawDot {
                sawDot = true
            } else {
                return nil
            }
        }
        guard sawDigit, let value = Double(text), value.isFinite else {
            return nil
        }
        return value == 0 ? 0 : value
    }

    private static func isAsciiDigits<S: StringProtocol>(_ text: S) -> Bool {
        !text.isEmpty && text.allSatisfy { $0 >= "0" && $0 <= "9" }
    }
}
