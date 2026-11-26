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
    private static let pumpOzPresets = ["2", "3", "4", "5", "6", "8"]
    private static let pumpMlPresets = ["60", "90", "120", "150", "180", "240"]
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
    @State private var sleepStart: Date
    @State private var sleepEnd: Date

    // Bottle & Pump state
    @State private var amountText: String
    @State private var volumeUnit: VolumeUnit
    @State private var substance: FeedingSubstance = .formula
    @State private var includeVitaminD: Bool = false
    @State private var pumpSide: BreastSide = .both

    // Nursing state
    @State private var nursingMode: NursingInputMode = .timer
    @State private var nursingMinutesText: String = "10"
    @State private var nursingSide: BreastSide = .left

    // Diaper state
    @State private var peeSelection: DiaperSelection = .medium
    @State private var poopSelection: DiaperSelection = .none
    @State private var diaperRash: Bool = false

    // Meal state
    @State private var mealSlot: MealSlot
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
        let defaultMealSlot = Self.defaultMealSlot(for: now, calendar: store.profileCalendar)

        // Default values for create mode
        var initAgo = 0
        var initUsesCustom = false
        var initExact = now
        var initSleepType: SleepType = .nap
        var initSleepStart = store.activeNapStart ?? now.addingTimeInterval(-3600)
        var initSleepEnd = now
        var initAmount = request.kind == .pump ? (isMl ? "120" : "4") : (isMl ? "95" : "3.25")
        var initUnit = preferredUnit
        var initSubstance: FeedingSubstance = .formula
        var initPumpSide: BreastSide = .both
        var initNurseMode: NursingInputMode = .timer
        var initNurseMinutes = "10"
        var initNurseSide: BreastSide = .left
        var initPee: DiaperSelection = .medium
        var initPoop: DiaperSelection = .none
        var initRash = false
        var initSlot = defaultMealSlot
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
                    let mins = meta.durationMinutes
                        ?? editing.endedAt.map { max(1, $0.timeIntervalSince(editing.startedAt) / 60.0) }
                        ?? max(1, Double((meta.leftDurationSeconds ?? 0) + (meta.rightDurationSeconds ?? 0)) / 60.0)
                    initNurseMinutes = FormattingHelpers.formatNumber(mins, maxFractionDigits: 1)
                    initNurseSide = meta.side ?? .left
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
                if let ml = meta.amountMl {
                    let displayed = initUnit == .oz ? UnitConversion.mlToOz(ml) : ml
                    initAmount = FormattingHelpers.formatNumber(
                        displayed,
                        maxFractionDigits: initUnit == .oz ? 2 : 1
                    )
                }
                initPumpSide = meta.side

            case .diaper(let meta):
                initPee = DiaperSelection.from(meta.peeSize)
                initPoop = DiaperSelection.from(meta.poopSize)
                initRash = meta.rash

            case .meal(let meta):
                initSlot = meta.mealSlot ?? defaultMealSlot
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
        _sleepStart = State(initialValue: initSleepStart)
        _sleepEnd = State(initialValue: initSleepEnd)
        _amountText = State(initialValue: initAmount)
        _volumeUnit = State(initialValue: initUnit)
        _substance = State(initialValue: initSubstance)
        _pumpSide = State(initialValue: initPumpSide)
        _nursingMode = State(initialValue: initNurseMode)
        _nursingMinutesText = State(initialValue: initNurseMinutes)
        _nursingSide = State(initialValue: initNurseSide)
        _peeSelection = State(initialValue: initPee)
        _poopSelection = State(initialValue: initPoop)
        _diaperRash = State(initialValue: initRash)
        _mealSlot = State(initialValue: initSlot)
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

    private var effectiveTimestamp: Date {
        if usesCustomTime {
            return exactTime
        }
        return store.now.addingTimeInterval(-TimeInterval(agoMinutes * 60))
    }

    private var timeRowLabel: String? {
        if request.kind == .sleep || isNursingTimerMode {
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

    private var canCommit: Bool {
        switch request.kind {
        case .sleep:
            if isActiveNapStartMode { return true }
            return resolvedSleepInterval.durationMinutes > 0
        case .nursing:
            if isNursingTimerMode {
                return store.activeNursing != nil
            }
            return (Double(nursingMinutesText) ?? 0) > 0
        case .feeding, .pump:
            return (Double(amountText) ?? 0) > 0
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
                let clock = FormattingHelpers.formatClock(sleepStart, timeZone: store.profileTimeZone)
                return "Set start to \(clock)"
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
            if isNursingTimerMode {
                guard let session = store.activeNursing else {
                    return "Tap a side to start"
                }
                let elapsed = session.elapsedSeconds(asOf: store.now)
                let mins = max(1, Int((elapsed.total / 60.0).rounded()))
                return "Log \(mins) min nursing"
            }
            let mins = nursingMinutesText.isEmpty ? "0" : nursingMinutesText
            return "Log \(mins) min nursing"

        case .pump:
            let shown = amountText.isEmpty ? "0" : amountText
            return "Log \(shown) \(volumeUnitLabel(volumeUnit)) pumped"

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
                    }

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
        )
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
            BLTimeField(label: "Fell asleep", date: $sleepStart)
            Text("The timer keeps running on every device.")
                .blTextRole(.callout)
                .foregroundStyle(theme.textSecondary)
        } else {
            let interval = resolvedSleepInterval
            BLSegmentedControl(
                options: [SleepType.nap, .night],
                selection: $sleepType,
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
                } else {
                    BLSegmentedControl(
                        options: NursingInputMode.allCases,
                        selection: $nursingMode,
                        isBlock: true
                    ) { $0.rawValue }

                    BLNursingTimer(
                        leftSeconds: 0,
                        rightSeconds: 0,
                        activeSide: nil
                    ) { sideId in
                        store.tapNursingSide(sideId == "right" ? .right : .left)
                    }

                    Text("Tap a side to start the timer.")
                        .blTextRole(.callout)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        } else {
            VStack(alignment: .leading, spacing: BLSpacing.space5) {
                if !isEditing {
                    BLSegmentedControl(
                        options: NursingInputMode.allCases,
                        selection: $nursingMode,
                        isBlock: true
                    ) { $0.rawValue }
                }

                BLAmountField(text: $nursingMinutesText, unit: "min")

                presetChipsRow(presets: Self.nurseMinutePresets, selected: nursingMinutesText) { chosen in
                    nursingMinutesText = chosen
                }

                labeledField("Side") {
                    BLSegmentedControl(
                        options: [BreastSide.left, .right, .both],
                        selection: $nursingSide,
                        size: .lg,
                        isBlock: true
                    ) { sideShortLabel($0) }
                }
            }
        }
    }

    private var pumpForm: some View {
        VStack(alignment: .leading, spacing: BLSpacing.space5) {
            volumeAmountRow

            presetChipsRow(
                presets: volumeUnit == .oz ? Self.pumpOzPresets : Self.pumpMlPresets,
                selected: amountText
            ) { chosen in
                amountText = chosen
            }

            labeledField("Side") {
                BLSegmentedControl(
                    options: [BreastSide.left, .right, .both],
                    selection: $pumpSide,
                    size: .lg,
                    isBlock: true
                ) { sideShortLabel($0) }
            }
        }
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

            BLCheckbox(isChecked: $diaperRash, label: "Rash")
        }
    }

    private var mealForm: some View {
        VStack(alignment: .leading, spacing: BLSpacing.space5) {
            BLSegmentedControl(
                options: [MealSlot.breakfast, .lunch, .dinner, .snack],
                selection: $mealSlot,
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
            get: { effectiveTimestamp },
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

        let timestamp = effectiveTimestamp

        switch request.kind {
        case .sleep:
            if isActiveNapStartMode {
                store.updateActiveNapStart(sleepStart)
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
                let mins = max(0, Double(nursingMinutesText) ?? 0)
                guard mins > 0 else { return }
                store.logManualNursing(
                    startedAt: timestamp,
                    minutes: mins,
                    side: nursingSide
                )
            }

        case .pump:
            let amount = max(0, Double(amountText) ?? 0)
            guard amount > 0 else { return }
            store.logPump(
                startedAt: timestamp,
                amount: amount,
                unit: volumeUnit,
                side: pumpSide
            )

        case .diaper:
            store.logDiaper(
                startedAt: timestamp,
                pee: peeSelection.diaperSize,
                poop: poopSelection.diaperSize,
                rash: diaperRash
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
        let timestamp = effectiveTimestamp

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
            let mins = max(0, Double(nursingMinutesText) ?? 0)
            updated.startedAt = timestamp
            updated.endedAt = timestamp.addingTimeInterval(mins * 60.0)
            updated.metadata = .feeding(
                FeedingMetadata(
                    method: .breast,
                    substance: .breastMilk,
                    amountMl: nil,
                    displayUnit: store.preferredUnit,
                    side: nursingSide,
                    durationMinutes: mins
                )
            )

        case .pump:
            let amount = max(0, Double(amountText) ?? 0)
            let amountMl = volumeUnit == .oz ? UnitConversion.ozToMl(amount) : amount
            updated.startedAt = timestamp
            updated.metadata = .pump(
                PumpMetadata(
                    amountMl: amountMl,
                    displayUnit: volumeUnit,
                    side: pumpSide
                )
            )

        case .diaper:
            updated.startedAt = timestamp
            updated.metadata = .diaper(
                DiaperMetadata(
                    peeSize: peeSelection.diaperSize,
                    poopSize: poopSelection.diaperSize,
                    rash: diaperRash
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

    private static func defaultMealSlot(for date: Date, calendar: Calendar) -> MealSlot {
        let comps = calendar.dateComponents([.hour, .minute], from: date)
        let mins = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        if mins < 630 { return .breakfast }
        if mins < 900 { return .lunch }
        if mins < 1020 { return .snack }
        return .dinner
    }

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
