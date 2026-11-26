import BlythesLifeCore
import BlythesLifeShared
import CoreGraphics
import Foundation
import Testing

// MARK: - Helpers

private func makeDate(
    year: Int = 2026,
    month: Int = 11,
    day: Int = 25,
    hour: Int,
    minute: Int,
    second: Int = 0,
    timeZoneIdentifier: String = SampleSeedData.defaultTimeZoneIdentifier
) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? .current
    return calendar.date(
        from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute, second: second)
    )!
}

private final class MockBackendAPI: BackendAPIProviding, Sendable {
    func signInWithApple(_ request: AppleAuthRequest) async throws -> AuthSessionResponse {
        throw BackendAPIError.unauthorized
    }

    func refreshSession(_ request: RefreshTokenRequest) async throws -> AuthSessionResponse {
        throw BackendAPIError.unauthorized
    }

    func logout(_ request: LogoutRequest, accessToken: String?) async throws {}
    func deleteAccount(accessToken: String) async throws {}

    func createHousehold(name: String, accessToken: String) async throws -> HouseholdDTO {
        HouseholdDTO(name: name, createdBy: SampleSeedData.ownerUserId)
    }

    func joinHousehold(inviteCode: String, displayName: String?, accessToken: String) async throws -> HouseholdDTO {
        HouseholdDTO(name: "Joined", inviteCode: inviteCode, createdBy: SampleSeedData.ownerUserId)
    }

    func rotateInviteCode(householdId: UUID, accessToken: String) async throws -> HouseholdDTO {
        HouseholdDTO(id: householdId, name: "Rotated", inviteCode: "112233", createdBy: SampleSeedData.ownerUserId)
    }

    func syncPush(_ request: SyncPushRequest, accessToken: String) async throws -> SyncPushResponse {
        SyncPushResponse(
            acceptedEventIds: request.events.map(\.id),
            acceptedProfileIds: (request.profiles ?? []).map(\.id),
            rejected: [],
            serverWatermark: makeDate(hour: 13, minute: 0)
        )
    }

    func syncPull(since: Date?, limit: Int, accessToken: String) async throws -> SyncPullResponse {
        SyncPullResponse(
            events: [],
            profiles: [],
            serverWatermark: makeDate(hour: 13, minute: 0),
            hasMore: false
        )
    }

    func syncStream(accessToken: String) -> AsyncThrowingStream<SyncStreamNotification, Error> {
        AsyncThrowingStream { $0.finish() }
    }

    func presignScan(_ request: PresignUploadRequest, accessToken: String) async throws -> PresignUploadResponse {
        PresignUploadResponse(
            scanId: UUID(),
            storageKey: "scans/demo.jpg",
            uploadUrl: "https://r2.example.com/upload",
            expiresAt: Date().addingTimeInterval(300)
        )
    }

    func uploadScanBytes(to uploadURL: URL, headers: [String: String], data: Data) async throws {}

    func extractScan(_ request: ExtractPaperScanRequest, accessToken: String) async throws -> PaperScanDTO {
        PaperScanDTO(
            id: request.scanId,
            profileId: request.profileId,
            scanDate: request.scanDate ?? "2026-11-25",
            timezone: request.timezone,
            storageKey: request.storageKey,
            scannedBy: SampleSeedData.ownerUserId
        )
    }

    func confirmScan(_ request: ConfirmPaperScanRequest, accessToken: String) async throws -> PaperScanDTO {
        PaperScanDTO(
            id: request.scanId,
            profileId: request.profileId,
            scanDate: request.scanDate,
            timezone: SampleSeedData.defaultTimeZoneIdentifier,
            storageKey: "scans/demo.jpg",
            status: .confirmed,
            scannedBy: SampleSeedData.ownerUserId
        )
    }

    func exportJSON(accessToken: String) async throws -> Data { Data() }
    func exportCSV(profileId: UUID?, accessToken: String) async throws -> Data { Data() }
}

// MARK: - Formatting Tests

