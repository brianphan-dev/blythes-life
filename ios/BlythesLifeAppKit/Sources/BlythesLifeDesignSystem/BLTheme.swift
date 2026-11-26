import Foundation
import SwiftUI

// MARK: - OKLCH Conversion

/// Exact OKLCH -> OKLab -> linear sRGB -> sRGB conversion matching CSS Color 4.
public enum BLColorPrimitives {
    /// Converts CSS `oklch(l c h / opacity)` into an exact sRGB SwiftUI `Color`.
    public static func oklch(
        _ l: Double,
        _ c: Double,
        _ hDegrees: Double,
        opacity: Double = 1.0
    ) -> Color {
        let hRad = hDegrees * .pi / 180.0
        let a = c * cos(hRad)
        let b = c * sin(hRad)

        let lPrime = l + 0.3963377774 * a + 0.2158037573 * b
        let mPrime = l - 0.1055613458 * a - 0.0638541728 * b
        let sPrime = l - 0.0894841775 * a - 1.2914855480 * b

        let lCubed = lPrime * lPrime * lPrime
        let mCubed = mPrime * mPrime * mPrime
        let sCubed = sPrime * sPrime * sPrime

        let rLinear = +4.0767416621 * lCubed - 3.3077115913 * mCubed + 0.2309699292 * sCubed
        let gLinear = -1.2684380046 * lCubed + 2.6097574011 * mCubed - 0.3413193965 * sCubed
        let bLinear = -0.0041960863 * lCubed - 0.7034186147 * mCubed + 1.7076147010 * sCubed

        return Color(
            .sRGB,
            red: compandSRGB(rLinear),
            green: compandSRGB(gLinear),
            blue: compandSRGB(bLinear),
            opacity: opacity
        )
    }

    private static func compandSRGB(_ linear: Double) -> Double {
        let clamped = min(max(linear, 0.0), 1.0)
        if clamped <= 0.0031308 {
            return 12.92 * clamped
        }
        return 1.055 * pow(clamped, 1.0 / 2.4) - 0.055
    }

    // Paper neutrals — warm, hue 85->70
    public static let paper0 = oklch(0.995, 0.004, 85)    // #FFFDFA
    public static let paper50 = oklch(0.975, 0.01, 85)    // #FAF6EF
    public static let paper100 = oklch(0.95, 0.014, 85)   // #F3EEE4
    public static let paper200 = oklch(0.915, 0.016, 85)  // #E8E2D7
    public static let paper300 = oklch(0.86, 0.018, 85)   // #D6D0C4
    public static let paper400 = oklch(0.72, 0.018, 80)   // #ABA498
    public static let paper500 = oklch(0.54, 0.018, 75)   // #756D63
    public static let paper600 = oklch(0.46, 0.018, 70)   // #5F564D
    public static let paper700 = oklch(0.36, 0.018, 70)   // #433C33
    public static let paper800 = oklch(0.27, 0.016, 70)   // #2C251E
    public static let paper900 = oklch(0.2, 0.014, 70)    // #1A150F
    public static let paper950 = oklch(0.15, 0.01, 70)    // #0E0A07

