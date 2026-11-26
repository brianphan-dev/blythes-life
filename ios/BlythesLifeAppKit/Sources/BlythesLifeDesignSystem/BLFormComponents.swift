import SwiftUI

// MARK: - BLSegmentedControl

/// Hairline-bordered segmented control with a raised paper thumb.
public struct BLSegmentedControl<Option: Hashable>: View {
    public enum Size: Sendable, Hashable {
        case sm
        case md
        case lg

        var optionHeight: CGFloat {
            switch self {
            case .sm: 30
            case .md: 38
            case .lg: 52
            }
        }

        var fontSize: CGFloat {
            switch self {
            case .sm: 13
            case .md: 15
            case .lg: 17
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .sm: 10
            case .md: 14
            case .lg: 14
            }
        }

        var outerRadius: CGFloat {
            self == .sm ? 10 : BLRadius.md
        }

        var thumbRadius: CGFloat {
            self == .sm ? 7 : 9
        }
    }

    @Environment(\.blTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let options: [Option]
    @Binding private var selection: Option
    private let size: Size
    private let isBlock: Bool
    private let label: (Option) -> String

    public init(
        options: [Option],
        selection: Binding<Option>,
        size: Size = .md,
        isBlock: Bool = false,
        label: @escaping (Option) -> String
    ) {
        self.options = options
        self._selection = selection
        self.size = size
        self.isBlock = isBlock
        self.label = label
    }

    public var body: some View {
        HStack(spacing: 2) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(
                        BLMotion.easeOut(duration: BLMotion.fast, reducedMotion: reduceMotion)
                    ) {
                        selection = option
                    }
                } label: {
                    Text(label(option))
                        .font(
                            BLFont.ui(
                                size: size.fontSize,
                                weight: isSelected ? .semibold : .medium
                            )
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                        .foregroundStyle(isSelected ? theme.textPrimary : theme.textSecondary)
                        .padding(.horizontal, isBlock ? BLSpacing.space1 : size.horizontalPadding)
                        .frame(height: size.optionHeight)
                        .frame(maxWidth: isBlock ? .infinity : nil)
                        .background(
                            RoundedRectangle(cornerRadius: size.thumbRadius, style: .continuous)
                                .fill(isSelected ? theme.bgRaised : .clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: size.thumbRadius, style: .continuous)
                                .strokeBorder(
                                    isSelected ? theme.borderStrong : .clear,
                                    lineWidth: BLSpacing.borderWidth
                                )
                        )
                        .contentShape(
                            RoundedRectangle(cornerRadius: size.thumbRadius, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .frame(maxWidth: isBlock ? .infinity : nil)
        .background(
            RoundedRectangle(cornerRadius: size.outerRadius, style: .continuous)
                .fill(theme.bgSunken)
        )
        .overlay(
            RoundedRectangle(cornerRadius: size.outerRadius, style: .continuous)
                .strokeBorder(theme.borderHairline, lineWidth: BLSpacing.borderWidth)
        )
    }
}

extension BLSegmentedControl where Option == String {
    public init(
        options: [String],
        selection: Binding<String>,
        size: Size = .md,
        isBlock: Bool = false
    ) {
        self.init(
            options: options,
            selection: selection,
            size: size,
            isBlock: isBlock,
            label: { $0 }
        )
    }
}

// MARK: - BLSwitch

/// Squared `52×32` switch (`10pt` outer radius, `24×24` thumb with `7pt` radius, honey when ON).
public struct BLSwitch: View {
    @Environment(\.blTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var isOn: Bool
    private let accessibilityLabelText: String

    public init(isOn: Binding<Bool>, label: String = "Toggle") {
        self._isOn = isOn
        self.accessibilityLabelText = label
    }

    public var body: some View {
        Button {
            withAnimation(
                BLMotion.easeOut(duration: BLMotion.base, reducedMotion: reduceMotion)
            ) {
                isOn.toggle()
            }
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isOn ? theme.accent : theme.bgSunken)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(
                                isOn ? theme.accentBorder : theme.borderStrong,
                                lineWidth: BLSpacing.borderWidth
                            )
                    )

                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isOn ? BLColorPrimitives.paper0 : theme.bgRaised)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(
                                isOn ? .clear : theme.borderStrong,
                                lineWidth: BLSpacing.borderWidth
                            )
                    )
                    .frame(width: 24, height: 24)
                    .offset(x: isOn ? 10 : -10)
            }
            .frame(width: 52, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabelText)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - BLCheckbox

/// Full-width `44pt`-min-height checkbox with `24×24` `6pt`-radius box.
public struct BLCheckbox: View {
    @Environment(\.blTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var isChecked: Bool
    private let label: String
    private let sub: String?

    public init(isChecked: Binding<Bool>, label: String, sub: String? = nil) {
        self._isChecked = isChecked
        self.label = label
        self.sub = sub
    }

    public var body: some View {
        Button {
            withAnimation(
                BLMotion.easeOut(duration: BLMotion.fast, reducedMotion: reduceMotion)
            ) {
                isChecked.toggle()
            }
        } label: {
            HStack(alignment: .center, spacing: BLSpacing.space3) {
                BLCheckboxSquare(isChecked: isChecked)

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .blTextRole(.body)
                        .foregroundStyle(theme.textPrimary)
                    if let sub, !sub.isEmpty {
                        Text(sub)
                            .blTextRole(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: BLHitTarget.min)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}

/// Reusable `24×24` checkbox indicator used by `BLCheckbox` and `BLDraftCard`.
struct BLCheckboxSquare: View {
    @Environment(\.blTheme) private var theme
    let isChecked: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: BLRadius.xs, style: .continuous)
                .fill(isChecked ? theme.accent : theme.bgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: BLRadius.xs, style: .continuous)
                        .strokeBorder(
                            isChecked ? theme.accentBorder : theme.borderStrong,
                            lineWidth: 1.5
                        )
                )

            if isChecked {
                Image(systemName: BLSymbol.check)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(theme.textOnAccent)
            }
        }
        .frame(width: 24, height: 24)
    }
}

// MARK: - BLTextField

/// Paper-bordered text field or multiline text area with crisp honey focus ring.
public struct BLTextField: View {
    @Environment(\.blTheme) private var theme
    @FocusState private var isFocused: Bool

    private let label: String?
    private let placeholder: String
    @Binding private var text: String
    private let isMultiline: Bool
    private let minLines: Int

    public init(
        label: String? = nil,
        placeholder: String = "",
        text: Binding<String>,
        isMultiline: Bool = false,
        minLines: Int = 3
    ) {
        self.label = label
        self.placeholder = placeholder
        self._text = text
        self.isMultiline = isMultiline
        self.minLines = minLines
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label, !label.isEmpty {
                Text(label)
                    .blMicroLabel()
            }

            let shape = RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
            Group {
                if isMultiline {
                    TextField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundStyle(theme.textTertiary),
                        axis: .vertical
                    )
                    .lineLimit(minLines...8)
                } else {
                    TextField(
                        "",
                        text: $text,
                        prompt: Text(placeholder).foregroundStyle(theme.textTertiary)
                    )
                }
            }
            .textFieldStyle(.plain)
            .blTextRole(.body)
            .foregroundStyle(theme.textPrimary)
            .tint(theme.accentBorder)
            .focused($isFocused)
            .padding(.vertical, 11)
            .padding(.horizontal, 14)
            .frame(minHeight: isMultiline ? 96 : 48, alignment: isMultiline ? .topLeading : .leading)
            .background(shape.fill(theme.bgSurface))
            .overlay(
                shape.strokeBorder(
                    isFocused ? theme.accentBorder : theme.borderStrong,
                    lineWidth: BLSpacing.borderWidth
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: BLRadius.md + 2, style: .continuous)
                    .stroke(isFocused ? theme.accentSoft : .clear, lineWidth: 3)
                    .padding(-2)
            )
        }
    }
}

// MARK: - BLAmountField

/// Giant display-serif numeral on a ruled bottom line, like filling in a paper log.
public struct BLAmountField: View {
    public enum Size: Sendable, Hashable {
        case lg
        case md

        var numberSize: CGFloat {
            switch self {
            case .lg: 64
            case .md: 40
            }
        }

        var unitSize: CGFloat {
            switch self {
            case .lg: 22
            case .md: 18
            }
        }
    }

    @Environment(\.blTheme) private var theme
    @FocusState private var isFocused: Bool

    @Binding private var text: String
    private let unit: String
    private let size: Size
    private let placeholder: String

    public init(
        text: Binding<String>,
        unit: String,
        size: Size = .lg,
        placeholder: String = "0"
    ) {
        self._text = text
        self.unit = unit
        self.size = size
        self.placeholder = placeholder
    }

    private var sanitizedBinding: Binding<String> {
        Binding(
            get: { text },
            set: { newValue in
                let normalized = newValue.replacingOccurrences(of: ",", with: ".")
                var sawDot = false
                let filtered = normalized.filter { ch in
                    if ch.isNumber { return true }
                    if ch == "." && !sawDot {
                        sawDot = true
                        return true
                    }
                    return false
                }
                text = filtered
            }
        )
    }

    private var measuringString: String {
        text.isEmpty ? placeholder : text
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: BLSpacing.space2) {
            Text(measuringString)
                .font(BLFont.display(size: size.numberSize, weight: .regular, tabularNumerals: true))
                .tracking(BLFont.displayTrackingRatio * size.numberSize)
                .padding(.horizontal, 4)
                .opacity(0)
                .accessibilityHidden(true)
                .overlay {
                    amountInput
                }

            if !unit.isEmpty {
                Text(unit)
                    .font(BLFont.display(size: size.unitSize, weight: .medium, tabularNumerals: false))
                    .foregroundStyle(theme.textSecondary)
            }
        }
        .padding(.top, BLSpacing.space1)
        .padding(.bottom, 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isFocused ? theme.accentBorder : theme.borderStrong)
                .frame(height: BLSpacing.borderWidth)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isFocused = true
        }
    }