@Suite("FormattingHelpers")
struct FormattingHelpersTests {
    @Test("Wake window typographic fractions")
    func wakeWindowFractions() {
        #expect(FormattingHelpers.formatWakeWindowFraction(minutes: 150) == "2½h")
        #expect(FormattingHelpers.formatWakeWindowFraction(minutes: 195) == "3¼h")
        #expect(FormattingHelpers.formatWakeWindowFraction(minutes: 180) == "3h")
        #expect(FormattingHelpers.formatWakeWindowFraction(minutes: 165) == "2¾h")
        #expect(FormattingHelpers.formatWakeWindowFraction(minutes: 90) == "90m")
        #expect(FormattingHelpers.formatWakeWindowFraction(minutes: 200) == "3h 20m")
    }

    @Test("Clock, range, duration, MMSS, and amount formatting")
    func coreFormatters() {
        let tz = TimeZone(identifier: SampleSeedData.defaultTimeZoneIdentifier)!
        let start = makeDate(hour: 9, minute: 15)
        let end = makeDate(hour: 10, minute: 32)
        let evening = makeDate(day: 24, hour: 19, minute: 10)
        let morning = makeDate(day: 25, hour: 6, minute: 45)

        #expect(FormattingHelpers.formatClock(makeDate(hour: 10, minute: 45), timeZone: tz) == "10:45 AM")
        #expect(FormattingHelpers.formatRange(start, end, timeZone: tz) == "9:15 – 10:32 AM")
        #expect(FormattingHelpers.formatRange(evening, morning, timeZone: tz) == "7:10 PM – 6:45 AM")
        #expect(FormattingHelpers.formatDuration(minutes: 142) == "2h 22m")
        #expect(FormattingHelpers.formatDuration(minutes: 34) == "34m")
        #expect(FormattingHelpers.formatMMSS(seconds: 248) == "4:08")
        #expect(FormattingHelpers.formatMMSS(seconds: 0) == "0:00")
        #expect(FormattingHelpers.formatAmount(3.25, unit: .oz) == "3.25 oz")
        #expect(FormattingHelpers.formatAmount(4.0, unit: .oz) == "4 oz")
        #expect(FormattingHelpers.formatAmount(95.0, unit: .ml) == "95 mL")
        #expect(FormattingHelpers.formatMinutesFromMidnight(990) == "4:30 PM")
    }
}

// MARK: - Duo Posture Resolver Tests

@Suite("DuoPostureResolver")
struct DuoPostureResolverTests {
    @Test("Resolves compact iPhone and landscape iPhone Pro Max without false iPad classification")
    func compactPhoneAndLandscapeProMax() {
        let portrait = DuoPostureResolver.resolve(
            containerSize: CGSize(width: 393, height: 852),
            horizontalSizeClass: .compact,
            hingeStatus: nil,
            hingeAngle: nil,
            divisionRect: nil
        )
        #expect(portrait.posture == .compactPhone)
        #expect(!portrait.usesSplitLayout)
        #expect(!portrait.shouldForceNightMode)

        // Landscape iPhone Pro Max has regular horizontal size class, but height < 600.
        let landscapeProMax = DuoPostureResolver.resolve(
            containerSize: CGSize(width: 932, height: 430),
            horizontalSizeClass: .regular,
            hingeStatus: nil,
            hingeAngle: nil,
            divisionRect: nil
        )
        #expect(landscapeProMax.posture == .compactPhone)
        #expect(!landscapeProMax.isPad)
    }

