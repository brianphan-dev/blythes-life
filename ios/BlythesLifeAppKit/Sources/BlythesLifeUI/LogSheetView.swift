import BlythesLifeCore
import BlythesLifeDesignSystem
import BlythesLifeShared
import SwiftUI

/// Presentation descriptor for opening any of the nine daily-log sheets in create or edit mode.
public struct LogSheetRequest: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var kind: BLEventKind
    public var editingEvent: EventDTO?

    public init(id: UUID = UUID(), kind: BLEventKind, editingEvent: EventDTO? = nil) {
        self.id = id
        self.kind = kind
        self.editingEvent = editingEvent
    }
}

/// Interactive bottom sheet hosting all nine Blythe's Life daily-care log forms (create & edit).
@MainActor
public struct LogSheetView: View {
    private enum NursingInputMode: String, CaseIterable, Hashable {
        case timer = "Timer"
        case manual = "Enter minutes"
    }

    private enum PumpInputMode: String, CaseIterable, Hashable {
        case manual = "Enter details"
        case timer = "Timer"
    }

    private enum PumpVolumeMode: String, CaseIterable, Hashable {
        case bySide = "By side"
        case combined = "Combined"
    }

    private struct ResolvedPumpInput {
        var combinedAmount: Double?
        var leftAmount: Double?
        var rightAmount: Double?
        var totalDisplayAmount: Double
        var sessionDurationMinutes: Double?
        var leftDurationMinutes: Double?
        var rightDurationMinutes: Double?
        var side: BreastSide
    }

    private enum DiaperSelection: String, CaseIterable, Hashable {
        case none = "None"
        case small = "S"
        case medium = "M"
        case large = "L"

        var diaperSize: DiaperSize? {
            switch self {
            case .none: nil
            case .small: .small
            case .medium: .medium
            case .large: .large
            }
        }

        static func from(_ size: DiaperSize?) -> DiaperSelection {
            switch size {
            case .none: .none
            case .small: .small
            case .medium: .medium
            case .large: .large
            }
        }
    }

    private enum MedPreset: String, CaseIterable, Hashable, Identifiable {
        case vitaminD = "Vitamin D"
        case tylenol = "Infant Tylenol"
        case buttCream = "Butt cream"
        case salineDrops = "Saline drops"
        case gasDrops = "Gas drops"
        case custom = "Custom"

        var id: String { rawValue }

        var defaultDose: String? {
            switch self {
            case .vitaminD: "1"
            case .tylenol: "2.5"
            case .buttCream: nil
            case .salineDrops: "2"
            case .gasDrops: "0.3"
            case .custom: ""
            }
        }

        var defaultUnit: DoseUnit {
            switch self {
            case .vitaminD, .salineDrops: .drops
            case .tylenol, .gasDrops, .buttCream, .custom: .ml
            }
        }

        var defaultCategory: MedicineCategory {
            switch self {
            case .vitaminD: .supplement
            case .buttCream: .topical
            case .tylenol, .salineDrops, .gasDrops, .custom: .medicine
            }
        }
    }

    private static let bottleOzPresets = ["2", "2.5", "3", "3.25", "4", "5"]
    private static let bottleMlPresets = ["60", "75", "90", "100", "120", "150"]
    private static let pumpSideOzPresets = ["1", "1.5", "2", "2.5", "3", "4"]
    private static let pumpSideMlPresets = ["30", "45", "60", "75", "90", "120"]
    private static let pumpOzPresets = ["2", "3", "4", "5", "6", "8"]
    private static let pumpMlPresets = ["60", "90", "120", "150", "180", "240"]
    private static let pumpMinutePresets = ["10", "15", "20", "25", "30"]
    private static let nurseMinutePresets = ["5", "10", "15", "20", "25", "30"]
    private static let relativeAgoOptions: [(minutes: Int, label: String)] = [
        (0, "Now"),
        (5, "5m ago"),
        (15, "15m ago")
    ]

    @Environment(\.blTheme) private var theme

    private let store: BlythesLifeStore
    private let request: LogSheetRequest
    private let showScrim: Bool
    private let onClose: () -> Void

    // Time state
    @State private var agoMinutes: Int = 0
    @State private var usesCustomTime: Bool = false
    @State private var exactTime: Date

    // Sleep state
    @State private var sleepType: SleepType = .nap
    @State private var userSelectedSleepType: Bool
    @State private var sleepStart: Date
    @State private var sleepEnd: Date

    // Bottle & Pump state
    @State private var amountText: String
    @State private var volumeUnit: VolumeUnit
    @State private var substance: FeedingSubstance = .formula
    @State private var includeVitaminD: Bool = false
    @State private var pumpMode: PumpInputMode
    @State private var pumpVolumeMode: PumpVolumeMode
    @State private var pumpLeftAmountText: String
    @State private var pumpRightAmountText: String
    @State private var focusedPumpVolumeSide: BreastSide
    @State private var splitPumpTimes: Bool
    @State private var pumpDurationText: String
    @State private var pumpLeftDurationText: String
    @State private var pumpRightDurationText: String
    @State private var focusedPumpDurationSide: BreastSide

    // Nursing state
    @State private var nursingMode: NursingInputMode = .timer
    @State private var nursingLeftMinutesText: String
    @State private var nursingRightMinutesText: String
    @State private var focusedNursingSide: BreastSide
    @State private var nursingLastSide: BreastSide
    @State private var userSelectedNursingLastSide: Bool

    // Diaper state
    @State private var peeSelection: DiaperSelection = .medium
    @State private var poopSelection: DiaperSelection = .none
    @State private var poopColor: PoopColor?
    @State private var poopConsistency: PoopConsistency?
    @State private var diaperRash: Bool = false

    // Meal state
    @State private var mealSlot: MealSlot
    @State private var userSelectedMealSlot: Bool
    @State private var mealAte: String = ""
    @State private var mealPortion: PortionEaten = .most

    // Bath state
    @State private var washedHair: Bool = false
    @State private var bathNotes: String = ""

    // Medicine state
    @State private var medPreset: MedPreset = .vitaminD
    @State private var customMedName: String = ""
    @State private var customMedCategory: MedicineCategory = .medicine
    @State private var medDoseText: String = "1"
    @State private var medDoseUnit: DoseUnit = .drops

    // Note state
    @State private var noteText: String = ""

