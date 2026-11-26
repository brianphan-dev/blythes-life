import BlythesLifeShared
import Foundation

/// Deterministic demo seed matching `KitData.jsx`, `RhythmScreen.jsx`, and `ScanScreens.jsx`.
public enum SampleSeedData: Sendable {
    public static let defaultTimeZoneIdentifier = "America/Los_Angeles"

    public static let householdId = UUID(uuidString: "10000000-0000-4000-8000-000000000001")!
    public static let profileId = UUID(uuidString: "10000000-0000-4000-8000-000000000002")!
    public static let ownerUserId = UUID(uuidString: "10000000-0000-4000-8000-000000000003")!
    public static let spouseUserId = UUID(uuidString: "10000000-0000-4000-8000-000000000004")!
    public static let grandmaUserId = UUID(uuidString: "10000000-0000-4000-8000-000000000005")!
    public static let pendingSheetId = UUID(uuidString: "20000000-0000-4000-8000-000000000001")!
    public static let earlierSheetId = UUID(uuidString: "20000000-0000-4000-8000-000000000002")!
    public static let tuesdaySheetId = UUID(uuidString: "20000000-0000-4000-8000-000000000003")!
    public static let mondaySheetId = UUID(uuidString: "20000000-0000-4000-8000-000000000004")!