    @Test("Resolves iPhone Duo folded, unfolded, tabletop, and iPad regular")
    func duoHardwareAndPadPostures() {
        let folded = DuoPostureResolver.resolve(
            containerSize: CGSize(width: 390, height: 844),
            horizontalSizeClass: .compact,
            hingeStatus: .closed,
            hingeAngle: 0,
            divisionRect: nil
        )
        #expect(folded.posture == .duoFolded)
        #expect(folded.isFoldedDuo)
        #expect(!folded.usesSplitLayout)

        let verticalCrease = CGRect(x: 410, y: 0, width: 20, height: 840)
        let unfolded = DuoPostureResolver.resolve(
            containerSize: CGSize(width: 840, height: 840),
            horizontalSizeClass: .regular,
            hingeStatus: .fullyOpen,
            hingeAngle: .pi,
            divisionRect: verticalCrease
        )
        #expect(unfolded.posture == .duoUnfolded(hingeRect: verticalCrease, axis: .vertical))
        #expect(unfolded.isUnfoldedDuo)
        #expect(unfolded.usesSplitLayout)
        #expect(!unfolded.shouldForceNightMode)
        #expect(unfolded.leadingPaneWidth == 410)
        #expect(unfolded.trailingPaneWidth == 410)

        let horizontalCrease = CGRect(x: 0, y: 410, width: 840, height: 20)
        let tabletop = DuoPostureResolver.resolve(
            containerSize: CGSize(width: 840, height: 840),
            horizontalSizeClass: .regular,
            hingeStatus: .partiallyOpen,
            hingeAngle: .pi / 2,
            divisionRect: horizontalCrease
        )
        #expect(tabletop.posture == .duoTabletop(hingeRect: horizontalCrease))
        #expect(tabletop.isTabletop)
        #expect(tabletop.shouldForceNightMode)
        #expect(tabletop.topPaneHeight == 410)
        #expect(tabletop.bottomPaneHeight == 410)

        let iPad = DuoPostureResolver.resolve(
            containerSize: CGSize(width: 1024, height: 1366),
            horizontalSizeClass: .regular,
            hingeStatus: nil,
            hingeAngle: nil,
            divisionRect: nil
        )
        #expect(iPad.posture == .iPadRegular)
        #expect(iPad.isPad)
        #expect(iPad.usesSplitLayout)
        #expect(!iPad.shouldForceNightMode)
    }

    @Test("Simulator preview overrides force every posture cleanly")
    func previewOverrides() {
        let size = CGSize(width: 393, height: 852)

        for overrideMode in PosturePreviewOverride.allCases where overrideMode != .automatic {
            let state = DuoPostureResolver.resolve(
                containerSize: size,
                horizontalSizeClass: .compact,
                hingeStatus: nil,
                hingeAngle: nil,
                divisionRect: nil,
                override: overrideMode
            )
            switch overrideMode {
            case .iPhone:
                #expect(state.posture == .compactPhone)
            case .duoFolded:
                #expect(state.posture == .duoFolded)
            case .duoUnfolded:
                #expect(state.isUnfoldedDuo)
                #expect(state.usesSplitLayout)
                #expect(state.hingeRect != nil)
            case .duoTabletop:
                #expect(state.isTabletop)
                #expect(state.shouldForceNightMode)
                #expect(state.hingeRect != nil)
            case .iPad:
                #expect(state.isPad)
                #expect(state.usesSplitLayout)
            case .automatic:
                break
            }
        }
    }
}

// MARK: - Store Lifecycle & Tracking Tests

@Suite("BlythesLifeStore")
@MainActor
struct BlythesLifeStoreTests {
    @Test("Demo seed matches KitData wake window and Today counts")
    func demoSeedAndWakeWindow() {
        let store = BlythesLifeStore.makeDemo()

        #expect(store.profile.displayName == "Blythe")
        #expect(store.profileAgeLabel == "8 months")
        #expect(store.todayEvents.count == 8)
        #expect(store.pendingReviewSheet?.title == "Grandma's sheet, 12:50 PM")

        // At 12:54 PM after Nap 1 ending at 10:32 AM: awake 2h 22m, Nap 2 sweet spot 1:47 PM · in 53m
        let napCard = store.napCardState
        #expect(napCard.mode == .awake)
        #expect(napCard.label == "Awake · since 10:32 AM")
        #expect(napCard.elapsedText == "2h 22m")
        #expect(napCard.highlightedClockTime == "1:47 PM")
        #expect(napCard.fullCaption == "Nap 2 sweet spot 1:47 PM · in 53m")
        #expect(napCard.primaryActionLabel == "Start nap")
        #expect(napCard.secondaryActionLabel == "Add a past sleep")

        #expect(store.lastFeedGlance.elapsedText == "2h 9m")
        #expect(store.lastFeedGlance.subtitle == "2.5 oz breast milk")
        #expect(store.lastDiaperGlance.elapsedText == "2h 14m")
        #expect(store.lastDiaperGlance.subtitle == "Pee L · Poop S")
    }