    public init(
        store: BlythesLifeStore,
        request: LogSheetRequest,
        showScrim: Bool = true,
        onClose: @escaping () -> Void
    ) {
        self.store = store
        self.request = request
        self.showScrim = showScrim
        self.onClose = onClose

        let now = store.now
        let preferredUnit = store.preferredUnit
        let isMl = preferredUnit == .ml

        // Default values for create mode
        var initAgo = 0
        var initUsesCustom = false
        var initExact = now
        var initSleepStart = store.activeNapStart ?? now.addingTimeInterval(-3600)
        var initSleepEnd = now
        var initSleepType: SleepType = .nap
        if request.kind == .sleep && request.editingEvent == nil {
            if store.activeNapStart != nil {
                initSleepType = store.isActiveSleepNight ? .night : .nap
            } else {
                initSleepType = store.classifySleep(start: initSleepStart, end: initSleepEnd)
            }
        }
        var initAmount = request.kind == .pump ? "" : (isMl ? "95" : "3.25")
        var initUnit = preferredUnit
        var initSubstance: FeedingSubstance = .formula
        let initPumpMode: PumpInputMode = (store.activePump != nil && request.editingEvent == nil) ? .timer : .manual
        var initPumpVolumeMode: PumpVolumeMode = .bySide
        var initPumpLeftAmount = ""
        var initPumpRightAmount = ""
        var initFocusedPumpVolumeSide: BreastSide = .left
        var initSplitPumpTimes = false
        var initPumpDuration = ""
        var initPumpLeftDuration = ""
        var initPumpRightDuration = ""
        var initFocusedPumpDurationSide: BreastSide = .left

        var initNurseMode: NursingInputMode = .timer
        var initNurseLeftMinutes = ""
        var initNurseRightMinutes = ""
        var initFocusedNursingSide: BreastSide = {
            switch store.lastNursingSideInfo?.side {
            case .left: .right
            case .right: .left
            case .both, .none: .left
            }
        }()
        var initNurseLastSide: BreastSide = initFocusedNursingSide
        var initUserSelectedNursingLastSide = false

        var initPee: DiaperSelection = .medium
        var initPoop: DiaperSelection = .none
        var initPoopColor: PoopColor? = nil
        var initPoopConsistency: PoopConsistency? = nil
        var initRash = false
        var initSlot = store.classifyMealSlot(for: initExact)
        var initAte = ""
        var initPortion: PortionEaten = .most
        var initHair = false
        var initBathNote = ""
        var initMedPreset: MedPreset = .vitaminD
        var initCustomMedName = ""
        var initCustomMedCat: MedicineCategory = .medicine
        var initMedDose = "1"
        var initMedUnit: DoseUnit = .drops
        var initNote = ""

        if let editing = request.editingEvent {
            initAgo = 0
            initUsesCustom = true
            initExact = editing.startedAt
            initNurseMode = .manual

            switch editing.metadata {
            case .sleep(let meta):
                initSleepType = meta.sleepType
                initSleepStart = editing.startedAt
                initSleepEnd = editing.endedAt ?? now

            case .feeding(let meta):
                if meta.method == .breast {
                    let lSec = meta.leftDurationSeconds ?? 0
                    let rSec = meta.rightDurationSeconds ?? 0
                    if lSec > 0 || rSec > 0 {
                        initNurseLeftMinutes = lSec > 0
                            ? FormattingHelpers.formatNumber(max(0.1, Double(lSec) / 60.0), maxFractionDigits: 1)
                            : ""
                        initNurseRightMinutes = rSec > 0
                            ? FormattingHelpers.formatNumber(max(0.1, Double(rSec) / 60.0), maxFractionDigits: 1)
                            : ""
                    } else {
                        let mins = meta.durationMinutes
                            ?? editing.endedAt.map { max(1, $0.timeIntervalSince(editing.startedAt) / 60.0) }
                            ?? 0
                        if mins > 0 {
                            switch meta.side {
                            case .left:
                                initNurseLeftMinutes = FormattingHelpers.formatNumber(mins, maxFractionDigits: 1)
                                initNurseRightMinutes = ""
                            case .right:
                                initNurseLeftMinutes = ""
                                initNurseRightMinutes = FormattingHelpers.formatNumber(mins, maxFractionDigits: 1)
                            case .both, .none:
                                let half = FormattingHelpers.formatNumber(mins / 2.0, maxFractionDigits: 1)
                                initNurseLeftMinutes = half
                                initNurseRightMinutes = half
                            }
                        } else {
                            initNurseLeftMinutes = ""
                            initNurseRightMinutes = ""
                        }
                    }

                    let hasLeft = (Double(initNurseLeftMinutes) ?? 0) > 0
                    let hasRight = (Double(initNurseRightMinutes) ?? 0) > 0
                    initFocusedNursingSide = (!hasLeft && hasRight) ? .right : .left
                    if let storedLast = meta.lastSide, storedLast == .left || storedLast == .right {
                        initNurseLastSide = storedLast
                    } else if hasRight && !hasLeft {
                        initNurseLastSide = .right
                    } else if hasLeft && !hasRight {
                        initNurseLastSide = .left
                    } else {
                        initNurseLastSide = meta.side == .left ? .left : .right
                    }
                    initUserSelectedNursingLastSide = true
                } else {
                    initUnit = meta.displayUnit
                    if let ml = meta.amountMl {
                        let displayed = initUnit == .oz ? UnitConversion.mlToOz(ml) : ml
                        initAmount = FormattingHelpers.formatNumber(
                            displayed,
                            maxFractionDigits: initUnit == .oz ? 2 : 1
                        )
                    }
                    initSubstance = meta.substance
                }

            case .pump(let meta):
                initUnit = meta.displayUnit
                let formatPumpVol: (Double) -> String = { ml in
                    let displayed = initUnit == .oz ? UnitConversion.mlToOz(ml) : ml
                    return FormattingHelpers.formatNumber(
                        displayed,
                        maxFractionDigits: initUnit == .oz ? 2 : 1
                    )
                }

                if meta.leftAmountMl != nil || meta.rightAmountMl != nil {
                    initPumpVolumeMode = .bySide
                    if let leftMl = meta.leftAmountMl, leftMl > 0 {
                        initPumpLeftAmount = formatPumpVol(leftMl)
                    } else {
                        initPumpLeftAmount = ""
                    }
                    if let rightMl = meta.rightAmountMl, rightMl > 0 {
                        initPumpRightAmount = formatPumpVol(rightMl)
                    } else {
                        initPumpRightAmount = ""
                    }
                    initAmount = ""
                    initFocusedPumpVolumeSide = (initPumpLeftAmount.isEmpty && !initPumpRightAmount.isEmpty) ? .right : .left
                } else if meta.side == .left {
                    initPumpVolumeMode = .bySide
                    if let ml = meta.amountMl, ml > 0 {
                        initPumpLeftAmount = formatPumpVol(ml)
                    } else {
                        initPumpLeftAmount = ""
                    }
                    initPumpRightAmount = ""
                    initAmount = ""
                    initFocusedPumpVolumeSide = .left
                } else if meta.side == .right {
                    initPumpVolumeMode = .bySide
                    initPumpLeftAmount = ""
                    if let ml = meta.amountMl, ml > 0 {
                        initPumpRightAmount = formatPumpVol(ml)
                    } else {
                        initPumpRightAmount = ""
                    }
                    initAmount = ""
                    initFocusedPumpVolumeSide = .right
                } else {
                    initPumpVolumeMode = .combined
                    if let ml = meta.amountMl, ml > 0 {
                        initAmount = formatPumpVol(ml)
                    } else {
                        initAmount = ""
                    }
                    initPumpLeftAmount = ""
                    initPumpRightAmount = ""
                    initFocusedPumpVolumeSide = .left
                }

                let lSec = meta.leftDurationSeconds ?? 0
                let rSec = meta.rightDurationSeconds ?? 0
                if lSec > 0 && rSec > 0 {
                    if abs(lSec - rSec) >= 30 {
                        initSplitPumpTimes = true
                        initPumpLeftDuration = FormattingHelpers.formatNumber(
                            max(0.1, Double(lSec) / 60.0),
                            maxFractionDigits: 1
                        )
                        initPumpRightDuration = FormattingHelpers.formatNumber(
                            max(0.1, Double(rSec) / 60.0),
                            maxFractionDigits: 1
                        )
                        initPumpDuration = ""
                    } else {
                        initSplitPumpTimes = false
                        let mins = meta.durationMinutes ?? (Double(max(lSec, rSec)) / 60.0)
                        initPumpDuration = mins > 0
                            ? FormattingHelpers.formatNumber(mins, maxFractionDigits: 1)
                            : ""
                    }
                } else if lSec > 0 && rSec == 0 && (meta.amountMl ?? 0) <= 0 {
                    initSplitPumpTimes = true
                    initPumpLeftDuration = FormattingHelpers.formatNumber(
                        max(0.1, Double(lSec) / 60.0),
                        maxFractionDigits: 1
                    )
                    initPumpRightDuration = ""
                    initPumpDuration = ""
                    initFocusedPumpDurationSide = .left
                } else if rSec > 0 && lSec == 0 && (meta.amountMl ?? 0) <= 0 {
                    initSplitPumpTimes = true
                    initPumpLeftDuration = ""
                    initPumpRightDuration = FormattingHelpers.formatNumber(
                        max(0.1, Double(rSec) / 60.0),
                        maxFractionDigits: 1
                    )
                    initPumpDuration = ""
                    initFocusedPumpDurationSide = .right
                } else {
                    initSplitPumpTimes = false
                    if let mins = meta.durationMinutes
                        ?? editing.endedAt.map({ max(0, $0.timeIntervalSince(editing.startedAt) / 60.0) }),
                       mins > 0
                    {
                        initPumpDuration = FormattingHelpers.formatNumber(mins, maxFractionDigits: 1)
                    } else {
                        initPumpDuration = ""
                    }
                }

            case .diaper(let meta):
                initPee = DiaperSelection.from(meta.peeSize)
                initPoop = DiaperSelection.from(meta.poopSize)
                initPoopColor = meta.poopSize == nil ? nil : meta.poopColor
                initPoopConsistency = meta.poopSize == nil ? nil : meta.poopConsistency
                initRash = meta.rash

            case .meal(let meta):
                initSlot = meta.mealSlot ?? store.classifyMealSlot(
                    for: editing.startedAt,
                    excludingEventId: editing.id
                )
                initAte = editing.notes ?? ""
                initPortion = meta.portionEaten ?? .most

            case .bath(let meta):
                initHair = meta.washedHair
                initBathNote = editing.notes ?? ""

            case .medicine(let meta):
                if let matched = MedPreset.allCases.first(where: {
                    $0 != .custom && $0.rawValue.caseInsensitiveCompare(meta.name) == .orderedSame
                }) {
                    initMedPreset = matched
                } else {
                    initMedPreset = .custom
                    initCustomMedName = meta.name
                }
                initCustomMedCat = meta.category
                if let dose = meta.dose {
                    initMedDose = FormattingHelpers.formatNumber(dose, maxFractionDigits: 2)
                } else {
                    initMedDose = ""
                }
                initMedUnit = meta.unit ?? .ml

            case .note:
                initNote = editing.notes ?? ""
            }
        }

        _agoMinutes = State(initialValue: initAgo)
        _usesCustomTime = State(initialValue: initUsesCustom)
        _exactTime = State(initialValue: initExact)
        _sleepType = State(initialValue: initSleepType)
        _userSelectedSleepType = State(initialValue: request.editingEvent != nil)
        _sleepStart = State(initialValue: initSleepStart)
        _sleepEnd = State(initialValue: initSleepEnd)
        _amountText = State(initialValue: initAmount)
        _volumeUnit = State(initialValue: initUnit)
        _substance = State(initialValue: initSubstance)
        _pumpMode = State(initialValue: initPumpMode)
        _pumpVolumeMode = State(initialValue: initPumpVolumeMode)
        _pumpLeftAmountText = State(initialValue: initPumpLeftAmount)
        _pumpRightAmountText = State(initialValue: initPumpRightAmount)
        _focusedPumpVolumeSide = State(initialValue: initFocusedPumpVolumeSide)
        _splitPumpTimes = State(initialValue: initSplitPumpTimes)
        _pumpDurationText = State(initialValue: initPumpDuration)
        _pumpLeftDurationText = State(initialValue: initPumpLeftDuration)
        _pumpRightDurationText = State(initialValue: initPumpRightDuration)
        _focusedPumpDurationSide = State(initialValue: initFocusedPumpDurationSide)
        _nursingMode = State(initialValue: initNurseMode)
        _nursingLeftMinutesText = State(initialValue: initNurseLeftMinutes)
        _nursingRightMinutesText = State(initialValue: initNurseRightMinutes)
        _focusedNursingSide = State(initialValue: initFocusedNursingSide)
        _nursingLastSide = State(initialValue: initNurseLastSide)
        _userSelectedNursingLastSide = State(initialValue: initUserSelectedNursingLastSide)
        _peeSelection = State(initialValue: initPee)
        _poopSelection = State(initialValue: initPoop)
        _poopColor = State(initialValue: initPoopColor)
        _poopConsistency = State(initialValue: initPoopConsistency)
        _diaperRash = State(initialValue: initRash)
        _mealSlot = State(initialValue: initSlot)
        _userSelectedMealSlot = State(initialValue: request.editingEvent != nil)
        _mealAte = State(initialValue: initAte)
        _mealPortion = State(initialValue: initPortion)
        _washedHair = State(initialValue: initHair)
        _bathNotes = State(initialValue: initBathNote)
        _medPreset = State(initialValue: initMedPreset)
        _customMedName = State(initialValue: initCustomMedName)
        _customMedCategory = State(initialValue: initCustomMedCat)
        _medDoseText = State(initialValue: initMedDose)
        _medDoseUnit = State(initialValue: initMedUnit)
        _noteText = State(initialValue: initNote)
    }