    // Night neutrals — OLED black up
    public static let night0 = Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 1) // #000000
    public static let night50 = oklch(0.12, 0.006, 80)    // #070604
    public static let night100 = oklch(0.16, 0.008, 80)   // #0F0D09
    public static let night200 = oklch(0.2, 0.01, 80)     // #181611
    public static let night300 = oklch(0.25, 0.012, 80)   // #25211B
    public static let night400 = oklch(0.34, 0.014, 80)   // #3C3730
    public static let night500 = oklch(0.56, 0.025, 80)   // #7C7364
    public static let night600 = oklch(0.68, 0.03, 82)    // #A29784
    public static let night700 = oklch(0.86, 0.035, 85)   // #DCD0B8

    // Honey — brand accent
    public static let honey100 = oklch(0.96, 0.045, 90)   // #FDF1D0
    public static let honey200 = oklch(0.92, 0.08, 88)    // #FBE2A7
    public static let honey300 = oklch(0.87, 0.12, 86)    // #F7CF73
    public static let honey400 = oklch(0.82, 0.145, 82)   // #F3BA44
    public static let honey500 = oklch(0.77, 0.15, 78)    // #E8A628
    public static let honey600 = oklch(0.66, 0.14, 70)    // #C8800D
    public static let honey700 = oklch(0.52, 0.115, 65)   // #955905
    public static let honey800 = oklch(0.4, 0.085, 62)    // #683C0B
    public static let honey900 = oklch(0.26, 0.05, 80)    // #312103

    // Sleep — violet
    public static let sleep100 = oklch(0.94, 0.035, 285)  // #E8E8FF
    public static let sleep300 = oklch(0.8, 0.08, 285)    // #B8B7F0
    public static let sleep500 = oklch(0.62, 0.12, 285)   // #7F7BCB
    public static let sleep700 = oklch(0.42, 0.11, 285)   // #484286
    public static let sleep900 = oklch(0.26, 0.06, 285)   // #211F40

    // Feeding & Nursing — apricot
    public static let feeding100 = oklch(0.94, 0.04, 50)  // #FFE4D4
    public static let feeding300 = oklch(0.8, 0.09, 50)   // #EEAD89
    public static let feeding500 = oklch(0.68, 0.13, 50)  // #D77E49
    public static let feeding700 = oklch(0.45, 0.11, 45)  // #853E19
    public static let feeding900 = oklch(0.26, 0.05, 50)  // #371C0C

    // Diaper — teal
    public static let diaper100 = oklch(0.94, 0.035, 200) // #D1F3F4
    public static let diaper300 = oklch(0.8, 0.075, 200)  // #81CDD1
    public static let diaper500 = oklch(0.64, 0.095, 200) // #319DA3
    public static let diaper700 = oklch(0.42, 0.075, 205) // #005860
    public static let diaper900 = oklch(0.26, 0.045, 200) // #002A2D

    // Meal — green
    public static let meal100 = oklch(0.94, 0.045, 145)   // #D9F4D9
    public static let meal300 = oklch(0.8, 0.09, 145)     // #99CE9A
    public static let meal500 = oklch(0.64, 0.12, 145)    // #5A9F5D
    public static let meal700 = oklch(0.42, 0.095, 148)   // #215B2D
    public static let meal900 = oklch(0.26, 0.05, 145)    // #132A14

    // Bath — blue
    public static let bath100 = oklch(0.94, 0.03, 245)    // #DBEEFE
    public static let bath300 = oklch(0.8, 0.075, 245)    // #95C3EB
    public static let bath500 = oklch(0.63, 0.11, 245)    // #4A8FC7
    public static let bath700 = oklch(0.42, 0.1, 250)     // #194F81
    public static let bath900 = oklch(0.26, 0.05, 245)    // #0C263A

    // Medicine — pink
    public static let medicine100 = oklch(0.94, 0.035, 345) // #FEE2F1
    public static let medicine300 = oklch(0.8, 0.085, 345)  // #E6A8CA
    public static let medicine500 = oklch(0.64, 0.13, 345)  // #C3699E
    public static let medicine700 = oklch(0.43, 0.12, 348)  // #7D2F5B
    public static let medicine900 = oklch(0.26, 0.055, 345) // #36182A

    // Pump — orchid
    public static let pump100 = oklch(0.94, 0.035, 315)   // #F4E5FC
    public static let pump300 = oklch(0.8, 0.085, 315)    // #D3AEE4
    public static let pump500 = oklch(0.63, 0.13, 315)    // #A66FBF
    public static let pump700 = oklch(0.43, 0.12, 315)    // #68387C
    public static let pump900 = oklch(0.26, 0.055, 315)   // #2E1B36

    // Status — amber, green, red
    public static let amber100 = oklch(0.95, 0.06, 75)    // #FFEAC2
    public static let amber300 = oklch(0.82, 0.12, 70)    // #F6B669
    public static let amber500 = oklch(0.74, 0.16, 62)    // #F19024
    public static let amber700 = oklch(0.47, 0.12, 55)    // #8C4400
    public static let amber900 = oklch(0.27, 0.06, 65)    // #3A1F00

    public static let green100 = oklch(0.94, 0.045, 155)  // #D5F5DE
    public static let green300 = oklch(0.8, 0.09, 155)    // #8ECFA4
    public static let green500 = oklch(0.62, 0.13, 155)   // #349D62
    public static let green700 = oklch(0.42, 0.1, 155)    // #095C34
    public static let green900 = oklch(0.26, 0.05, 155)   // #0C2B19

    public static let red100 = oklch(0.94, 0.035, 25)     // #FFE3DF
    public static let red300 = oklch(0.8, 0.1, 25)        // #F8A49D
    public static let red500 = oklch(0.6, 0.18, 25)       // #D74745
    public static let red700 = oklch(0.45, 0.15, 25)      // #972527
    public static let red900 = oklch(0.27, 0.07, 25)      // #431614

    // Scrims & Shadows
    public static let scrimDay = oklch(0.2, 0.014, 70, opacity: 0.38)
    public static let scrimNight = Color(.sRGB, red: 0, green: 0, blue: 0, opacity: 0.62)
    public static let shadowSheetDay = oklch(0.2, 0.014, 70, opacity: 0.14)
    public static let shadowFloatPrimaryDay = oklch(0.2, 0.014, 70, opacity: 0.18)
    public static let shadowFloatSecondaryDay = oklch(0.2, 0.014, 70, opacity: 0.12)
}