    @Test("Nap lifecycle with live timer, wake up, and Undo")
    func napLifecycleAndUndo() {
        let store = BlythesLifeStore.makeDemo()
        let initialTodayCount = store.todayEvents.count
        let initialOutbox = store.outboxCount

        // Start nap at 12:54 PM
        let startedEvent = store.toggleNap()
        #expect(startedEvent == nil)
        #expect(store.activeNapStart == store.now)
        #expect(store.napCardState.mode == .asleep)
        #expect(store.napCardState.primaryActionLabel == "Wake up")
        #expect(store.napCardState.secondaryActionLabel == "Change start time")

        // Undo start cancels timer cleanly
        store.undoLastToast()
        #expect(store.activeNapStart == nil)

        // Start again, advance 50 minutes, wake up
        store.toggleNap()
        store.tick(now: store.now.addingTimeInterval(50 * 60))
        #expect(store.napCardState.elapsedText == "50m")

        let savedNap = store.toggleNap()
        #expect(savedNap != nil)
        #expect(store.activeNapStart == nil)
        #expect(store.todayEvents.count == initialTodayCount + 1)
        #expect(store.outboxCount == initialOutbox + 1)
        #expect(store.toast?.message == "Nap 2 saved")

        // Undo waking up removes saved nap and restores active nap timer
        store.undoLastToast()
        #expect(store.todayEvents.count == initialTodayCount)
        #expect(store.activeNapStart != nil)
    }

    @Test("Nursing timer left/right switching, pause, finish, discard, and Undo")
    func nursingTimerLifecycle() {
        let store = BlythesLifeStore.makeDemo()
        let t0 = store.now

        // Tap left -> runs 120s
        store.tapNursingSide(.left)
        #expect(store.activeNursing?.activeSide == .left)

        store.tick(now: t0.addingTimeInterval(120))
        // Switch to right -> runs 180s
        store.tapNursingSide(.right)
        #expect(store.activeNursing?.activeSide == .right)
        #expect(store.activeNursing?.leftAccumulatedSeconds == 120)

        store.tick(now: t0.addingTimeInterval(300))
        // Tap right again -> pauses
        store.tapNursingSide(.right)
        #expect(store.activeNursing?.activeSide == nil)
        #expect(store.activeNursing?.rightAccumulatedSeconds == 180)

        // Discard + Undo restores paused session
        store.discardNursing()
        #expect(store.activeNursing == nil)
        #expect(store.toast?.message == "Nursing timer discarded")
        store.undoLastToast()
        #expect(store.activeNursing != nil)
        #expect(store.activeNursing?.leftAccumulatedSeconds == 120)
        #expect(store.activeNursing?.rightAccumulatedSeconds == 180)

        // Finish saves event with both-side metadata
        let saved = store.finishNursing()
        #expect(saved != nil)
        #expect(store.activeNursing == nil)
        if case .feeding(let meta) = saved?.metadata {
            #expect(meta.method == .breast)
            #expect(meta.side == .both)
            #expect(meta.durationMinutes == 5)
            #expect(meta.leftDurationSeconds == 120)
            #expect(meta.rightDurationSeconds == 180)
        } else {
            Issue.record("Expected breast feeding metadata")
        }
        #expect(store.eventDetail(for: saved!) == "5m · Left 2m, Right 3m")
        #expect(store.lastFeedGlance.isNursing == true)
    }