    private var isEditing: Bool {
        request.editingEvent != nil
    }

    private var isActiveNapStartMode: Bool {
        request.kind == .sleep && !isEditing && store.activeNapStart != nil
    }

    private var isNursingTimerMode: Bool {
        request.kind == .nursing && !isEditing && (store.activeNursing != nil || nursingMode == .timer)
    }

    private var isPumpTimerMode: Bool {
        request.kind == .pump && !isEditing && (store.activePump != nil || pumpMode == .timer)
    }

    private func resolvedCommitTimestamp() -> Date {
        if usesCustomTime {
            return exactTime
        }
        return store.now.addingTimeInterval(-TimeInterval(agoMinutes * 60))
    }

    private var timeRowLabel: String? {
        if request.kind == .sleep || isNursingTimerMode || isPumpTimerMode {
            return nil
        }
        if request.kind == .nursing {
            return "Started"
        }
        return "Time"
    }

    private var effectiveMedicineCategory: MedicineCategory {
        medPreset == .custom ? customMedCategory : medPreset.defaultCategory
    }

    private var isTopicalMedicine: Bool {
        effectiveMedicineCategory == .topical
    }

    private var resolvedSleepInterval: (start: Date, end: Date, durationMinutes: Double, startedYesterday: Bool) {
        let cal = store.profileCalendar
        var start = sleepStart
        let end = sleepEnd
        var startedYesterday = false

        if sleepType == .night {
            let startComps = cal.dateComponents([.hour, .minute], from: start)
            let endComps = cal.dateComponents([.hour, .minute], from: end)
            let startMin = (startComps.hour ?? 0) * 60 + (startComps.minute ?? 0)
            let endMin = (endComps.hour ?? 0) * 60 + (endComps.minute ?? 0)
            if start >= end && startMin >= endMin {
                if let shifted = cal.date(byAdding: .day, value: -1, to: start) {
                    start = shifted
                    startedYesterday = true
                }
            } else if !cal.isDate(start, inSameDayAs: end) && start < end {
                startedYesterday = true
            }
        }

        let minutes = end.timeIntervalSince(start) / 60.0
        return (start, end, minutes, startedYesterday)
    }

    private var parsedNursingLeftMinutes: Double {
        max(0, Double(nursingLeftMinutesText) ?? 0)
    }

    private var parsedNursingRightMinutes: Double {
        max(0, Double(nursingRightMinutesText) ?? 0)
    }

    private var parsedPumpLeftAmount: Double {
        max(0, Double(pumpLeftAmountText) ?? 0)
    }

    private var parsedPumpRightAmount: Double {
        max(0, Double(pumpRightAmountText) ?? 0)
    }

    private var parsedPumpSharedDuration: Double {
        max(0, Double(pumpDurationText) ?? 0)
    }

    private var parsedPumpLeftDuration: Double {
        max(0, Double(pumpLeftDurationText) ?? 0)
    }

    private var parsedPumpRightDuration: Double {
        max(0, Double(pumpRightDurationText) ?? 0)
    }

    private var resolvedManualPumpInput: ResolvedPumpInput {
        let leftAmt = pumpVolumeMode == .bySide ? parsedPumpLeftAmount : 0
        let rightAmt = pumpVolumeMode == .bySide ? parsedPumpRightAmount : 0
        let combinedAmt = pumpVolumeMode == .combined ? max(0, Double(amountText) ?? 0) : 0
        let totalDisplayAmount = pumpVolumeMode == .bySide ? (leftAmt + rightAmt) : combinedAmt

        let leftDur: Double?
        let rightDur: Double?
        let sessionDur: Double?

        if splitPumpTimes {
            leftDur = parsedPumpLeftDuration > 0 ? parsedPumpLeftDuration : nil
            rightDur = parsedPumpRightDuration > 0 ? parsedPumpRightDuration : nil
            if leftDur != nil || rightDur != nil {
                sessionDur = max(leftDur ?? 0, rightDur ?? 0)
            } else {
                sessionDur = nil
            }
        } else {
            let sharedDur = parsedPumpSharedDuration > 0 ? parsedPumpSharedDuration : nil
            sessionDur = sharedDur
            if let sharedDur {
                if leftAmt > 0 && rightAmt <= 0 {
                    leftDur = sharedDur
                    rightDur = nil
                } else if rightAmt > 0 && leftAmt <= 0 {
                    leftDur = nil
                    rightDur = sharedDur
                } else if leftAmt > 0 && rightAmt > 0 {
                    leftDur = sharedDur
                    rightDur = sharedDur
                } else {
                    leftDur = nil
                    rightDur = nil
                }
            } else {
                leftDur = nil
                rightDur = nil
            }
        }

        let hasLeft = leftAmt > 0 || (leftDur ?? 0) > 0
        let hasRight = rightAmt > 0 || (rightDur ?? 0) > 0
        let derivedSide: BreastSide
        if hasLeft && hasRight {
            derivedSide = .both
        } else if hasLeft {
            derivedSide = .left
        } else if hasRight {
            derivedSide = .right
        } else {
            derivedSide = .both
        }

        return ResolvedPumpInput(
            combinedAmount: combinedAmt > 0 ? combinedAmt : nil,
            leftAmount: leftAmt > 0 ? leftAmt : nil,
            rightAmount: rightAmt > 0 ? rightAmt : nil,
            totalDisplayAmount: totalDisplayAmount,
            sessionDurationMinutes: sessionDur,
            leftDurationMinutes: leftDur,
            rightDurationMinutes: rightDur,
            side: derivedSide
        )
    }

    private var canCommit: Bool {
        switch request.kind {
        case .sleep:
            if isActiveNapStartMode { return true }
            return resolvedSleepInterval.durationMinutes > 0
        case .nursing:
            if isNursingTimerMode {
                return store.activeNursing != nil
            }
            return (parsedNursingLeftMinutes + parsedNursingRightMinutes) > 0
        case .feeding:
            return (Double(amountText) ?? 0) > 0
        case .pump:
            if isPumpTimerMode {
                return store.activePump != nil
            }
            let resolved = resolvedManualPumpInput
            return resolved.totalDisplayAmount > 0 || (resolved.sessionDurationMinutes ?? 0) > 0
        case .diaper, .meal, .bath, .medicine, .note:
            return true
        }
    }

    private var ctaTitle: String {
        if isEditing {
            if request.kind == .sleep && resolvedSleepInterval.durationMinutes <= 0 {
                return "End is before start"
            }
            return "Save changes"
        }

        switch request.kind {
        case .sleep:
            if isActiveNapStartMode {
                let currentType: SleepType = store.isActiveSleepNight ? .night : .nap
                let startChanged = abs((store.activeNapStart ?? sleepStart).timeIntervalSince(sleepStart)) >= 1.0
                if sleepType != currentType && !startChanged {
                    return sleepType == .night ? "Switch to night sleep" : "Switch to nap"
                }
                let clock = FormattingHelpers.formatClock(sleepStart, timeZone: store.profileTimeZone)
                return "Save · \(clock)"
            }
            let interval = resolvedSleepInterval
            guard interval.durationMinutes > 0 else {
                return "End is before start"
            }
            let dur = FormattingHelpers.formatDuration(minutes: interval.durationMinutes)
            return "Log \(dur) \(sleepType == .night ? "night sleep" : "nap")"

        case .feeding:
            let shown = amountText.isEmpty ? "0" : amountText
            return "Log \(shown) \(volumeUnitLabel(volumeUnit))"

        case .nursing:
            let total = parsedNursingLeftMinutes + parsedNursingRightMinutes
            guard total > 0 else {
                return "Enter minutes"
            }
            let formatted = FormattingHelpers.formatNumber(total, maxFractionDigits: 1)
            return "Log \(formatted) min nursing"

        case .pump:
            let resolved = resolvedManualPumpInput
            var parts: [String] = []
            if resolved.totalDisplayAmount > 0 {
                parts.append(FormattingHelpers.formatAmount(resolved.totalDisplayAmount, unit: volumeUnit))
            }
            if let sessionDur = resolved.sessionDurationMinutes, sessionDur > 0 {
                let mins = FormattingHelpers.formatNumber(sessionDur, maxFractionDigits: 1)
                parts.append("\(mins)m")
            }
            if parts.isEmpty {
                return "Enter output or time"
            }
            return "Log \(parts.joined(separator: " · ")) pumped"

        case .diaper:
            return "Log diaper"

        case .meal:
            return "Log \(mealSlotLabel(mealSlot).lowercased())"

        case .bath:
            return "Log bath"

        case .medicine:
            if medPreset == .custom {
                let trimmed = customMedName.trimmingCharacters(in: .whitespacesAndNewlines)
                return "Log \(trimmed.isEmpty ? "care" : trimmed)"
            }
            return "Log \(medPreset.rawValue)"

        case .note:
            return "Save note"
        }
    }