// MARK: - Color Mode & Triplets

/// First-class theme mode: warm paper Day or OLED low-blue Night.
public enum BLColorMode: String, CaseIterable, Sendable, Hashable {
    case day
    case night
}

/// Tint / solid / ink semantic color triplet for events and statuses.
public struct BLColorTriplet: Sendable, Hashable {
    public let tint: Color
    public let solid: Color
    public let ink: Color

    public init(tint: Color, solid: Color, ink: Color) {
        self.tint = tint
        self.solid = solid
        self.ink = ink
    }
}

// MARK: - Semantic Palette

/// Complete semantic theme palette from `tokens/colors.css`.
public struct BLPalette: Sendable, Equatable {
    public let mode: BLColorMode

    // Surfaces
    public let bgApp: Color
    public let bgSurface: Color
    public let bgSunken: Color
    public let bgRaised: Color

    // Borders
    public let borderHairline: Color
    public let borderStrong: Color

    // Text
    public let textPrimary: Color
    public let textSecondary: Color
    public let textTertiary: Color
    public let textOnAccent: Color

    // Brand accent (Honey)
    public let accent: Color
    public let accentPressed: Color
    public let accentSoft: Color
    public let accentBorder: Color
    public let accentText: Color

    // Overlays & Toast
    public let scrim: Color
    public let toastBg: Color
    public let toastFg: Color
    public let toastAction: Color

    // Event triplets (all 9 BLEventKinds)
    public let sleep: BLColorTriplet
    public let feeding: BLColorTriplet
    public let nursing: BLColorTriplet
    public let pump: BLColorTriplet
    public let diaper: BLColorTriplet
    public let meal: BLColorTriplet
    public let bath: BLColorTriplet
    public let medicine: BLColorTriplet
    public let note: BLColorTriplet

    // Status triplets
    public let warn: BLColorTriplet
    public let ok: BLColorTriplet
    public let danger: BLColorTriplet

    // Floating elevation (shadows in Day, 1px outline in Night)
    public let sheetShadowColor: Color
    public let floatShadowPrimaryColor: Color
    public let floatShadowSecondaryColor: Color
    public let nightFloatOutline: Color?

    /// Returns the semantic `tint` / `solid` / `ink` triplet for any event kind.
    public func event(_ kind: BLEventKind) -> BLColorTriplet {
        switch kind {
        case .sleep: sleep
        case .feeding: feeding
        case .nursing: nursing
        case .pump: pump
        case .diaper: diaper
        case .meal: meal
        case .bath: bath
        case .medicine: medicine
        case .note: note
        }
    }

    public static func palette(for mode: BLColorMode) -> BLPalette {
        switch mode {
        case .day: .day
        case .night: .night
        }
    }