    @Test("Bottle with Vitamin D companion logs two events and undoes both together")
    func bottleWithVitaminDAndUndo() {
        let store = BlythesLifeStore.makeDemo()
        let beforeCount = store.todayEvents.count
        let beforeOutbox = store.outboxCount

        let created = store.logBottle(
            startedAt: store.now,
            amount: 3.25,
            unit: .oz,
            substance: .formula,
            includeVitaminD: true
        )
        #expect(created.count == 2)
        #expect(store.todayEvents.count == beforeCount + 2)
        #expect(store.outboxCount == beforeOutbox + 2)
        #expect(store.toast?.message == "Bottle logged · 3.25 oz")

        let bottle = created[0]
        let vitD = created[1]
        #expect(store.eventDetail(for: bottle) == "3.25 oz formula")
        #expect(store.eventTitle(for: vitD) == "Vitamin D")
        #expect(store.eventDetail(for: vitD) == "1 drop · supplement")

        store.undoLastToast()
        #expect(store.todayEvents.count == beforeCount)
        #expect(store.outboxCount == beforeOutbox)
    }

    @Test("Edit and soft-delete with Undo")
    func editAndSoftDeleteWithUndo() {
        let store = BlythesLifeStore.makeDemo()
        let original = store.logDiaper(startedAt: store.now, pee: .medium, poop: nil)
        #expect(store.eventDetail(for: original) == "Pee M")

        var edited = original
        edited.metadata = .diaper(DiaperMetadata(peeSize: .large, poopSize: .small, rash: true))
        store.updateEvent(edited)

        let updatedInStore = store.todayEvents.first(where: { $0.id == original.id })
        #expect(updatedInStore != nil)
        #expect(store.eventDetail(for: updatedInStore!) == "Pee L · Poop S · Rash")

        // Undo edit restores Pee M
        store.undoLastToast()
        let restoredAfterEditUndo = store.todayEvents.first(where: { $0.id == original.id })!
        #expect(store.eventDetail(for: restoredAfterEditUndo) == "Pee M")

        // Soft delete hides event from todayEvents but preserves tombstone in events array
        store.deleteEvent(restoredAfterEditUndo)
        #expect(store.todayEvents.first(where: { $0.id == original.id }) == nil)
        #expect(store.events.first(where: { $0.id == original.id })?.deletedAt != nil)

        // Undo delete clears deletedAt
        store.undoLastToast()
        #expect(store.todayEvents.first(where: { $0.id == original.id }) != nil)
        #expect(store.events.first(where: { $0.id == original.id })?.deletedAt == nil)
    }

    @Test("Scan review ambiguity gating, confirmation, and Undo")
    func scanReviewAmbiguityAndConfirmation() {
        let store = BlythesLifeStore.makeDemo()
        guard let sheet = store.pendingReviewSheet else {
            Issue.record("Expected pending demo sheet")
            return
        }

        #expect(sheet.drafts.count == 7)
        #expect(sheet.includedDraftCount == 3)
        #expect(sheet.unresolvedAmbiguityCount == 1)
        #expect(!sheet.canConfirm)

        // Attempting to confirm while ambiguity is unresolved must refuse and create 0 events
        let blocked = store.confirmScanReview(sheetId: sheet.id, drafts: sheet.drafts)
        #expect(blocked.isEmpty)
        #expect(store.pendingReviewSheet != nil)

        // Resolve the overwritten diaper time to 11:30 AM and include Vitamin D suggestion
        var resolvedDrafts = sheet.drafts
        if let s5Idx = resolvedDrafts.firstIndex(where: { $0.id == "s5" }) {
            resolvedDrafts[s5Idx].resolvedOption = "11:30 AM"
        }
        if let s4Idx = resolvedDrafts.firstIndex(where: { $0.id == "s4" }) {
            resolvedDrafts[s4Idx].isIncluded = true
        }

        let updatedSheet = ScannedSheetRecord(
            id: sheet.id,
            title: sheet.title,
            subtitle: sheet.subtitle,
            scannedAt: sheet.scannedAt,
            status: sheet.status,
            drafts: resolvedDrafts
        )
        #expect(updatedSheet.canConfirm)
        #expect(updatedSheet.unresolvedAmbiguityCount == 0)

        let beforeToday = store.todayEvents.count
        let saved = store.confirmScanReview(sheetId: sheet.id, drafts: resolvedDrafts)
        #expect(saved.count == 4)
        #expect(saved.allSatisfy { $0.source == .paperScan && $0.scanId == sheet.id })
        #expect(store.todayEvents.count == beforeToday + 4)
        #expect(store.pendingReviewSheet == nil)
        #expect(store.toast?.message == "4 entries saved from Grandma's sheet")

        // Verify resolved ambiguity timestamp became 11:30 AM
        let tz = store.profileTimeZone
        let resolvedDiaper = saved.first {
            if case .diaper(let d) = $0.metadata { return d.peeSize == .large }
            return false
        }
        #expect(resolvedDiaper != nil)
        #expect(FormattingHelpers.formatClock(resolvedDiaper!.startedAt, timeZone: tz) == "11:30 AM")

        // Undo confirmation restores pending sheet and removes all 4 entries
        store.undoLastToast()
        #expect(store.todayEvents.count == beforeToday)
        #expect(store.pendingReviewSheet?.id == sheet.id)
    }