    /// Wed, Nov 25, 2026 at 12:54 PM in `America/Los_Angeles` (minute 774, matching `KitData.jsx` `BASE_NOW`).
    public static var defaultReferenceDate: Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: defaultTimeZoneIdentifier) ?? .current
        return calendar.date(from: DateComponents(year: 2026, month: 11, day: 25, hour: 12, minute: 54)) ?? Date()
    }

    public static func makeDemoState(
        referenceDate: Date = SampleSeedData.defaultReferenceDate,
        timeZone: TimeZone = TimeZone(identifier: SampleSeedData.defaultTimeZoneIdentifier) ?? .current
    ) -> PersistedAppState {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let todayStart = calendar.startOfDay(for: referenceDate)

        // Compute birthDate 8 months prior to `referenceDate` so Blythe always reads "8 months".
        let birthDateObject = calendar.date(byAdding: .month, value: -8, to: todayStart) ?? todayStart
        let birthDateString = formatISODateOnly(birthDateObject, calendar: calendar)

        let members = [
            HouseholdMemberDTO(householdId: householdId, userId: ownerUserId, role: .owner, displayName: "Brian"),
            HouseholdMemberDTO(householdId: householdId, userId: spouseUserId, role: .member, displayName: "Sarah"),
            HouseholdMemberDTO(householdId: householdId, userId: grandmaUserId, role: .caregiver, displayName: "Grandma")
        ]

        let household = HouseholdDTO(
            id: householdId,
            name: "Blythe's household",
            inviteCode: "482913",
            inviteExpiresAt: calendar.date(byAdding: .day, value: 7, to: referenceDate),
            createdBy: ownerUserId,
            createdAt: birthDateObject,
            role: .owner,
            members: members
        )

        let schedule = ScheduleConfig(
            wakeWindowsMinutes: [150, 195],
            napCapMinutes: 90,
            shortNapThresholdMinutes: 45,
            shortNapNextWindowMinutes: 150,
            backupCatnapCutoffMinutesFromMidnight: 990, // 4:30 PM
            backupCatnapDurationMinutes: 25
        )

        let profile = ProfileDTO(
            id: profileId,
            householdId: householdId,
            displayName: "Blythe",
            birthDate: birthDateString,
            defaultTimezone: timeZone.identifier,
            scheduleConfig: schedule,
            createdAt: birthDateObject,
            updatedAt: referenceDate
        )

        let priorEvents = makePriorSixDaysEvents(
            todayStart: todayStart,
            calendar: calendar,
            timeZoneIdentifier: timeZone.identifier
        )
        let todayEvents = makeTodayEvents(
            todayStart: todayStart,
            timeZoneIdentifier: timeZone.identifier
        )
        let scannedSheets = makeScannedSheets(
            todayStart: todayStart,
            calendar: calendar,
            timeZone: timeZone
        )

        return PersistedAppState(
            profile: profile,
            household: household,
            currentUserId: ownerUserId,
            events: priorEvents + todayEvents,
            activeNapStart: nil,
            activeNursingSession: nil,
            pendingScans: scannedSheets,
            outbox: [],
            serverWatermark: nil,
            preferredUnit: .oz,
            colorMode: .day,
            authEmail: "brian@icloud.com",
            displayName: "Brian",
            isSignedInWithApple: true
        )
    }

    // MARK: - Today's 8 Events (Matching KitData.jsx INITIAL_EVENTS)

    private static func makeTodayEvents(todayStart: Date, timeZoneIdentifier: String) -> [EventDTO] {
        func at(_ minutesFromMidnight: Int) -> Date {
            todayStart.addingTimeInterval(TimeInterval(minutesFromMidnight * 60))
        }

        func makeEvent(
            index: Int,
            type: EventType,
            startedAt: Date,
            endedAt: Date? = nil,
            notes: String? = nil,
            metadata: EventMetadata,
            source: EventSource = .manual,
            scanId: UUID? = nil
        ) -> EventDTO {
            let uuid = UUID(uuidString: String(format: "30000000-0000-4000-8000-%012d", index))!
            return EventDTO(
                id: uuid,
                profileId: profileId,
                eventType: type,
                startedAt: startedAt,
                endedAt: endedAt,
                timezone: timeZoneIdentifier,
                notes: notes,
                metadata: metadata,
                source: source,
                scanId: scanId,
                externalId: nil,
                createdBy: ownerUserId,
                updatedBy: ownerUserId,
                createdAt: endedAt ?? startedAt,
                updatedAt: endedAt ?? startedAt
            )
        }

        return [
            // a1: Night sleep 7:10 PM (-290m) – 6:45 AM (405m) · 11h 35m
            makeEvent(
                index: 1,
                type: .sleep,
                startedAt: at(-290),
                endedAt: at(405),
                metadata: .sleep(SleepMetadata(sleepType: .night))
            ),
            // a2: Bottle 7:00 AM (420m) · 4 oz formula
            makeEvent(
                index: 2,
                type: .feeding,
                startedAt: at(420),
                metadata: .feeding(FeedingMetadata(method: .bottle, substance: .formula, amountOz: 4))
            ),
            // a3: Diaper 7:05 AM (425m) · Pee M
            makeEvent(
                index: 3,
                type: .diaper,
                startedAt: at(425),
                metadata: .diaper(DiaperMetadata(peeSize: .medium, poopSize: nil, rash: false))
            ),
            // a4: Breakfast 8:00 AM (480m) · Oatmeal, banana · Some eaten
            makeEvent(
                index: 4,
                type: .meal,
                startedAt: at(480),
                notes: "Oatmeal, banana",
                metadata: .meal(MealMetadata(mealSlot: .breakfast, portionEaten: .some))
            ),
            // a5: Nap 1 9:15 – 10:32 AM (555..632m) · 1h 17m (paper_scan)
            makeEvent(
                index: 5,
                type: .sleep,
                startedAt: at(555),
                endedAt: at(632),
                metadata: .sleep(SleepMetadata(sleepType: .nap)),
                source: .paperScan,
                scanId: earlierSheetId
            ),
            // a5p: Pump 9:45 AM (585m) · 4.5 oz · Both sides
            makeEvent(
                index: 6,
                type: .pump,
                startedAt: at(585),
                metadata: .pump(PumpMetadata(amountOz: 4.5, side: .both))
            ),
            // a6: Diaper 10:40 AM (640m) · Pee L · Poop S (paper_scan)
            makeEvent(
                index: 7,
                type: .diaper,
                startedAt: at(640),
                metadata: .diaper(DiaperMetadata(peeSize: .large, poopSize: .small, rash: false)),
                source: .paperScan,
                scanId: earlierSheetId
            ),
            // a7: Bottle 10:45 AM (645m) · 2.5 oz breast milk (paper_scan)
            makeEvent(
                index: 8,
                type: .feeding,
                startedAt: at(645),
                metadata: .feeding(FeedingMetadata(method: .bottle, substance: .breastMilk, amountOz: 2.5)),
                source: .paperScan,
                scanId: earlierSheetId
            )
        ]
    }

    // MARK: - 6 Prior Days of Rhythm History (Matching RhythmScreen.jsx pastDay)

    private static func makePriorSixDaysEvents(
        todayStart: Date,
        calendar: Calendar,
        timeZoneIdentifier: String
    ) -> [EventDTO] {
        func pseudoRandom(_ i: Int) -> Double {
            let x = sin(Double(i) * 99.13) * 43758.5453
            return x - floor(x)
        }

        var result: [EventDTO] = []
        var counter = 100

        func nextUUID() -> UUID {
            counter += 1
            return UUID(uuidString: String(format: "30000000-0000-4000-8000-%012d", counter))!
        }

        for dayIndex in 1 ... 6 {
            let dayOffset = dayIndex - 7 // -6 ... -1
            guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: todayStart) else { continue }

            func jitter(_ k: Int) -> Int {
                Int(((pseudoRandom(dayIndex * 11 + k) - 0.5) * 36.0).rounded())
            }
            func at(_ minute: Int) -> Date {
                dayStart.addingTimeInterval(TimeInterval(minute * 60))
            }

            let wake = 405 + jitter(1)
            let nap1Start = 555 + jitter(2)
            let nap1End = nap1Start + 72 + jitter(3) / 2
            let nap2Start = 835 + jitter(4)
            let nap2End = nap2Start + 78 + jitter(5) / 2
            let bedtime = 1150 + jitter(6)

            // Morning wake portion of prior night sleep (from 0:00 to wake) so the day column starts asleep cleanly
            // On dayOffset == -1 (Tuesday), today's Night sleep already covers Tuesday bedtime -> Wednesday 6:45 AM!
            if dayIndex == 1 {
                result.append(EventDTO(
                    id: nextUUID(),
                    profileId: profileId,
                    eventType: .sleep,
                    startedAt: at(-290),
                    endedAt: at(wake),
                    timezone: timeZoneIdentifier,
                    metadata: .sleep(SleepMetadata(sleepType: .night)),
                    source: .manual,
                    createdBy: ownerUserId,
                    updatedBy: ownerUserId,
                    createdAt: at(wake),
                    updatedAt: at(wake)
                ))
            }

            // Daytime naps
            result.append(EventDTO(
                id: nextUUID(),
                profileId: profileId,
                eventType: .sleep,
                startedAt: at(nap1Start),
                endedAt: at(nap1End),
                timezone: timeZoneIdentifier,
                metadata: .sleep(SleepMetadata(sleepType: .nap)),
                source: .paperScan,
                createdBy: ownerUserId,
                updatedBy: ownerUserId,
                createdAt: at(nap1End),
                updatedAt: at(nap1End)
            ))
            result.append(EventDTO(
                id: nextUUID(),
                profileId: profileId,
                eventType: .sleep,
                startedAt: at(nap2Start),
                endedAt: at(nap2End),
                timezone: timeZoneIdentifier,
                metadata: .sleep(SleepMetadata(sleepType: .nap)),
                source: .paperScan,
                createdBy: ownerUserId,
                updatedBy: ownerUserId,
                createdAt: at(nap2End),
                updatedAt: at(nap2End)
            ))

            // Overnight sleep starting this evening (for days -6 ... -2; day -1's evening is today's a1 Night sleep)
            if dayIndex < 6 {
                let nextDayIndex = dayIndex + 1
                let nextWake = 405 + Int(((pseudoRandom(nextDayIndex * 11 + 1) - 0.5) * 36.0).rounded())
                result.append(EventDTO(
                    id: nextUUID(),
                    profileId: profileId,
                    eventType: .sleep,
                    startedAt: at(bedtime),
                    endedAt: at(1440 + nextWake),
                    timezone: timeZoneIdentifier,
                    metadata: .sleep(SleepMetadata(sleepType: .night)),
                    source: .manual,
                    createdBy: ownerUserId,
                    updatedBy: ownerUserId,
                    createdAt: at(bedtime),
                    updatedAt: at(bedtime)
                ))
            }

            // 4 Bottles (formula vs breast milk)
            let feeds: [(Int, Double, FeedingSubstance)] = [
                (wake + 15, 4.0, .formula),
                (nap1End + 13, 2.5, .breastMilk),
                (nap2End + 10, 4.0, .formula),
                (bedtime - 30, 5.0, .formula)
            ]
            for (minute, oz, substance) in feeds {
                result.append(EventDTO(
                    id: nextUUID(),
                    profileId: profileId,
                    eventType: .feeding,
                    startedAt: at(minute),
                    timezone: timeZoneIdentifier,
                    metadata: .feeding(FeedingMetadata(method: .bottle, substance: substance, amountOz: oz)),
                    source: substance == .breastMilk ? .paperScan : .manual,
                    createdBy: ownerUserId,
                    updatedBy: ownerUserId,
                    createdAt: at(minute),
                    updatedAt: at(minute)
                ))
            }

            // 3 Meals
            let meals: [(Int, MealSlot, PortionEaten)] = [
                (480 + jitter(7), .breakfast, .some),
                (720 + jitter(8) / 3, .lunch, .most),
                (1050 + jitter(9), .dinner, .most)
            ]
            for (minute, slot, portion) in meals {
                result.append(EventDTO(
                    id: nextUUID(),
                    profileId: profileId,
                    eventType: .meal,
                    startedAt: at(minute),
                    timezone: timeZoneIdentifier,
                    metadata: .meal(MealMetadata(mealSlot: slot, portionEaten: portion)),
                    source: slot == .lunch ? .paperScan : .manual,
                    createdBy: ownerUserId,
                    updatedBy: ownerUserId,
                    createdAt: at(minute),
                    updatedAt: at(minute)
                ))
            }

            // 5 Diapers
            let diapers: [(Int, DiaperSize?, DiaperSize?)] = [
                (wake + 20, .medium, nil),
                (nap1End + 8, .large, .small),
                (740 + jitter(10), .medium, nil),
                (nap2End + 5, .large, nil),
                (1085 + jitter(11), .medium, nil)
            ]
            for (minute, pee, poop) in diapers {
                result.append(EventDTO(
                    id: nextUUID(),
                    profileId: profileId,
                    eventType: .diaper,
                    startedAt: at(minute),
                    timezone: timeZoneIdentifier,
                    metadata: .diaper(DiaperMetadata(peeSize: pee, poopSize: poop, rash: false)),
                    source: .manual,
                    createdBy: ownerUserId,
                    updatedBy: ownerUserId,
                    createdAt: at(minute),
                    updatedAt: at(minute)
                ))
            }
        }

        return result
    }

    // MARK: - Pending & Recent Scanned Sheets (Matching KitData.jsx DRAFTS & ScanScreens.jsx)

    private static func makeScannedSheets(
        todayStart: Date,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> [ScannedSheetRecord] {
        func at(_ minutesFromMidnight: Int) -> Date {
            todayStart.addingTimeInterval(TimeInterval(minutesFromMidnight * 60))
        }

        let drafts: [ScanReviewDraftItem] = [
            ScanReviewDraftItem(
                id: "s1",
                rowKey: "nap",
                eventType: .sleep,
                startedAt: at(555),
                endedAt: at(632),
                title: "Nap 1",
                detail: "Until 10:32 AM · 1h 17m",
                savedDetail: "9:15 – 10:32 AM · 1h 17m",
                metadata: .sleep(SleepMetadata(sleepType: .nap)),
                matchAction: .skipDuplicate,
                isSuggestion: false,
                isIncluded: false,
                boundingBox: NormalizedBoundingBox(x: 0.06, y: 0.14, width: 0.88, height: 0.11)
            ),
            ScanReviewDraftItem(
                id: "s2",
                rowKey: "d1",
                eventType: .diaper,
                startedAt: at(640),
                title: "Diaper",
                detail: "Pee L · Poop S",
                metadata: .diaper(DiaperMetadata(peeSize: .large, poopSize: .small, rash: false)),
                matchAction: .skipDuplicate,
                isSuggestion: false,
                isIncluded: false,
                boundingBox: NormalizedBoundingBox(x: 0.06, y: 0.27, width: 0.88, height: 0.10)
            ),
            ScanReviewDraftItem(
                id: "s3",
                rowKey: "b1",
                eventType: .feeding,
                startedAt: at(645),
                title: "Bottle",
                detail: "2.5 oz breast milk",
                metadata: .feeding(FeedingMetadata(method: .bottle, substance: .breastMilk, amountOz: 2.5)),
                matchAction: .skipDuplicate,
                isSuggestion: false,
                isIncluded: false,
                boundingBox: NormalizedBoundingBox(x: 0.06, y: 0.39, width: 0.88, height: 0.12)
            ),
            ScanReviewDraftItem(
                id: "s4",
                rowKey: "b1",
                eventType: .medicine,
                startedAt: at(645),
                title: "Vitamin D",
                detail: "The row is labelled + VIT D",
                savedDetail: "1 drop · supplement",
                metadata: .medicine(MedicineMetadata(name: "Vitamin D", category: .supplement, dose: 1, unit: .drops)),
                matchAction: .create,
                isSuggestion: true,
                isIncluded: false,
                boundingBox: NormalizedBoundingBox(x: 0.06, y: 0.39, width: 0.88, height: 0.12)
            ),
            ScanReviewDraftItem(
                id: "s5",
                rowKey: "d2",
                eventType: .diaper,
                startedAt: at(680), // 11:20 AM
                title: "Diaper",
                detail: "Pee L",
                metadata: .diaper(DiaperMetadata(peeSize: .large, poopSize: nil, rash: false)),
                matchAction: .create,
                isSuggestion: false,
                ambiguityQuestion: "The time was written over. Which is it?",
                ambiguityOptions: ["11:20 AM", "11:30 AM"],
                ambiguityOptionDates: [
                    "11:20 AM": at(680),
                    "11:30 AM": at(690)
                ],
                resolvedOption: nil,
                isIncluded: true,
                boundingBox: NormalizedBoundingBox(x: 0.06, y: 0.53, width: 0.88, height: 0.11)
            ),
            ScanReviewDraftItem(
                id: "s6",
                rowKey: "lunch",
                eventType: .meal,
                startedAt: at(720), // 12:00 PM
                title: "Lunch",
                detail: "Most eaten",
                metadata: .meal(MealMetadata(mealSlot: .lunch, portionEaten: .most)),
                matchAction: .create,
                isSuggestion: false,
                isIncluded: true,
                boundingBox: NormalizedBoundingBox(x: 0.06, y: 0.66, width: 0.88, height: 0.11)
            ),
            ScanReviewDraftItem(
                id: "s7",
                rowKey: "d3",
                eventType: .diaper,
                startedAt: at(740), // 12:20 PM
                title: "Diaper",
                detail: "Pee M",
                metadata: .diaper(DiaperMetadata(peeSize: .medium, poopSize: nil, rash: false)),
                matchAction: .create,
                isSuggestion: false,
                isIncluded: true,
                boundingBox: NormalizedBoundingBox(x: 0.06, y: 0.79, width: 0.88, height: 0.11)
            )
        ]

        let previewLines: [ScannedSheetLinePreview] = [
            ScannedSheetLinePreview(id: "nap", label: "NAP 1", targetText: "9:15–10:45", handwrittenText: "9:15 – 10:32"),
            ScannedSheetLinePreview(id: "d1", label: "DIAPER", handwrittenText: "10:40  pee L  poop S"),
            ScannedSheetLinePreview(id: "b1", label: "BOTTLE", pills: ["BREAST MILK", "+ VIT D"], targetText: "2–4 oz", handwrittenText: "2½ oz  10:45"),
            ScannedSheetLinePreview(id: "d2", label: "DIAPER", handwrittenText: "11:20  pee L", overwrittenDigits: "2/3"),
            ScannedSheetLinePreview(id: "lunch", label: "LUNCH", targetText: "12:00", handwrittenText: "12:00  most"),
            ScannedSheetLinePreview(id: "d3", label: "DIAPER", handwrittenText: "12:20  pee M")
        ]

        let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart) ?? todayStart
        let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: todayStart) ?? todayStart

        let shortDayFormatter = DateFormatter()
        shortDayFormatter.locale = Locale(identifier: "en_US_POSIX")
        shortDayFormatter.calendar = calendar
        shortDayFormatter.timeZone = timeZone
        shortDayFormatter.dateFormat = "EEE, MMM d"

        return [
            ScannedSheetRecord(
                id: pendingSheetId,
                title: "Grandma's sheet, 12:50 PM",
                subtitle: "3 new · 3 already logged",
                listLabel: "Today, 12:50 PM",
                scannedAt: at(770),
                status: .pendingReview,
                drafts: drafts,
                previewLines: previewLines,
                imageData: nil,
                confirmedEntryCount: 0
            ),
            ScannedSheetRecord(
                id: earlierSheetId,
                title: "Grandma's sheet, 11:02 AM",
                subtitle: "3 entries saved",
                listLabel: "Today, 11:02 AM",
                scannedAt: at(662),
                status: .confirmed,
                drafts: [],
                previewLines: [],
                imageData: nil,
                confirmedEntryCount: 3
            ),
            ScannedSheetRecord(
                id: tuesdaySheetId,
                title: shortDayFormatter.string(from: yesterday),
                subtitle: "11 entries saved · 2 photos",
                listLabel: shortDayFormatter.string(from: yesterday),
                scannedAt: yesterday.addingTimeInterval(17 * 3600),
                status: .confirmed,
                drafts: [],
                previewLines: [],
                imageData: nil,
                confirmedEntryCount: 11
            ),
            ScannedSheetRecord(
                id: mondaySheetId,
                title: shortDayFormatter.string(from: twoDaysAgo),
                subtitle: "12 entries saved · 2 photos",
                listLabel: shortDayFormatter.string(from: twoDaysAgo),
                scannedAt: twoDaysAgo.addingTimeInterval(17 * 3600),
                status: .confirmed,
                drafts: [],
                previewLines: [],
                imageData: nil,
                confirmedEntryCount: 12
            )
        ]
    }

    private static func formatISODateOnly(_ date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 2026
        let m = comps.month ?? 1
        let d = comps.day ?? 1
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}