    /// Warm paper Day palette (default).
    public static let day = BLPalette(
        mode: .day,
        bgApp: BLColorPrimitives.paper50,
        bgSurface: BLColorPrimitives.paper0,
        bgSunken: BLColorPrimitives.paper100,
        bgRaised: BLColorPrimitives.paper0,
        borderHairline: BLColorPrimitives.paper200,
        borderStrong: BLColorPrimitives.paper300,
        textPrimary: BLColorPrimitives.paper900,
        textSecondary: BLColorPrimitives.paper600,
        textTertiary: BLColorPrimitives.paper500,
        textOnAccent: BLColorPrimitives.paper900,
        accent: BLColorPrimitives.honey400,
        accentPressed: BLColorPrimitives.honey500,
        accentSoft: BLColorPrimitives.honey100,
        accentBorder: BLColorPrimitives.honey500,
        accentText: BLColorPrimitives.honey700,
        scrim: BLColorPrimitives.scrimDay,
        toastBg: BLColorPrimitives.paper900,
        toastFg: BLColorPrimitives.paper50,
        toastAction: BLColorPrimitives.honey300,
        sleep: BLColorTriplet(
            tint: BLColorPrimitives.sleep100,
            solid: BLColorPrimitives.sleep500,
            ink: BLColorPrimitives.sleep700
        ),
        feeding: BLColorTriplet(
            tint: BLColorPrimitives.feeding100,
            solid: BLColorPrimitives.feeding500,
            ink: BLColorPrimitives.feeding700
        ),
        nursing: BLColorTriplet(
            tint: BLColorPrimitives.feeding100,
            solid: BLColorPrimitives.feeding500,
            ink: BLColorPrimitives.feeding700
        ),
        pump: BLColorTriplet(
            tint: BLColorPrimitives.pump100,
            solid: BLColorPrimitives.pump500,
            ink: BLColorPrimitives.pump700
        ),
        diaper: BLColorTriplet(
            tint: BLColorPrimitives.diaper100,
            solid: BLColorPrimitives.diaper500,
            ink: BLColorPrimitives.diaper700
        ),
        meal: BLColorTriplet(
            tint: BLColorPrimitives.meal100,
            solid: BLColorPrimitives.meal500,
            ink: BLColorPrimitives.meal700
        ),
        bath: BLColorTriplet(
            tint: BLColorPrimitives.bath100,
            solid: BLColorPrimitives.bath500,
            ink: BLColorPrimitives.bath700
        ),
        medicine: BLColorTriplet(
            tint: BLColorPrimitives.medicine100,
            solid: BLColorPrimitives.medicine500,
            ink: BLColorPrimitives.medicine700
        ),
        note: BLColorTriplet(
            tint: BLColorPrimitives.paper100,
            solid: BLColorPrimitives.paper500,
            ink: BLColorPrimitives.paper700
        ),
        warn: BLColorTriplet(
            tint: BLColorPrimitives.amber100,
            solid: BLColorPrimitives.amber500,
            ink: BLColorPrimitives.amber700
        ),
        ok: BLColorTriplet(
            tint: BLColorPrimitives.green100,
            solid: BLColorPrimitives.green500,
            ink: BLColorPrimitives.green700
        ),
        danger: BLColorTriplet(
            tint: BLColorPrimitives.red100,
            solid: BLColorPrimitives.red500,
            ink: BLColorPrimitives.red700
        ),
        sheetShadowColor: BLColorPrimitives.shadowSheetDay,
        floatShadowPrimaryColor: BLColorPrimitives.shadowFloatPrimaryDay,
        floatShadowSecondaryColor: BLColorPrimitives.shadowFloatSecondaryDay,
        nightFloatOutline: nil
    )