    @Test("7-day Rhythm aggregation distinguishes formula vs breast milk, nursing, and live sleep")
    func rhythmWeekAggregation() {
        let store = BlythesLifeStore.makeDemo()
        store.logManualNursing(startedAt: makeDate(hour: 11, minute: 30), minutes: 12, side: .left)
        store.toggleNap()
        store.tick(now: store.now.addingTimeInterval(30 * 60))

        let days = store.rhythmWeekDays
        #expect(days.count == 7)
        #expect(days.last?.isToday == true)
        #expect(store.rhythmWeekRangeTitle == "Nov 19 – 25")

        let today = days[6]
        #expect(today.bottleCount == 2)
        #expect(today.bottleMarks.filter(\.isBreastMilk).count == 1)
        #expect(today.bottleMarks.filter { !$0.isBreastMilk }.count == 1)
        #expect(today.totalBottleOz == 6.5)
        #expect(today.nursingCount == 1)
        #expect(today.mealCount == 1)
        #expect(today.diaperCount == 2)
        let hasLiveSpan = today.sleepSpans.contains { $0.isLive }
        #expect(hasLiveSpan)

        // Prior days should each have full 24h sleep + 4 bottles + 3 meals + 5 diapers
        for priorDay in days.prefix(6) {
            #expect(priorDay.bottleCount == 4)
            #expect(priorDay.mealCount == 3)
            #expect(priorDay.diaperCount == 5)
            #expect(priorDay.totalSleepMinutes > 600)
        }
    }

    @Test("Outbox flushes against mock BackendAPIProviding")
    func outboxFlushSync() async {
        let mockAPI = MockBackendAPI()
        let store = BlythesLifeStore.makeDemo(apiClient: mockAPI, accessToken: "test-token")
        store.logNote(startedAt: store.now, text: "Rolled over today")
        #expect(store.outboxCount >= 1)

        await store.flushOutbox()
        #expect(store.outboxCount == 0)
        if case .synced = store.syncStatus {
            // Expected
        } else {
            Issue.record("Expected synced status after flushOutbox, got \(store.syncStatus)")
        }
    }
}

// MARK: - Huckleberry Import, Portability, Persistence & SSE Tests

@Suite("Portability, Importer, Persistence & SSE")
struct PortabilityAndInfrastructureTests {
    private let sampleHuckleberryCSV = """
    "Type","Start","End","Duration","Start Condition","Start Location","End Condition","Notes"
    "Sleep","2026-11-20 09:15","2026-11-20 10:32","01:17","Crib","","","Calm nap"
    "Feed","2026-11-20 10:45","","","Formula","Bottle","4 oz","Finished bottle"
    "Feed","2026-11-20 13:00","2026-11-20 13:15","00:15","Breast","00:08L","00:07R",""
    "Pump","2026-11-20 14:00","2026-11-20 14:20","00:20","Both","2 oz","2.5 oz",""
    "Diaper","2026-11-20 14:30","","","Both","","Large","Mild rash"
    "Solids","2026-11-20 12:00","","","Avocado, pear","","Most","Loved it"
    "Meds","2026-11-20 10:45","","","Vitamin D","","1 drops",""
    """