    @ViewBuilder
    private var amountInput: some View {
        let field = TextField(
            "",
            text: sanitizedBinding,
            prompt: Text(placeholder).foregroundStyle(theme.textTertiary)
        )
        .textFieldStyle(.plain)
        .font(BLFont.display(size: size.numberSize, weight: .regular, tabularNumerals: true))
        .tracking(BLFont.displayTrackingRatio * size.numberSize)
        .foregroundStyle(theme.textPrimary)
        .multilineTextAlignment(.trailing)
        .tint(theme.accentBorder)
        .focused($isFocused)

        #if os(iOS)
        field.keyboardType(.decimalPad)
        #else
        field
        #endif
    }
}

// MARK: - BLTimeField

/// Crisp `44pt` hairline-bordered clock time picker matching the paper form aesthetic.
public struct BLTimeField: View {
    @Environment(\.blTheme) private var theme

    private let label: String?
    @Binding private var date: Date

    public init(label: String? = nil, date: Binding<Date>) {
        self.label = label
        self._date = date
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label, !label.isEmpty {
                Text(label)
                    .blMicroLabel()
            }

            let shape = RoundedRectangle(cornerRadius: BLRadius.md, style: .continuous)
            HStack {
                DatePicker(
                    label ?? "Time",
                    selection: $date,
                    displayedComponents: .hourAndMinute
                )
                .labelsHidden()
                .datePickerStyle(.compact)
                .font(BLFont.ui(size: 16, weight: .medium, tabularNumerals: true))
                .foregroundStyle(theme.textPrimary)
                .tint(theme.accentText)
            }
            .padding(.horizontal, BLSpacing.space2)
            .frame(minHeight: BLHitTarget.min)
            .background(shape.fill(theme.bgSurface))
            .overlay(shape.strokeBorder(theme.borderStrong, lineWidth: BLSpacing.borderWidth))
        }
    }
}
