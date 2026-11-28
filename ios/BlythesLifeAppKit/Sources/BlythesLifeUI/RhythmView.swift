import BlythesLifeCore
import BlythesLifeDesignSystem
import BlythesLifeShared
import SwiftUI

/// PiyoLog-inspired 7-day vertical 24-hour Rhythm strip with interactive day selection,
/// daily totals card, and side-by-side selected-day event list on iPad and unfolded iPhone Duo.
@MainActor
public struct RhythmView: View {
    private static let hourMarkers: [(hour: Int, label: String)] = [
        (0, "12a"),
        (3, "3a"),
        (6, "6a"),
        (9, "9a"),
        (12, "12p"),
        (15, "3p"),
        (18, "6p"),
        (21, "9p")
    ]

    @Environment(\.blTheme) private var theme
    @Environment(\.duoLayout) private var duoLayout

    private let store: BlythesLifeStore
    private let onEditEvent: (EventDTO) -> Void

    @State private var selectedDayIndex: Int = 6

    public init(
        store: BlythesLifeStore,
        onEditEvent: @escaping (EventDTO) -> Void
    ) {
        self.store = store
        self.onEditEvent = onEditEvent
    }

    public var body: some View {
        let days = store.rhythmWeekDays
        let clampedIndex = days.isEmpty ? 0 : min(max(0, selectedDayIndex), days.count - 1)
        let selectedDay = days.isEmpty ? nil : days[clampedIndex]

        return HingeSplitContainer(
            padLeadingRatio: 0.56,
            leading: {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        headerView
                            .padding(.horizontal, -BLSpacing.screenGutter)
                        legendView
                        rhythmChart(days: days, selectedIndex: clampedIndex, chartHeight: 432)
                    }
                    .padding(.horizontal, BLSpacing.screenGutter)
                    .padding(.bottom, BLSpacing.space6)
                }
                .scrollIndicators(.hidden)
                .background(theme.bgApp)
            },
            trailing: {
                ScrollView {
                    VStack(alignment: .leading, spacing: BLSpacing.space4) {
                        if let selectedDay {
                            dayTotalsCard(
                                day: selectedDay,
                                showPumpedRow: selectedDay.pumpCount > 0 || store.rhythmWeekPumpCount > 0
                            )
                            selectedDayEventsSection(day: selectedDay)
                        }
                    }
                    .padding(.horizontal, BLSpacing.screenGutter)
                    .padding(.top, BLSpacing.space4)
                    .padding(.bottom, BLSpacing.space6)
                }
                .scrollIndicators(.hidden)
                .background(theme.bgApp)
            },
            compact: {
                VStack(spacing: 0) {
                    headerView

                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            legendView
                            rhythmChart(days: days, selectedIndex: clampedIndex, chartHeight: 384)
                            if let selectedDay {
                                dayTotalsCard(
                                    day: selectedDay,
                                    showPumpedRow: selectedDay.pumpCount > 0 || store.rhythmWeekPumpCount > 0
                                )
                                .padding(.top, BLSpacing.space3)
                                selectedDayEventsSection(day: selectedDay)
                                    .padding(.top, BLSpacing.space3)
                            }
                        }
                        .padding(.horizontal, BLSpacing.screenGutter)
                        .padding(.bottom, BLSpacing.space6)
                    }
                    .scrollIndicators(.hidden)
                }
                .background(theme.bgApp)
            }
        )
        .background(theme.bgApp)
    }

    // MARK: - Header & Legend

    private var headerView: some View {
        let unit = store.preferredUnit
        let subtitle: String = {
            if store.rhythmWeekPumpCount > 0 {
                let pumpedWeekText = FormattingHelpers.formatAmount(
                    unit == .oz ? store.rhythmWeekTotalPumpedOz : store.rhythmWeekTotalPumpedMl,
                    unit: unit
                )
                return "\(store.rhythmWeekRangeTitle) · \(pumpedWeekText) pumped"
            }
            return store.rhythmWeekRangeTitle
        }()

        return HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 2) {
                Text(subtitle)
                    .blMicroLabel()
                Text("Rhythm")
                    .blTextRole(.display)
                    .foregroundStyle(theme.textPrimary)
            }
            Spacer()
        }
        .padding(.top, 6)
        .padding(.horizontal, BLSpacing.screenGutter)
        .padding(.bottom, BLSpacing.space3)
    }

    private var legendView: some View {
        BLFlowLayout(horizontalSpacing: BLSpacing.space3, verticalSpacing: 6) {
            legendItem(label: "Sleep") {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(theme.sleep.solid)
                    .frame(width: 9, height: 9)
            }
            legendItem(label: "Formula") {
                Circle()
                    .fill(theme.feeding.solid)
                    .frame(width: 9, height: 9)
            }
            legendItem(label: "Breast milk") {
                Circle()
                    .fill(theme.bgSurface)
                    .overlay(
                        Circle()
                            .strokeBorder(theme.feeding.solid, lineWidth: 2)
                    )
                    .frame(width: 9, height: 9)
            }
            legendItem(label: "Nursing") {
                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                    .fill(theme.feeding.ink)
                    .frame(width: 5, height: 11)
            }
            legendItem(label: "Pump") {
                Rectangle()
                    .fill(theme.pump.solid)
                    .frame(width: 7, height: 7)
                    .rotationEffect(.degrees(45))
                    .frame(width: 10, height: 10)
            }
            legendItem(label: "Meal") {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(theme.meal.solid)
                    .frame(width: 9, height: 9)
            }
            legendItem(label: "Diaper") {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(theme.diaper.solid)
                    .frame(width: 9, height: 3)
            }
        }
        .padding(.bottom, BLSpacing.space3)
    }

    private func legendItem<Key: View>(label: String, @ViewBuilder key: () -> Key) -> some View {
        HStack(spacing: 5) {
            key()
            Text(label)
                .blTextRole(.caption)
                .foregroundStyle(theme.textSecondary)
        }
    }

    // MARK: - 7-Day Vertical 24-Hour Strip

    private func rhythmChart(
        days: [RhythmDaySummary],
        selectedIndex: Int,
        chartHeight: CGFloat
    ) -> some View {
        let nowMinutes = minutesSinceStartOfDay(store.now)

        return VStack(spacing: 6) {
            // Day selector header row
            HStack(spacing: 4) {
                Color.clear
                    .frame(width: 28, height: BLHitTarget.min)

                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    let isSelected = index == selectedIndex
                    Button {
                        selectedDayIndex = index
                    } label: {
                        VStack(spacing: 2) {
                            Text(day.weekdayInitial)
                                .font(BLFont.ui(size: 11, weight: .semibold))
                                .foregroundStyle(theme.textSecondary)
                            Text("\(day.dayNumber)")
                                .font(BLFont.display(size: 17, weight: .medium, tabularNumerals: true))
                                .foregroundStyle(theme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: BLHitTarget.min)
                        .background(
                            RoundedRectangle(cornerRadius: BLRadius.sm, style: .continuous)
                                .fill(isSelected ? theme.accentSoft : .clear)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(day.headerLabel)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }

            // Hour labels + 7 vertical 24h columns
            HStack(alignment: .top, spacing: 4) {
                hourAxis(chartHeight: chartHeight)
                    .frame(width: 28, height: chartHeight)

                ForEach(Array(days.enumerated()), id: \.element.id) { index, day in
                    let isSelected = index == selectedIndex
                    Button {
                        selectedDayIndex = index
                    } label: {
                        RhythmDayColumn(
                            day: day,
                            isSelected: isSelected,
                            nowMinutes: day.isToday ? nowMinutes : nil,
                            chartHeight: chartHeight
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(day.headerLabel), \(FormattingHelpers.formatDuration(minutes: day.totalSleepMinutes)) sleep")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    private func hourAxis(chartHeight: CGFloat) -> some View {
        let pxPerHour = chartHeight / 24.0
        return ZStack(alignment: .topTrailing) {
            ForEach(Self.hourMarkers, id: \.hour) { marker in
                let y = CGFloat(marker.hour) * pxPerHour
                Text(marker.label)
                    .font(BLFont.ui(size: 10, weight: .medium, tabularNumerals: true))
                    .foregroundStyle(theme.textTertiary)
                    .padding(.trailing, 2)
                    .offset(y: marker.hour == 0 ? 0 : y - 5)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
    }

    // MARK: - Day Totals & Selected Day Timeline

    private func dayTotalsCard(day: RhythmDaySummary, showPumpedRow: Bool) -> some View {
        let unit = store.preferredUnit
        let milkText = FormattingHelpers.formatAmount(
            unit == .oz ? day.totalBottleOz : day.totalBottleMl,
            unit: unit
        )
        let bottleNoun = day.bottleCount == 1 ? "bottle" : "bottles"
        let nursingDurationText = FormattingHelpers.formatDuration(minutes: day.totalNursingMinutes)
        let nursingSessionNoun = day.nursingCount == 1 ? "session" : "sessions"
        let nursingOnly = day.nursingCount > 0 && day.bottleCount == 0
        let bothBottlesAndNursing = day.nursingCount > 0 && day.bottleCount > 0
        let pumpedText = FormattingHelpers.formatAmount(
            unit == .oz ? day.totalPumpedOz : day.totalPumpedMl,
            unit: unit
        )
        let pumpSessionNoun = day.pumpCount == 1 ? "session" : "sessions"

        return BLCard {
            VStack(alignment: .leading, spacing: BLSpacing.space2) {
                HStack {
                    Text(day.headerLabel)
                        .blMicroLabel()
                    Spacer()
                    if day.isToday {
                        Text("So far")
                            .blMicroLabel()
                    }
                }

                HStack(alignment: .top, spacing: BLSpacing.space2) {
                    totalMetric(
                        value: FormattingHelpers.formatDuration(minutes: day.totalSleepMinutes),
                        label: "Sleep"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if nursingOnly {
                        totalMetric(
                            value: nursingDurationText,
                            label: "\(day.nursingCount) nursing"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        totalMetric(
                            value: milkText,
                            label: "\(day.bottleCount) \(bottleNoun)"
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    totalMetric(
                        value: "\(day.diaperCount)",
                        label: "Diapers"
                    )
                    .frame(minWidth: 54, alignment: .leading)

                    totalMetric(
                        value: "\(day.mealCount)",
                        label: "Meals"
                    )
                    .frame(minWidth: 46, alignment: .leading)
                }

                if bothBottlesAndNursing {
                    Rectangle()
                        .fill(theme.borderHairline)
                        .frame(height: BLSpacing.borderWidth)
                        .padding(.top, BLSpacing.space1)

                    HStack(alignment: .firstTextBaseline, spacing: BLSpacing.space2) {
                        Text("Nursing")
                            .blMicroLabel()
                        Spacer()
                        Text(nursingDurationText)
                            .font(BLFont.display(size: 19, weight: .medium, tabularNumerals: true))
                            .foregroundStyle(theme.textPrimary)
                        Text("· \(day.nursingCount) \(nursingSessionNoun)")
                            .blTextRole(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                    .padding(.top, 2)
                }

                if showPumpedRow {
                    Rectangle()
                        .fill(theme.borderHairline)
                        .frame(height: BLSpacing.borderWidth)
                        .padding(.top, BLSpacing.space1)

                    HStack(alignment: .firstTextBaseline, spacing: BLSpacing.space2) {
                        Text("Pumped")
                            .blMicroLabel()
                        Spacer()
                        Text(pumpedText)
                            .font(BLFont.display(size: 19, weight: .medium, tabularNumerals: true))
                            .foregroundStyle(theme.textPrimary)
                        Text("· \(day.pumpCount) \(pumpSessionNoun)")
                            .blTextRole(.caption)
                            .foregroundStyle(theme.textSecondary)
                    }
                    .padding(.top, 2)
                }
            }
        }
    }

    private func totalMetric(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(BLFont.display(size: 21, weight: .medium, tabularNumerals: true))
                .foregroundStyle(theme.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(label)
                .blTextRole(.caption)
                .foregroundStyle(theme.textSecondary)
                .lineLimit(2)
        }
    }

    private func selectedDayEventsSection(day: RhythmDaySummary) -> some View {
        let dayEvents = events(for: day)
        let noun = dayEvents.count == 1 ? "entry" : "entries"

        return VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(day.headerLabel)
                    .blMicroLabel()
                Spacer()
                Text("\(dayEvents.count) \(noun) · tap to edit")
                    .blMicroLabel()
            }
            .padding(.top, BLSpacing.space2)
            .padding(.bottom, BLSpacing.space2)

            Rectangle()
                .fill(theme.borderHairline)
                .frame(height: BLSpacing.borderWidth)

            if dayEvents.isEmpty {
                Text("No entries logged on this day")
                    .blTextRole(.callout)
                    .foregroundStyle(theme.textSecondary)
                    .padding(.vertical, BLSpacing.space4)
            } else {
                LazyVStack(spacing: 0) {
                    ForEach(dayEvents) { event in
                        BLEventRow(
                            kind: event.blEventKind,
                            time: FormattingHelpers.formatClock(
                                store.displayTimestamp(for: event),
                                timeZone: store.profileTimeZone
                            ),
                            title: store.eventTitle(for: event),
                            detail: store.eventDetail(for: event),
                            sourceIcon: event.source.blSourceIcon,
                            showDivider: true
                        ) {
                            onEditEvent(event)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func events(for day: RhythmDaySummary) -> [EventDTO] {
        let calendar = store.profileCalendar
        return store.activeEvents
            .filter { event in
                guard !event.isOpenLiveTimer else { return false }
                if case .sleep(let meta) = event.metadata, meta.sleepType == .night, let endedAt = event.endedAt {
                    return calendar.isDate(endedAt, inSameDayAs: day.date) || calendar.isDate(event.startedAt, inSameDayAs: day.date)
                }
                return calendar.isDate(event.startedAt, inSameDayAs: day.date)
            }
            .sorted { lhs, rhs in
                let lt = store.displayTimestamp(for: lhs)
                let rt = store.displayTimestamp(for: rhs)
                if lt != rt { return lt > rt }
                return lhs.createdAt > rhs.createdAt
            }
    }

    private func minutesSinceStartOfDay(_ date: Date) -> Double {
        let start = store.profileCalendar.startOfDay(for: date)
        return max(0, min(1440, date.timeIntervalSince(start) / 60.0))
    }
}

/// Single interactive 24-hour column rendered via SwiftUI `Canvas` for crisp pixel-aligned marks.
private struct RhythmDayColumn: View {
    @Environment(\.blTheme) private var theme

    let day: RhythmDaySummary
    let isSelected: Bool
    let nowMinutes: Double?
    let chartHeight: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: BLRadius.xs, style: .continuous)
        Canvas { context, size in
            let pxPerMinute = size.height / 1440.0
            let pxPerThreeHours = size.height / 8.0

            // 1. 3-hour horizontal hairlines
            for step in 1 ..< 8 {
                let y = floor(CGFloat(step) * pxPerThreeHours) + 0.5
                var line = Path()
                line.move(to: CGPoint(x: 0, y: y))
                line.addLine(to: CGPoint(x: size.width, y: y))
                context.stroke(line, with: .color(theme.borderHairline), lineWidth: 1)
            }

            // 2. Sleep spans
            for span in day.sleepSpans {
                let top = CGFloat(span.startMinute) * pxPerMinute
                let height = max(2, CGFloat(span.durationMinutes) * pxPerMinute)
                let rect = CGRect(x: 0, y: top, width: size.width, height: height)
                context.fill(Path(rect), with: .color(theme.sleep.solid.opacity(0.82)))
            }

            // 3. Bottle marks (formula solid dot, breast milk hollow ring)
            let bottleX = size.width * 0.18
            for mark in day.bottleMarks {
                let y = CGFloat(mark.minute) * pxPerMinute
                let dotRect = CGRect(x: bottleX - 4.5, y: y - 4.5, width: 9, height: 9)
                let circle = Path(ellipseIn: dotRect)
                if mark.isBreastMilk {
                    context.fill(circle, with: .color(theme.bgSurface))
                    context.stroke(circle, with: .color(theme.feeding.solid), lineWidth: 2)
                } else {
                    context.fill(circle, with: .color(theme.feeding.solid))
                }
            }

            // 4. Nursing vertical bars (dedicated lane with paper halo for high contrast on paper & sleep spans)
            let nursingX = size.width * 0.37
            for span in day.nursingSpans {
                let top = CGFloat(span.startMinute) * pxPerMinute
                let height = max(10, CGFloat(span.durationMinutes) * pxPerMinute)
                let barRect = CGRect(x: nursingX - 3, y: top, width: 6, height: height)
                let haloRect = barRect.insetBy(dx: -0.75, dy: -0.75)
                let haloPath = Path(roundedRect: haloRect, cornerRadius: 3.75)
                let barPath = Path(roundedRect: barRect, cornerRadius: 3)

                context.stroke(haloPath, with: .color(theme.bgSurface), lineWidth: 1.5)
                context.fill(barPath, with: .color(theme.feeding.ink))
                if span.isLive {
                    context.stroke(barPath, with: .color(theme.accent), lineWidth: 1.5)
                }
            }

            // 5. Pump diamonds (7×7 rotated square with subtle paper halo)
            let pumpX = size.width * 0.54
            let diamondHalfDiagonal: CGFloat = 3.5 * sqrt(2.0)
            for mark in day.pumpMarks {
                let y = CGFloat(mark.minute) * pxPerMinute
                var diamondPath = Path()
                diamondPath.move(to: CGPoint(x: pumpX, y: y - diamondHalfDiagonal))
                diamondPath.addLine(to: CGPoint(x: pumpX + diamondHalfDiagonal, y: y))
                diamondPath.addLine(to: CGPoint(x: pumpX, y: y + diamondHalfDiagonal))
                diamondPath.addLine(to: CGPoint(x: pumpX - diamondHalfDiagonal, y: y))
                diamondPath.closeSubpath()

                context.stroke(diamondPath, with: .color(theme.bgSurface), lineWidth: 1.5)
                context.fill(diamondPath, with: .color(theme.pump.solid))
                if mark.isLive {
                    context.stroke(diamondPath, with: .color(theme.accent), lineWidth: 1.5)
                }
            }

            // 6. Meal squares
            let mealX = size.width * 0.72
            for minute in day.mealMinutes {
                let y = CGFloat(minute) * pxPerMinute
                let rect = CGRect(x: mealX - 4, y: y - 4, width: 8, height: 8)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 2),
                    with: .color(theme.meal.solid)
                )
            }

            // 7. Diaper horizontal dashes
            let diaperWidth: CGFloat = min(7, max(5, size.width * 0.13))
            let diaperX = max(0, min(size.width - diaperWidth - 1.5, size.width * 0.90 - diaperWidth / 2))
            for minute in day.diaperMinutes {
                let y = CGFloat(minute) * pxPerMinute
                let rect = CGRect(x: diaperX, y: y - 1.5, width: diaperWidth, height: 3)
                context.fill(
                    Path(roundedRect: rect, cornerRadius: 1.5),
                    with: .color(theme.diaper.solid)
                )
            }

            // 8. Honey "now" horizontal line on Today's column
            if let nowMinutes {
                let y = CGFloat(nowMinutes) * pxPerMinute
                let rect = CGRect(x: 0, y: y - 1, width: size.width, height: 2)
                context.fill(Path(rect), with: .color(theme.accentPressed))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: chartHeight)
        .background(shape.fill(theme.bgSurface))
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                isSelected ? theme.accentBorder : theme.borderHairline,
                lineWidth: isSelected ? 2 : BLSpacing.borderWidth
            )
        )
    }
}