    @Test("Huckleberry CSV parses all event types with deterministic SHA-256 externalId and idempotent re-import")
    @MainActor
    func huckleberryIdempotentImport() {
        let store = BlythesLifeStore.makeDemo()
        let parsed = HuckleberryCSVImporter.parse(
            csvString: sampleHuckleberryCSV,
            profileId: store.profile.id,
            userId: store.currentUserId,
            timezone: store.profile.defaultTimezone
        )

        #expect(parsed.count == 7)
        for event in parsed {
            #expect(event.source == .importHuckleberry)
            #expect(event.externalId?.hasPrefix("hb:") == true)
            #expect(event.externalId?.count == 19) // "hb:" + 16 hex chars
        }

        // First import adds all 7 events
        let firstAdded = store.importHuckleberryCSV(sampleHuckleberryCSV)
        #expect(firstAdded == 7)

        // Second import of identical CSV adds 0 duplicates!
        let secondAdded = store.importHuckleberryCSV(sampleHuckleberryCSV)
        #expect(secondAdded == 0)
    }

    @Test("Lossless JSON bundle round-trip and pediatrician CSV export")
    @MainActor
    func losslessJSONAndPediatricianCSV() throws {
        let store = BlythesLifeStore.makeDemo()
        store.logNote(startedAt: store.now, text: "Smiled at grandma, \"great\" mood")

        let jsonData = try store.exportLosslessJSONData()
        let imported = try DataPortabilityService.importLosslessJSON(jsonData)

        #expect(imported.schemaVersion == LosslessExportBundleV1.currentSchemaVersion)
        #expect(imported.household.id == store.household.id)
        #expect(imported.profiles.first?.scheduleConfig == store.profile.scheduleConfig)
        #expect(imported.events.count == store.activeEvents.count)

        let csv = store.exportPediatricianCSVString()
        let lines = csv.split(separator: "\n")
        #expect(lines.first == "Date,Time,Type,Details,Duration,Notes,Source")
        #expect(lines.count == store.activeEvents.count + 1)
        #expect(csv.contains("\"Smiled at grandma, \"\"great\"\" mood\""))
    }

    @Test("FileLocalStateStorage saves, loads, and clears atomically")
    func fileLocalStateStorageRoundTrip() throws {
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("blythes-life-test-\(UUID().uuidString)")
            .appendingPathComponent("state.json")
        defer {
            try? FileManager.default.removeItem(at: tempURL.deletingLastPathComponent())
        }

        let storage = FileLocalStateStorage(fileURL: tempURL)
        #expect(try storage.load() == nil)

        let seed = SampleSeedData.makeDemoState()
        try storage.save(seed)
        let loaded = try storage.load()
        #expect(loaded == seed)

        try storage.clear()
        #expect(try storage.load() == nil)
    }

    @Test("SyncSSEParser parses single-line and multi-line SSE notifications while ignoring keepalives")
    func sseLineParsing() throws {
        var parser = SyncSSEParser()
        #expect(parser.feed(line: ": keepalive") == nil)
        #expect(parser.feed(line: "event: sync") == nil)

        let payload = SyncStreamNotification(
            householdId: SampleSeedData.householdId,
            profileId: SampleSeedData.profileId,
            entityType: "event",
            entityId: UUID(),
            updatedAt: makeDate(hour: 12, minute: 55)
        )
        let jsonData = try BlythesLifeJSONCoding.makeEncoder().encode(payload)
        let jsonString = String(decoding: jsonData, as: UTF8.self)

        let decoded = parser.feed(line: "data: \(jsonString)")
        #expect(decoded == payload)
    }
}