    public var body: some View {
        BLSheetContainer(
            isPresented: true,
            title: request.kind.displayLabel,
            showScrim: showScrim,
            onClose: onClose,
            icon: {
                BLEventIcon(kind: request.kind, size: .md)
            },
            content: {
                formBody

                if let label = timeRowLabel {
                    timeFieldSection(label: label)
                }
            },
            footer: {
                HStack(spacing: BLSpacing.space2) {
                    if let editing = request.editingEvent {
                        BLButton(
                            icon: BLSymbol.trash,
                            accessibilityLabel: "Delete entry",
                            variant: .danger,
                            size: .lg
                        ) {
                            store.deleteEvent(editing)
                            onClose()
                        }
                    } else if isNursingTimerMode && store.activeNursing != nil {
                        BLButton(
                            icon: BLSymbol.trash,
                            accessibilityLabel: "Discard timer",
                            variant: .danger,
                            size: .lg
                        ) {
                            store.discardNursing()
                            onClose()
                        }
                    } else if isPumpTimerMode && store.activePump != nil {
                        BLButton(
                            icon: BLSymbol.trash,
                            accessibilityLabel: "Discard timer",
                            variant: .danger,
                            size: .lg
                        ) {
                            store.discardPumpTimer()
                            onClose()
                        }
                    }

                    if isNursingTimerMode {
                        LiveNursingCommitButton(
                            store: store,
                            canCommit: canCommit,
                            action: commit
                        )
                    } else if isPumpTimerMode {
                        LivePumpCommitButton(
                            store: store,
                            isBySideVolumeMode: pumpVolumeMode == .bySide,
                            combinedAmountText: amountText,
                            leftAmountText: pumpLeftAmountText,
                            rightAmountText: pumpRightAmountText,
                            volumeUnit: volumeUnit,
                            canCommit: canCommit,
                            action: commit
                        )
                    } else {
                        BLButton(
                            ctaTitle,
                            variant: .primary,
                            size: .lg,
                            isBlock: true,
                            action: commit
                        )
                        .disabled(!canCommit)
                    }
                }
            }
        )
        .onChange(of: sleepStart) { _, _ in
            guard request.kind == .sleep && !isEditing && !isActiveNapStartMode && !userSelectedSleepType else {
                return
            }
            sleepType = store.classifySleep(start: sleepStart, end: sleepEnd > sleepStart ? sleepEnd : nil)
        }
        .onChange(of: sleepEnd) { _, _ in
            guard request.kind == .sleep && !isEditing && !isActiveNapStartMode && !userSelectedSleepType else {
                return
            }
            sleepType = store.classifySleep(start: sleepStart, end: sleepEnd > sleepStart ? sleepEnd : nil)
        }
        .onChange(of: exactTime) { _, newTime in
            guard request.kind == .meal && !isEditing && !userSelectedMealSlot else {
                return
            }
            mealSlot = store.classifyMealSlot(for: newTime)
        }
        .onChange(of: nursingLeftMinutesText) { _, newValue in
            guard request.kind == .nursing else { return }
            if (Double(newValue) ?? 0) > 0 && !userSelectedNursingLastSide {
                nursingLastSide = .left
            }
        }
        .onChange(of: nursingRightMinutesText) { _, newValue in
            guard request.kind == .nursing else { return }
            if (Double(newValue) ?? 0) > 0 && !userSelectedNursingLastSide {
                nursingLastSide = .right
            }
        }
    }

    // MARK: - Form Sections

    @ViewBuilder
    private var formBody: some View {
        switch request.kind {
        case .sleep:
            sleepForm
        case .feeding:
            bottleForm
        case .nursing:
            nursingForm
        case .pump:
            pumpForm
        case .diaper:
            diaperForm
        case .meal:
            mealForm
        case .bath:
            bathForm
        case .medicine:
            medicineForm
        case .note:
            noteForm
        }
    }