    /// OLED true-black, warm low-blue Night palette.
    public static let night = BLPalette(
        mode: .night,
        bgApp: BLColorPrimitives.night0,
        bgSurface: BLColorPrimitives.night100,
        bgSunken: BLColorPrimitives.night50,
        bgRaised: BLColorPrimitives.night200,
        borderHairline: BLColorPrimitives.night300,
        borderStrong: BLColorPrimitives.night400,
        textPrimary: BLColorPrimitives.night700,
        textSecondary: BLColorPrimitives.night600,
        textTertiary: BLColorPrimitives.night500,
        textOnAccent: BLColorPrimitives.paper950,
        accent: BLColorPrimitives.honey600,
        accentPressed: BLColorPrimitives.honey700,
        accentSoft: BLColorPrimitives.honey900,
        accentBorder: BLColorPrimitives.honey700,
        accentText: BLColorPrimitives.honey400,
        scrim: BLColorPrimitives.scrimNight,
        toastBg: BLColorPrimitives.night300,
        toastFg: BLColorPrimitives.night700,
        toastAction: BLColorPrimitives.honey400,
        sleep: BLColorTriplet(
            tint: BLColorPrimitives.sleep900,
            solid: BLColorPrimitives.sleep500,
            ink: BLColorPrimitives.sleep300
        ),
        feeding: BLColorTriplet(
            tint: BLColorPrimitives.feeding900,
            solid: BLColorPrimitives.feeding500,
            ink: BLColorPrimitives.feeding300
        ),
        nursing: BLColorTriplet(
            tint: BLColorPrimitives.feeding900,
            solid: BLColorPrimitives.feeding500,
            ink: BLColorPrimitives.feeding300
        ),
        pump: BLColorTriplet(
            tint: BLColorPrimitives.pump900,
            solid: BLColorPrimitives.pump500,
            ink: BLColorPrimitives.pump300
        ),
        diaper: BLColorTriplet(
            tint: BLColorPrimitives.diaper900,
            solid: BLColorPrimitives.diaper500,
            ink: BLColorPrimitives.diaper300
        ),
        meal: BLColorTriplet(
            tint: BLColorPrimitives.meal900,
            solid: BLColorPrimitives.meal500,
            ink: BLColorPrimitives.meal300
        ),
        bath: BLColorTriplet(
            tint: BLColorPrimitives.bath900,
            solid: BLColorPrimitives.bath500,
            ink: BLColorPrimitives.bath300
        ),
        medicine: BLColorTriplet(
            tint: BLColorPrimitives.medicine900,
            solid: BLColorPrimitives.medicine500,
            ink: BLColorPrimitives.medicine300
        ),
        note: BLColorTriplet(
            tint: BLColorPrimitives.night200,
            solid: BLColorPrimitives.night500,
            ink: BLColorPrimitives.night600
        ),
        warn: BLColorTriplet(
            tint: BLColorPrimitives.amber900,
            solid: BLColorPrimitives.amber500,
            ink: BLColorPrimitives.amber300
        ),
        ok: BLColorTriplet(
            tint: BLColorPrimitives.green900,
            solid: BLColorPrimitives.green500,
            ink: BLColorPrimitives.green300
        ),
        danger: BLColorTriplet(
            tint: BLColorPrimitives.red900,
            solid: BLColorPrimitives.red500,
            ink: BLColorPrimitives.red300
        ),
        sheetShadowColor: .clear,
        floatShadowPrimaryColor: .clear,
        floatShadowSecondaryColor: .clear,
        nightFloatOutline: BLColorPrimitives.night400
    )
}

// MARK: - Environment Integration

private struct BLThemeKey: EnvironmentKey {
    static let defaultValue: BLPalette = .day
}

private struct BLColorModeKey: EnvironmentKey {
    static let defaultValue: BLColorMode = .day
}

extension EnvironmentValues {
    /// Active Blythe's Life semantic palette.
    public var blTheme: BLPalette {
        get { self[BLThemeKey.self] }
        set { self[BLThemeKey.self] = newValue }
    }

    /// Active Blythe's Life color mode (`.day` or `.night`).
    public var blColorMode: BLColorMode {
        get { self[BLColorModeKey.self] }
        set { self[BLColorModeKey.self] = newValue }
    }
}

extension View {
    /// Applies the canonical Day or Night palette and matches system `preferredColorScheme`.
    public func blTheme(_ mode: BLColorMode) -> some View {
        self
            .environment(\.blColorMode, mode)
            .environment(\.blTheme, BLPalette.palette(for: mode))
            .preferredColorScheme(mode == .night ? .dark : .light)
    }
}