    @ViewBuilder
    private var sleepForm: some View {
        if isActiveNapStartMode {
            BLSegmentedControl(
                options: [SleepType.nap, .night],
                selection: $sleepType,
                size: .md,
                isBlock: true
            ) { option in
                option == .nap ? "Nap" : "Night sleep"
            }

            BLTimeField(label: "Fell asleep", date: $sleepStart)
            Text("The timer keeps running on every device.")
                .blTextRole(.callout)
                .foregroundStyle(theme.textSecondary)
        } else {
            let interval = resolvedSleepInterval
            let manualSleepTypeBinding = Binding<SleepType>(
                get: { sleepType },
                set: { newType in
                    userSelectedSleepType = true
                    sleepType = newType
                }
            )

            BLSegmentedControl(
                options: [SleepType.nap, .night],
                selection: manualSleepTypeBinding,
                size: .lg,
                isBlock: true
            ) { option in
                option == .nap ? "Nap" : "Night sleep"
            }

            HStack(spacing: BLSpacing.space3) {
                BLTimeField(label: "Start", date: $sleepStart)
                    .frame(maxWidth: .infinity, alignment: .leading)
                BLTimeField(label: "End", date: $sleepEnd)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(
                interval.durationMinutes > 0
                    ? "\(FormattingHelpers.formatDuration(minutes: interval.durationMinutes)) asleep\(interval.startedYesterday ? " · started yesterday" : "")"
                    : "Pick an end time after the start."
            )
            .blTextRole(.callout)
            .foregroundStyle(theme.textSecondary)
        }
    }

    private var bottleForm: some View {
        VStack(alignment: .leading, spacing: BLSpacing.space5) {
            volumeAmountRow

            presetChipsRow(
                presets: volumeUnit == .oz ? Self.bottleOzPresets : Self.bottleMlPresets,
                selected: amountText
            ) { chosen in
                amountText = chosen
            }

            BLSegmentedControl(
                options: [FeedingSubstance.formula, .breastMilk, .mixed],
                selection: $substance,
                size: .lg,
                isBlock: true
            ) { item in
                switch item {
                case .formula: "Formula"
                case .breastMilk: "Breast milk"
                case .mixed: "Mixed"
                }
            }

            if !isEditing {
                BLCheckbox(
                    isChecked: $includeVitaminD,
                    label: "+ Vitamin D",
                    sub: "Logs a supplement alongside this bottle"
                )
            }
        }
    }

    @ViewBuilder
    private var nursingForm: some View {
        if isNursingTimerMode {
            VStack(alignment: .leading, spacing: BLSpacing.space4) {
                if store.activeNursing != nil {
                    LiveNursingTimerSection(store: store)
                } else {
                    let lastInfo = store.lastNursingSideInfo

                    BLSegmentedControl(
                        options: NursingInputMode.allCases,
                        selection: $nursingMode,
                        isBlock: true
                    ) { $0.rawValue }

                    BLNursingTimer(
                        leftSeconds: 0,
                        rightSeconds: 0,
                        activeSide: nil,
                        lastSide: lastInfo?.side.rawValue
                    ) { sideId in
                        store.tapNursingSide(sideId == "right" ? .right : .left)
                    }

                    Text(
                        lastInfo.map { last in
                            "Last time ended on \(sideShortLabel(last.side)) · \(FormattingHelpers.formatClock(last.at, timeZone: store.profileTimeZone)). Tap a side to start."
                        } ?? "Tap a side to start the timer."
                    )
                    .blTextRole(.callout)
                    .foregroundStyle(theme.textSecondary)
                }
            }
        } else {
            let lastInfo = store.lastNursingSideInfo
            let focusedLabel = focusedNursingSide == .left ? "Left" : "Right"

            VStack(alignment: .leading, spacing: BLSpacing.space5) {
                if !isEditing {
                    BLSegmentedControl(
                        options: NursingInputMode.allCases,
                        selection: $nursingMode,
                        isBlock: true
                    ) { $0.rawValue }
                }

                VStack(alignment: .leading, spacing: BLSpacing.space3) {
                    HStack(spacing: BLSpacing.space2) {
                        sideInputCard(
                            label: "Left",
                            text: $nursingLeftMinutesText,
                            unit: "min",
                            isFocused: focusedNursingSide == .left,
                            accentColor: theme.event(.nursing).solid,
                            showLastBadge: !isEditing && lastInfo?.side == .left
                        ) {
                            focusedNursingSide = .left
                        }

                        sideInputCard(
                            label: "Right",
                            text: $nursingRightMinutesText,
                            unit: "min",
                            isFocused: focusedNursingSide == .right,
                            accentColor: theme.event(.nursing).solid,
                            showLastBadge: !isEditing && lastInfo?.side == .right
                        ) {
                            focusedNursingSide = .right
                        }
                    }

                    presetChipsRow(
                        presets: Self.nurseMinutePresets,
                        selected: focusedNursingSide == .left ? nursingLeftMinutesText : nursingRightMinutesText
                    ) { chosen in
                        if focusedNursingSide == .left {
                            nursingLeftMinutesText = (nursingLeftMinutesText == chosen ? "" : chosen)
                        } else {
                            nursingRightMinutesText = (nursingRightMinutesText == chosen ? "" : chosen)
                        }
                    }

                    if !isEditing {
                        Text(
                            lastInfo.map { last in
                                "Last ended on \(sideShortLabel(last.side)) · \(FormattingHelpers.formatClock(last.at, timeZone: store.profileTimeZone)). Presets fill \(focusedLabel)."
                            } ?? "Presets fill \(focusedLabel)."
                        )
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)
                    }
                }

                if parsedNursingLeftMinutes > 0 && parsedNursingRightMinutes > 0 {
                    let endedOnBinding = Binding<BreastSide>(
                        get: { nursingLastSide },
                        set: { newSide in
                            userSelectedNursingLastSide = true
                            nursingLastSide = newSide
                        }
                    )

                    labeledField("Ended on") {
                        BLSegmentedControl(
                            options: [BreastSide.left, .right],
                            selection: endedOnBinding,
                            size: .md,
                            isBlock: true
                        ) { sideShortLabel($0) }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var pumpForm: some View {
        if isPumpTimerMode {
            VStack(alignment: .leading, spacing: BLSpacing.space4) {
                if store.activePump == nil {
                    BLSegmentedControl(
                        options: PumpInputMode.allCases,
                        selection: $pumpMode,
                        isBlock: true
                    ) { $0.rawValue }
                }

                LivePumpTimerSection(store: store)

                if let session = store.activePump {
                    let leftUsed = session.leftAccumulatedSeconds > 0 || session.isLeftRunning
                    let rightUsed = session.rightAccumulatedSeconds > 0 || session.isRightRunning

                    if leftUsed && !rightUsed {
                        pumpSingleSideOutputSection(
                            title: "Left output (optional)",
                            text: $pumpLeftAmountText
                        )
                    } else if rightUsed && !leftUsed {
                        pumpSingleSideOutputSection(
                            title: "Right output (optional)",
                            text: $pumpRightAmountText
                        )
                    } else {
                        pumpOutputSection(title: "Output (optional)")
                    }
                }
            }
        } else {
            VStack(alignment: .leading, spacing: BLSpacing.space5) {
                if !isEditing {
                    BLSegmentedControl(
                        options: PumpInputMode.allCases,
                        selection: $pumpMode,
                        isBlock: true
                    ) { $0.rawValue }
                }

                pumpOutputSection(title: "Output")

                pumpDurationSection
            }
        }
    }

    private var pumpVolumeModeBinding: Binding<PumpVolumeMode> {
        Binding<PumpVolumeMode>(
            get: { pumpVolumeMode },
            set: { newMode in
                guard newMode != pumpVolumeMode else { return }
                if newMode == .combined {
                    let sum = parsedPumpLeftAmount + parsedPumpRightAmount
                    if sum > 0 {
                        amountText = FormattingHelpers.formatNumber(
                            sum,
                            maxFractionDigits: volumeUnit == .oz ? 2 : 1
                        )
                    }
                }
                pumpVolumeMode = newMode
            }
        )
    }

    private var pumpUnitBinding: Binding<VolumeUnit> {
        Binding<VolumeUnit>(
            get: { volumeUnit },
            set: { newUnit in
                guard newUnit != volumeUnit else { return }
                amountText = convertVolumeText(amountText, to: newUnit)
                pumpLeftAmountText = convertVolumeText(pumpLeftAmountText, to: newUnit)
                pumpRightAmountText = convertVolumeText(pumpRightAmountText, to: newUnit)
                volumeUnit = newUnit
            }
        )
    }

    private func convertVolumeText(_ raw: String, to newUnit: VolumeUnit) -> String {
        guard let parsed = Double(raw), parsed > 0 else { return raw }
        if newUnit == .ml {
            let ml = UnitConversion.ozToMl(parsed)
            let roundedStep = (ml / 5.0).rounded() * 5.0
            let result = roundedStep > 0 ? roundedStep : max(1.0, ml.rounded())
            return FormattingHelpers.formatNumber(result, maxFractionDigits: 0)
        } else {
            let oz = UnitConversion.mlToOz(parsed)
            let quarterStep = (oz * 4.0).rounded() / 4.0
            let result = quarterStep > 0 ? quarterStep : max(0.1, (oz * 10.0).rounded() / 10.0)
            return FormattingHelpers.formatNumber(result, maxFractionDigits: 2)
        }
    }

    private func toggleSplitPumpTimes() {
        if !splitPumpTimes {
            let shared = parsedPumpSharedDuration
            if shared > 0 && pumpLeftDurationText.isEmpty && pumpRightDurationText.isEmpty {
                let leftAmt = parsedPumpLeftAmount
                let rightAmt = parsedPumpRightAmount
                if pumpVolumeMode == .bySide && leftAmt > 0 && rightAmt <= 0 {
                    pumpLeftDurationText = pumpDurationText
                    focusedPumpDurationSide = .left
                } else if pumpVolumeMode == .bySide && rightAmt > 0 && leftAmt <= 0 {
                    pumpRightDurationText = pumpDurationText
                    focusedPumpDurationSide = .right
                } else {
                    pumpLeftDurationText = pumpDurationText
                    pumpRightDurationText = pumpDurationText
                }
            }
            splitPumpTimes = true
        } else {
            let maxDur = max(parsedPumpLeftDuration, parsedPumpRightDuration)
            pumpDurationText = maxDur > 0
                ? FormattingHelpers.formatNumber(maxDur, maxFractionDigits: 1)
                : ""
            splitPumpTimes = false
        }
    }

    private func pumpSingleSideOutputSection(title: String, text: Binding<String>) -> some View {
        labeledField(title) {
            VStack(alignment: .leading, spacing: BLSpacing.space3) {
                HStack(alignment: .bottom, spacing: BLSpacing.space4) {
                    BLAmountField(
                        text: text,
                        unit: volumeUnitLabel(volumeUnit),
                        placeholder: "0"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    BLSegmentedControl(
                        options: [VolumeUnit.oz, .ml],
                        selection: pumpUnitBinding,
                        size: .sm
                    ) { volumeUnitLabel($0) }
                }

                presetChipsRow(
                    presets: volumeUnit == .oz ? Self.pumpSideOzPresets : Self.pumpSideMlPresets,
                    selected: text.wrappedValue
                ) { chosen in
                    text.wrappedValue = (text.wrappedValue == chosen ? "" : chosen)
                }
            }
        }
    }

    private func pumpOutputSection(title: String) -> some View {
        let leftVal = parsedPumpLeftAmount
        let rightVal = parsedPumpRightAmount
        let focusedLabel = focusedPumpVolumeSide == .left ? "Left" : "Right"
        let bySideCaption: String = {
            if leftVal > 0 && rightVal > 0 {
                return "Total \(FormattingHelpers.formatAmount(leftVal + rightVal, unit: volumeUnit))"
            } else if leftVal > 0 {
                return "Left side · presets fill \(focusedLabel)"
            } else if rightVal > 0 {
                return "Right side · presets fill \(focusedLabel)"
            } else {
                return "Optional · presets fill \(focusedLabel)"
            }
        }()

        return VStack(alignment: .leading, spacing: BLSpacing.space3) {
            HStack {
                Text(title)
                    .blMicroLabel()
                Spacer()
                BLSegmentedControl(
                    options: PumpVolumeMode.allCases,
                    selection: pumpVolumeModeBinding,
                    size: .sm
                ) { $0.rawValue }
            }

            if pumpVolumeMode == .bySide {
                HStack(spacing: BLSpacing.space2) {
                    sideInputCard(
                        label: "Left",
                        text: $pumpLeftAmountText,
                        unit: volumeUnitLabel(volumeUnit),
                        isFocused: focusedPumpVolumeSide == .left,
                        accentColor: theme.event(.pump).solid
                    ) {
                        focusedPumpVolumeSide = .left
                    }

                    sideInputCard(
                        label: "Right",
                        text: $pumpRightAmountText,
                        unit: volumeUnitLabel(volumeUnit),
                        isFocused: focusedPumpVolumeSide == .right,
                        accentColor: theme.event(.pump).solid
                    ) {
                        focusedPumpVolumeSide = .right
                    }
                }

                presetChipsRow(
                    presets: volumeUnit == .oz ? Self.pumpSideOzPresets : Self.pumpSideMlPresets,
                    selected: focusedPumpVolumeSide == .left ? pumpLeftAmountText : pumpRightAmountText
                ) { chosen in
                    if focusedPumpVolumeSide == .left {
                        pumpLeftAmountText = (pumpLeftAmountText == chosen ? "" : chosen)
                    } else {
                        pumpRightAmountText = (pumpRightAmountText == chosen ? "" : chosen)
                    }
                }

                HStack(alignment: .center, spacing: BLSpacing.space2) {
                    Text(bySideCaption)
                        .blTextRole(.caption)
                        .foregroundStyle(theme.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    BLSegmentedControl(
                        options: [VolumeUnit.oz, .ml],
                        selection: pumpUnitBinding,
                        size: .sm
                    ) { volumeUnitLabel($0) }
                }
            } else {
                HStack(alignment: .bottom, spacing: BLSpacing.space4) {
                    BLAmountField(
                        text: $amountText,
                        unit: volumeUnitLabel(volumeUnit),
                        placeholder: "0"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    BLSegmentedControl(
                        options: [VolumeUnit.oz, .ml],
                        selection: pumpUnitBinding,
                        size: .sm
                    ) { volumeUnitLabel($0) }
                }

                presetChipsRow(
                    presets: volumeUnit == .oz ? Self.pumpOzPresets : Self.pumpMlPresets,
                    selected: amountText
                ) { chosen in
                    amountText = (amountText == chosen ? "" : chosen)
                }
            }
        }
    }

    private var pumpDurationSection: some View {
        let leftDur = parsedPumpLeftDuration
        let rightDur = parsedPumpRightDuration
        let focusedLabel = focusedPumpDurationSide == .left ? "Left" : "Right"
        let splitCaption: String = {
            if leftDur > 0 && rightDur > 0 {
                let sessionText = FormattingHelpers.formatNumber(max(leftDur, rightDur), maxFractionDigits: 1)
                return "Session \(sessionText)m · simultaneous"
            }
            return "Presets fill \(focusedLabel)."
        }()

        return VStack(alignment: .leading, spacing: BLSpacing.space3) {
            HStack {
                Text("Pumping time (optional)")
                    .blMicroLabel()
                Spacer()
                Button {
                    toggleSplitPumpTimes()
                } label: {
                    Text(splitPumpTimes ? "Same time" : "Different times")
                        .font(BLFont.ui(size: 13, weight: .semibold))
                        .foregroundStyle(theme.accent)
                        .frame(minHeight: 36)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }

            if !splitPumpTimes {
                BLAmountField(
                    text: $pumpDurationText,
                    unit: "min",
                    size: .md,
                    placeholder: "0"
                )

                presetChipsRow(
                    presets: Self.pumpMinutePresets,
                    selected: pumpDurationText
                ) { chosen in
                    pumpDurationText = (pumpDurationText == chosen ? "" : chosen)
                }
            } else {
                HStack(spacing: BLSpacing.space2) {
                    sideInputCard(
                        label: "Left",
                        text: $pumpLeftDurationText,
                        unit: "min",
                        isFocused: focusedPumpDurationSide == .left,
                        accentColor: theme.event(.pump).solid
                    ) {
                        focusedPumpDurationSide = .left
                    }

                    sideInputCard(
                        label: "Right",
                        text: $pumpRightDurationText,
                        unit: "min",
                        isFocused: focusedPumpDurationSide == .right,
                        accentColor: theme.event(.pump).solid
                    ) {
                        focusedPumpDurationSide = .right
                    }
                }

                presetChipsRow(
                    presets: Self.pumpMinutePresets,
                    selected: focusedPumpDurationSide == .left ? pumpLeftDurationText : pumpRightDurationText
                ) { chosen in
                    if focusedPumpDurationSide == .left {
                        pumpLeftDurationText = (pumpLeftDurationText == chosen ? "" : chosen)
                    } else {
                        pumpRightDurationText = (pumpRightDurationText == chosen ? "" : chosen)
                    }
                }

                Text(splitCaption)
                    .blTextRole(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func sideInputCard(
        label: String,
        text: Binding<String>,
        unit: String,
        isFocused: Bool,
        accentColor: Color,
        showLastBadge: Bool = false,
        onSelect: @escaping () -> Void
    ) -> some View {
        let shape = RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
        let trackedText = Binding<String>(
            get: { text.wrappedValue },
            set: { newValue in
                if newValue != text.wrappedValue {
                    onSelect()
                }
                text.wrappedValue = newValue
            }
        )

        return VStack(alignment: .leading, spacing: BLSpacing.space2) {
            HStack(spacing: BLSpacing.space1) {
                Text(label)
                    .blMicroLabel()
                Spacer(minLength: 4)
                if showLastBadge {
                    BLBadge("Last", tone: .neutral)
                }
            }
            .frame(minHeight: 22)

            BLAmountField(
                text: trackedText,
                unit: unit,
                size: .md,
                placeholder: "0"
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(shape.fill(theme.bgSurface))
        .overlay(
            shape.strokeBorder(
                isFocused ? accentColor : theme.borderHairline,
                lineWidth: isFocused ? 1.5 : BLSpacing.borderWidth
            )
        )
        .contentShape(shape)
        .simultaneousGesture(
            TapGesture().onEnded {
                onSelect()
            }
        )
    }

    private var diaperForm: some View {
        VStack(alignment: .leading, spacing: BLSpacing.space5) {
            labeledField("Pee") {
                BLSegmentedControl(
                    options: DiaperSelection.allCases,
                    selection: $peeSelection,
                    size: .lg,
                    isBlock: true
                ) { $0.rawValue }
            }

            labeledField("Poop") {
                BLSegmentedControl(
                    options: DiaperSelection.allCases,
                    selection: $poopSelection,
                    size: .lg,
                    isBlock: true
                ) { $0.rawValue }
            }

            if poopSelection != .none {
                labeledField("Poop color (optional)") {
                    BLFlowLayout(horizontalSpacing: BLSpacing.space2, verticalSpacing: BLSpacing.space2) {
                        ForEach(PoopColor.allCases, id: \.self) { color in
                            PoopColorChip(
                                color: color,
                                isSelected: poopColor == color
                            ) {
                                poopColor = (poopColor == color ? nil : color)
                            }
                        }
                    }
                }

                labeledField("Consistency (optional)") {
                    BLFlowLayout(horizontalSpacing: BLSpacing.space2, verticalSpacing: BLSpacing.space2) {
                        ForEach(PoopConsistency.allCases, id: \.self) { item in
                            BLChip(
                                FormattingHelpers.formatPoopConsistency(item),
                                isSelected: poopConsistency == item
                            ) {
                                poopConsistency = (poopConsistency == item ? nil : item)
                            }
                        }
                    }
                }
            }

            BLCheckbox(isChecked: $diaperRash, label: "Rash")
        }
        .onChange(of: poopSelection) { _, newValue in
            if newValue == .none {
                poopColor = nil
                poopConsistency = nil
            }
        }
    }

    private var mealForm: some View {
        let manualMealSlotBinding = Binding<MealSlot>(
            get: { mealSlot },
            set: { newSlot in
                userSelectedMealSlot = true
                mealSlot = newSlot
            }
        )

        return VStack(alignment: .leading, spacing: BLSpacing.space5) {
            BLSegmentedControl(
                options: [MealSlot.breakfast, .lunch, .dinner, .snack],
                selection: manualMealSlotBinding,
                size: .md,
                isBlock: true
            ) { mealSlotLabel($0) }

            BLTextField(label: "What she ate", placeholder: "Optional", text: $mealAte)

            labeledField("How much") {
                BLSegmentedControl(
                    options: [PortionEaten.none, .some, .most],
                    selection: $mealPortion,
                    size: .lg,
                    isBlock: true
                ) { portionLabel($0) }
            }
        }
    }

    private var bathForm: some View {
        let hairBinding = Binding<String>(
            get: { washedHair ? "Yes" : "No" },
            set: { washedHair = ($0 == "Yes") }
        )

        return VStack(alignment: .leading, spacing: BLSpacing.space5) {
            labeledField("Shampooed hair?") {
                BLSegmentedControl(
                    options: ["No", "Yes"],
                    selection: hairBinding,
                    size: .lg,
                    isBlock: true
                )
            }

            BLTextField(label: "Notes", placeholder: "Optional", text: $bathNotes)
        }
    }

    private var medicineForm: some View {
        VStack(alignment: .leading, spacing: BLSpacing.space4) {
            BLFlowLayout(horizontalSpacing: BLSpacing.space2, verticalSpacing: BLSpacing.space2) {
                ForEach(MedPreset.allCases) { preset in
                    BLChip(preset.rawValue, isSelected: medPreset == preset) {
                        medPreset = preset
                        if let defaultDose = preset.defaultDose {
                            medDoseText = defaultDose
                        } else {
                            medDoseText = ""
                        }
                        medDoseUnit = preset.defaultUnit
                        if preset != .custom {
                            customMedCategory = preset.defaultCategory
                        }
                    }
                }
            }

            if medPreset == .custom {
                BLTextField(
                    label: "Name",
                    placeholder: "Medicine or care name",
                    text: $customMedName
                )

                labeledField("Category") {
                    BLSegmentedControl(
                        options: [MedicineCategory.medicine, .supplement, .topical],
                        selection: $customMedCategory,
                        size: .md,
                        isBlock: true
                    ) { category in
                        switch category {
                        case .medicine: "Medicine"
                        case .supplement: "Supplement"
                        case .topical: "Topical"
                        }
                    }
                }
            }

            if isTopicalMedicine {
                Text("Topical care. No dose needed.")
                    .blTextRole(.callout)
                    .foregroundStyle(theme.textSecondary)
            } else {
                HStack(alignment: .bottom, spacing: BLSpacing.space4) {
                    BLAmountField(
                        text: $medDoseText,
                        unit: doseUnitLabel(medDoseUnit),
                        size: .md
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    BLSegmentedControl(
                        options: [DoseUnit.ml, .drops, .mg],
                        selection: $medDoseUnit,
                        size: .sm
                    ) { doseUnitLabel($0) }
                }
            }
        }
    }

    private var noteForm: some View {
        BLTextField(
            placeholder: "Anything worth remembering about today",
            text: $noteText,
            isMultiline: true,
            minLines: 4
        )
    }

    // MARK: - Shared Form Helpers

    private var volumeAmountRow: some View {
        let unitBinding = Binding<VolumeUnit>(
            get: { volumeUnit },
            set: { newUnit in
                guard newUnit != volumeUnit else { return }
                if let parsed = Double(amountText), parsed > 0 {
                    if newUnit == .ml {
                        let ml = UnitConversion.ozToMl(parsed)
                        let roundedStep = (ml / 5.0).rounded() * 5.0
                        amountText = FormattingHelpers.formatNumber(roundedStep, maxFractionDigits: 0)
                    } else {
                        let oz = UnitConversion.mlToOz(parsed)
                        let quarterStep = (oz * 4.0).rounded() / 4.0
                        amountText = FormattingHelpers.formatNumber(quarterStep, maxFractionDigits: 2)
                    }
                }
                volumeUnit = newUnit
            }
        )

        return HStack(alignment: .bottom, spacing: BLSpacing.space4) {
            BLAmountField(text: $amountText, unit: volumeUnitLabel(volumeUnit))
                .frame(maxWidth: .infinity, alignment: .leading)

            BLSegmentedControl(
                options: [VolumeUnit.oz, .ml],
                selection: unitBinding,
                size: .sm
            ) { volumeUnitLabel($0) }
        }
    }

    private func presetChipsRow(
        presets: [String],
        selected: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        HStack(spacing: BLSpacing.space2) {
            ForEach(presets, id: \.self) { preset in
                BLChip(preset, isSelected: selected == preset, isBlock: true) {
                    onSelect(preset)
                }
            }
        }
    }

    private func timeFieldSection(label: String) -> some View {
        let timeBinding = Binding<Date>(
            get: { exactTime },
            set: { newDate in
                exactTime = newDate
                usesCustomTime = true
            }
        )

        return labeledField(label) {
            if isEditing {
                BLTimeField(date: timeBinding)
            } else {
                HStack(spacing: BLSpacing.space2) {
                    BLTimeField(date: timeBinding)
                        .layoutPriority(1)

                    ForEach(Self.relativeAgoOptions, id: \.minutes) { option in
                        BLChip(
                            option.label,
                            isSelected: !usesCustomTime && agoMinutes == option.minutes,
                            isBlock: true
                        ) {
                            agoMinutes = option.minutes
                            usesCustomTime = false
                            exactTime = store.now.addingTimeInterval(-TimeInterval(option.minutes * 60))
                        }
                    }
                }
            }
        }
    }

    private func labeledField<Content: View>(
        _ title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: BLSpacing.space2) {
            Text(title)
                .blMicroLabel()
            content()
        }
    }

    // MARK: - Commit Logic

    private func commit() {
        if let editing = request.editingEvent {
            commitEdit(editing)
            onClose()
            return
        }

        let timestamp = resolvedCommitTimestamp()

        switch request.kind {
        case .sleep:
            if isActiveNapStartMode {
                let currentType: SleepType = store.isActiveSleepNight ? .night : .nap
                let startChanged = abs((store.activeNapStart ?? sleepStart).timeIntervalSince(sleepStart)) >= 1.0
                if startChanged {
                    store.updateActiveNapStart(sleepStart)
                }
                if sleepType != currentType {
                    store.switchActiveSleepType(sleepType)
                }
            } else {
                let interval = resolvedSleepInterval
                guard interval.durationMinutes > 0 else { return }
                store.logPastSleep(
                    isNap: sleepType == .nap,
                    start: interval.start,
                    end: interval.end
                )
            }

        case .feeding:
            let amount = max(0, Double(amountText) ?? 0)
            guard amount > 0 else { return }
            store.logBottle(
                startedAt: timestamp,
                amount: amount,
                unit: volumeUnit,
                substance: substance,
                includeVitaminD: includeVitaminD
            )

        case .nursing:
            if isNursingTimerMode {
                guard store.activeNursing != nil else { return }
                store.finishNursing()
            } else {
                let leftMins = parsedNursingLeftMinutes
                let rightMins = parsedNursingRightMinutes
                guard leftMins + rightMins > 0 else { return }
                store.logManualNursing(
                    startedAt: timestamp,
                    leftMinutes: leftMins,
                    rightMinutes: rightMins,
                    lastSide: (leftMins > 0 && rightMins > 0) ? nursingLastSide : nil
                )
            }

        case .pump:
            if isPumpTimerMode {
                guard let session = store.activePump else { return }
                let leftUsed = session.leftAccumulatedSeconds > 0 || session.isLeftRunning
                let rightUsed = session.rightAccumulatedSeconds > 0 || session.isRightRunning
                let leftVal = parsedPumpLeftAmount
                let rightVal = parsedPumpRightAmount
                let combinedVal = max(0, Double(amountText) ?? 0)

                if leftUsed && !rightUsed {
                    store.finishPumpTimer(
                        leftAmount: leftVal > 0 ? leftVal : nil,
                        unit: volumeUnit
                    )
                } else if rightUsed && !leftUsed {
                    store.finishPumpTimer(
                        rightAmount: rightVal > 0 ? rightVal : nil,
                        unit: volumeUnit
                    )
                } else if pumpVolumeMode == .bySide {
                    store.finishPumpTimer(
                        leftAmount: leftVal > 0 ? leftVal : nil,
                        rightAmount: rightVal > 0 ? rightVal : nil,
                        unit: volumeUnit
                    )
                } else {
                    store.finishPumpTimer(
                        amount: combinedVal > 0 ? combinedVal : nil,
                        unit: volumeUnit
                    )
                }
            } else {
                let resolved = resolvedManualPumpInput
                guard resolved.totalDisplayAmount > 0 || (resolved.sessionDurationMinutes ?? 0) > 0 else {
                    return
                }
                store.logPump(
                    startedAt: timestamp,
                    amount: resolved.combinedAmount ?? 0,
                    unit: volumeUnit,
                    side: resolved.side,
                    durationMinutes: resolved.sessionDurationMinutes,
                    leftAmount: resolved.leftAmount,
                    rightAmount: resolved.rightAmount,
                    leftDurationMinutes: resolved.leftDurationMinutes,
                    rightDurationMinutes: resolved.rightDurationMinutes
                )
            }

        case .diaper:
            store.logDiaper(
                startedAt: timestamp,
                pee: peeSelection.diaperSize,
                poop: poopSelection.diaperSize,
                rash: diaperRash,
                poopColor: poopSelection == .none ? nil : poopColor,
                poopConsistency: poopSelection == .none ? nil : poopConsistency
            )

        case .meal:
            store.logMeal(
                startedAt: timestamp,
                slot: mealSlot,
                ate: mealAte,
                portion: mealPortion
            )

        case .bath:
            store.logBath(
                startedAt: timestamp,
                washedHair: washedHair,
                notes: bathNotes
            )

        case .medicine:
            let resolvedName: String = {
                if medPreset == .custom {
                    let trimmed = customMedName.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? "Meds & care" : trimmed
                }
                return medPreset.rawValue
            }()
            let doseValue = isTopicalMedicine ? nil : Double(medDoseText)
            store.logMedicine(
                startedAt: timestamp,
                name: resolvedName,
                category: effectiveMedicineCategory,
                dose: doseValue,
                unit: doseValue == nil ? nil : medDoseUnit
            )

        case .note:
            store.logNote(startedAt: timestamp, text: noteText)
        }

        onClose()
    }

    private func commitEdit(_ original: EventDTO) {
        var updated = original
        let timestamp = resolvedCommitTimestamp()

        switch request.kind {
        case .sleep:
            let interval = resolvedSleepInterval
            guard interval.durationMinutes > 0 else { return }
            var location: SleepLocation?
            if case .sleep(let oldMeta) = original.metadata {
                location = oldMeta.location
            }
            updated.startedAt = interval.start
            updated.endedAt = interval.end
            updated.metadata = .sleep(SleepMetadata(sleepType: sleepType, location: location))

        case .feeding:
            let amount = max(0, Double(amountText) ?? 0)
            let amountMl = volumeUnit == .oz ? UnitConversion.ozToMl(amount) : amount
            updated.startedAt = timestamp
            updated.metadata = .feeding(
                FeedingMetadata(
                    method: .bottle,
                    substance: substance,
                    amountMl: amountMl,
                    displayUnit: volumeUnit
                )
            )

        case .nursing:
            let leftMins = parsedNursingLeftMinutes
            let rightMins = parsedNursingRightMinutes
            let total = leftMins + rightMins
            guard total > 0 else { return }
            let side: BreastSide = (leftMins > 0 && rightMins > 0)
                ? .both
                : (leftMins > 0 ? .left : .right)
            let leftDurationSeconds = leftMins > 0 ? Int((leftMins * 60.0).rounded()) : nil
            let rightDurationSeconds = rightMins > 0 ? Int((rightMins * 60.0).rounded()) : nil
            let resolvedLastSide: BreastSide = (side == .both) ? nursingLastSide : side
            updated.startedAt = timestamp
            updated.endedAt = timestamp.addingTimeInterval(total * 60.0)
            updated.metadata = .feeding(
                FeedingMetadata(
                    method: .breast,
                    substance: .breastMilk,
                    amountMl: nil,
                    displayUnit: store.preferredUnit,
                    side: side,
                    durationMinutes: total,
                    leftDurationSeconds: leftDurationSeconds,
                    rightDurationSeconds: rightDurationSeconds,
                    lastSide: resolvedLastSide
                )
            )

        case .pump:
            let resolved = resolvedManualPumpInput
            guard resolved.totalDisplayAmount > 0 || (resolved.sessionDurationMinutes ?? 0) > 0 else {
                return
            }
            let toMl: (Double) -> Double = { value in
                volumeUnit == .oz ? UnitConversion.ozToMl(value) : value
            }
            let leftMl = resolved.leftAmount.map(toMl)
            let rightMl = resolved.rightAmount.map(toMl)
            let totalMl: Double? = {
                if leftMl != nil || rightMl != nil {
                    return (leftMl ?? 0) + (rightMl ?? 0)
                }
                if let combined = resolved.combinedAmount {
                    return toMl(combined)
                }
                return nil
            }()
            let leftSec = resolved.leftDurationMinutes.map { max(1, Int(($0 * 60.0).rounded())) }
            let rightSec = resolved.rightDurationMinutes.map { max(1, Int(($0 * 60.0).rounded())) }
            updated.startedAt = timestamp
            updated.endedAt = resolved.sessionDurationMinutes.map { timestamp.addingTimeInterval($0 * 60.0) }
            updated.metadata = .pump(
                PumpMetadata(
                    amountMl: totalMl,
                    displayUnit: volumeUnit,
                    side: resolved.side,
                    durationMinutes: resolved.sessionDurationMinutes,
                    leftAmountMl: leftMl,
                    rightAmountMl: rightMl,
                    leftDurationSeconds: leftSec,
                    rightDurationSeconds: rightSec
                )
            )

        case .diaper:
            updated.startedAt = timestamp
            updated.metadata = .diaper(
                DiaperMetadata(
                    peeSize: peeSelection.diaperSize,
                    poopSize: poopSelection.diaperSize,
                    rash: diaperRash,
                    poopColor: poopSelection == .none ? nil : poopColor,
                    poopConsistency: poopSelection == .none ? nil : poopConsistency
                )
            )

        case .meal:
            updated.startedAt = timestamp
            let trimmed = mealAte.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.notes = trimmed.isEmpty ? nil : trimmed
            updated.metadata = .meal(MealMetadata(mealSlot: mealSlot, portionEaten: mealPortion))

        case .bath:
            updated.startedAt = timestamp
            let trimmed = bathNotes.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.notes = trimmed.isEmpty ? nil : trimmed
            updated.metadata = .bath(BathMetadata(washedHair: washedHair))

        case .medicine:
            let resolvedName: String = {
                if medPreset == .custom {
                    let trimmed = customMedName.trimmingCharacters(in: .whitespacesAndNewlines)
                    return trimmed.isEmpty ? "Meds & care" : trimmed
                }
                return medPreset.rawValue
            }()
            let doseValue = isTopicalMedicine ? nil : Double(medDoseText)
            updated.startedAt = timestamp
            updated.metadata = .medicine(
                MedicineMetadata(
                    name: resolvedName,
                    category: effectiveMedicineCategory,
                    dose: doseValue,
                    unit: doseValue == nil ? nil : medDoseUnit
                )
            )

        case .note:
            let trimmed = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
            updated.startedAt = timestamp
            updated.notes = trimmed.isEmpty ? nil : trimmed
            updated.metadata = .note(NoteMetadata())
        }

        store.updateEvent(updated)
    }

    // MARK: - Label Helpers

    private func volumeUnitLabel(_ unit: VolumeUnit) -> String {
        unit == .oz ? "oz" : "mL"
    }

    private func doseUnitLabel(_ unit: DoseUnit) -> String {
        switch unit {
        case .ml: "mL"
        case .drops: "drops"
        case .mg: "mg"
        }
    }

    private func sideShortLabel(_ side: BreastSide) -> String {
        switch side {
        case .left: "Left"
        case .right: "Right"
        case .both: "Both"
        }
    }

    private func mealSlotLabel(_ slot: MealSlot) -> String {
        switch slot {
        case .breakfast: "Breakfast"
        case .lunch: "Lunch"
        case .dinner: "Dinner"
        case .snack: "Snack"
        }
    }

    private func portionLabel(_ portion: PortionEaten) -> String {
        switch portion {
        case .none: "None"
        case .some: "Some"
        case .most: "Most"
        }
    }
}

// MARK: - Clock-Isolated Live Nursing Subviews

@MainActor
private struct LiveNursingTimerSection: View {
    @Environment(\.blTheme) private var theme
    let store: BlythesLifeStore

    var body: some View {
        if let session = store.activeNursing {
            let elapsed = session.elapsedSeconds(asOf: store.now)
            HStack {
                Text("Started \(FormattingHelpers.formatClock(session.startedAt, timeZone: store.profileTimeZone))")
                    .blMicroLabel()
                Spacer()
                BLBadge(session.isRunning ? "Running" : "Paused", tone: .event(.nursing))
            }
            .frame(minHeight: 36)

            BLNursingTimer(
                leftSeconds: Int(elapsed.left),
                rightSeconds: Int(elapsed.right),
                activeSide: session.activeSide?.rawValue
            ) { sideId in
                store.tapNursingSide(sideId == "right" ? .right : .left)
            }

            Text("Runs on every device. You can close this.")
                .blTextRole(.callout)
                .foregroundStyle(theme.textSecondary)
        }
    }
}

@MainActor
private struct LiveNursingCommitButton: View {
    let store: BlythesLifeStore
    let canCommit: Bool
    let action: () -> Void

    var body: some View {
        let title: String = {
            guard let session = store.activeNursing else {
                return "Tap a side to start"
            }
            let elapsed = session.elapsedSeconds(asOf: store.now)
            let mins = max(1, Int((elapsed.total / 60.0).rounded()))
            return "Log \(mins) min nursing"
        }()

        BLButton(
            title,
            variant: .primary,
            size: .lg,
            isBlock: true,
            action: action
        )
        .disabled(!canCommit)
    }
}

// MARK: - Clock-Isolated Live Pump Subviews

@MainActor
private struct LivePumpTimerSection: View {
    @Environment(\.blTheme) private var theme
    let store: BlythesLifeStore

    var body: some View {
        VStack(alignment: .leading, spacing: BLSpacing.space4) {
            if let session = store.activePump {
                let elapsed = session.elapsedSeconds(asOf: store.now)

                HStack {
                    Text("Started \(FormattingHelpers.formatClock(session.startedAt, timeZone: store.profileTimeZone))")
                        .blMicroLabel()
                    Spacer()
                    BLBadge(session.isRunning ? "Running" : "Paused", tone: .event(.pump))
                }
                .frame(minHeight: 36)

                BLPumpTimer(
                    sessionSeconds: Int(elapsed.session),
                    leftSeconds: Int(elapsed.left),
                    rightSeconds: Int(elapsed.right),
                    isLeftRunning: session.isLeftRunning,
                    isRightRunning: session.isRightRunning,
                    onTapSide: { sideId in
                        store.tapPumpSide(sideId == "right" ? .right : .left)
                    },
                    onToggleBoth: {
                        store.togglePumpBoth()
                    }
                )

                Text("Runs while you close this.")
                    .blTextRole(.callout)
                    .foregroundStyle(theme.textSecondary)
            } else {
                BLPumpTimer(
                    sessionSeconds: 0,
                    leftSeconds: 0,
                    rightSeconds: 0,
                    isLeftRunning: false,
                    isRightRunning: false,
                    onTapSide: { sideId in
                        store.tapPumpSide(sideId == "right" ? .right : .left)
                    },
                    onToggleBoth: {
                        store.togglePumpBoth()
                    }
                )

                Text("Tap Start both or pick a side.")
                    .blTextRole(.callout)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }
}

@MainActor
private struct LivePumpCommitButton: View {
    let store: BlythesLifeStore
    let isBySideVolumeMode: Bool
    let combinedAmountText: String
    let leftAmountText: String
    let rightAmountText: String
    let volumeUnit: VolumeUnit
    let canCommit: Bool
    let action: () -> Void

    var body: some View {
        let title: String = {
            guard let session = store.activePump else {
                return "Start a side above"
            }
            let elapsed = session.elapsedSeconds(asOf: store.now)
            let mins = max(1, Int((elapsed.session / 60.0).rounded()))
            let leftUsed = session.leftAccumulatedSeconds > 0 || session.isLeftRunning
            let rightUsed = session.rightAccumulatedSeconds > 0 || session.isRightRunning
            let leftVal = max(0, Double(leftAmountText) ?? 0)
            let rightVal = max(0, Double(rightAmountText) ?? 0)
            let combinedVal = max(0, Double(combinedAmountText) ?? 0)

            let totalAmt: Double
            if leftUsed && !rightUsed {
                totalAmt = leftVal
            } else if rightUsed && !leftUsed {
                totalAmt = rightVal
            } else if isBySideVolumeMode {
                totalAmt = leftVal + rightVal
            } else {
                totalAmt = combinedVal
            }

            if totalAmt > 0 {
                let amountLabel = FormattingHelpers.formatAmount(totalAmt, unit: volumeUnit)
                return "Log \(amountLabel) · \(mins)m pumped"
            }
            return "Log \(mins)m pumped"
        }()

        BLButton(
            title,
            variant: .primary,
            size: .lg,
            isBlock: true,
            action: action
        )
        .disabled(!canCommit)
    }
}

// MARK: - Diaper Poop Color Swatch Chip

@MainActor
private struct PoopColorChip: View {
    @Environment(\.blTheme) private var theme

    let color: PoopColor
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Self.swatchColor(for: color))
                    .overlay(
                        Circle()
                            .strokeBorder(theme.borderStrong, lineWidth: BLSpacing.borderWidth)
                    )
                    .frame(width: 12, height: 12)

                Text(FormattingHelpers.formatPoopColor(color))
                    .font(BLFont.ui(size: 14, weight: isSelected ? .semibold : .medium))
                    .lineLimit(1)
            }
        }
        .buttonStyle(PoopColorChipStyle(isSelected: isSelected))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private static func swatchColor(for color: PoopColor) -> Color {
        switch color {
        case .yellow: BLColorPrimitives.oklch(0.76, 0.14, 90)
        case .brown: BLColorPrimitives.oklch(0.48, 0.08, 55)
        case .green: BLColorPrimitives.oklch(0.56, 0.10, 138)
        case .orange: BLColorPrimitives.oklch(0.68, 0.14, 52)
        case .black: BLColorPrimitives.oklch(0.24, 0.01, 70)
        case .red: BLColorPrimitives.oklch(0.55, 0.16, 25)
        case .pale: BLColorPrimitives.oklch(0.90, 0.015, 85)
        }
    }
}

private struct PoopColorChipStyle: ButtonStyle {
    let isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        StyledBody(configuration: configuration, isSelected: isSelected)
    }

    private struct StyledBody: View {
        @Environment(\.blTheme) private var theme
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        let configuration: Configuration
        let isSelected: Bool

        private var backgroundColor: Color {
            if isSelected { return theme.diaper.tint }
            return configuration.isPressed ? theme.bgSunken : theme.bgSurface
        }

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: BLRadius.sm, style: .continuous)
            configuration.label
                .padding(.horizontal, 10)
                .frame(minHeight: 38)
                .foregroundStyle(isSelected ? theme.diaper.ink : theme.textPrimary)
                .background(shape.fill(backgroundColor))
                .overlay(
                    shape.strokeBorder(
                        isSelected ? theme.diaper.solid : theme.borderStrong,
                        lineWidth: isSelected ? 2 : BLSpacing.borderWidth
                    )
                )
                .contentShape(shape)
                .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
                .animation(
                    BLMotion.easeOut(duration: BLMotion.fast, reducedMotion: reduceMotion),
                    value: configuration.isPressed
                )
        }
    }
}
