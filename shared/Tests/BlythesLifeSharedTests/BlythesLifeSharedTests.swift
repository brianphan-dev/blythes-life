import Foundation
import Testing
@testable import BlythesLifeShared

@Suite("BlythesLifeShared Models & Coding")
struct ModelCodingTests {
    private let encoder = BlythesLifeJSONCoding.makeEncoder(sortedKeys: true)
    private let decoder = BlythesLifeJSONCoding.makeDecoder()

    private func fixedDate(_ iso: String) -> Date {
        guard let date = BlythesLifeJSONCoding.parseISO8601(iso) else {
            fatalError("Invalid test ISO date: \(iso)")
        }
        return date
    }

    @Test("All 7 EventType + EventMetadata variants round-trip with exact snake_case JSON")
    func allSevenEventTypesRoundTrip() throws {
        let profileId = UUID()
        let userId = UUID()
        let scanId = UUID()
        let t0 = fixedDate("2026-11-25T17:30:00.123Z")
        let t1 = fixedDate("2026-11-25T19:00:00.000Z")

        let events: [EventDTO] = [
            // 1. Sleep
            EventDTO(
                profileId: profileId,
                eventType: .sleep,
                startedAt: t0,
                endedAt: t1,
                timezone: "America/Los_Angeles",
                notes: "Fell asleep quickly",
                metadata: .sleep(SleepMetadata(sleepType: .nap, location: .crib)),
                source: .manual,
                createdBy: userId,
                updatedBy: userId,
                createdAt: t0,
                updatedAt: t1
            ),
            // 2. Feeding (arbitrary decimal 3.25 oz)
            EventDTO(
                profileId: profileId,
                eventType: .feeding,
                startedAt: t0,
                timezone: "America/Los_Angeles",
                metadata: .feeding(FeedingMetadata(method: .bottle, substance: .breastMilk, amountOz: 3.25)),
                source: .paperScan,
                scanId: scanId,
                createdBy: userId,
                updatedBy: userId,
                createdAt: t0,
                updatedAt: t0
            ),
            // 2b. Feeding (85 mL formula)
            EventDTO(
                profileId: profileId,
                eventType: .feeding,
                startedAt: t0,
                timezone: "America/Los_Angeles",
                metadata: .feeding(FeedingMetadata(method: .bottle, substance: .formula, amountMl: 85.0, displayUnit: .ml)),
                source: .manual,
                createdBy: userId,
                updatedBy: userId,
                createdAt: t0,
                updatedAt: t0
            ),
            // 3. Diaper
            EventDTO(
                profileId: profileId,
                eventType: .diaper,
                startedAt: t0,
                timezone: "America/Los_Angeles",
                notes: "Slight redness",
                metadata: .diaper(DiaperMetadata(peeSize: .large, poopSize: .medium, rash: true)),
                source: .controlCenter,
                createdBy: userId,
                updatedBy: userId,
                createdAt: t0,
                updatedAt: t0
            ),
            // 4. Meal
            EventDTO(
                profileId: profileId,
                eventType: .meal,
                startedAt: t0,
                timezone: "America/Los_Angeles",
                notes: "Avocado toast & blueberries",
                metadata: .meal(MealMetadata(mealSlot: .lunch, portionEaten: .most)),
                source: .manual,
                createdBy: userId,
                updatedBy: userId,
                createdAt: t0,
                updatedAt: t0
            ),
            // 5. Bath (washed_hair: true)
            EventDTO(
                profileId: profileId,
                eventType: .bath,
                startedAt: t0,
                timezone: "America/Los_Angeles",
                metadata: .bath(BathMetadata(washedHair: true)),
                source: .manual,
                createdBy: userId,
                updatedBy: userId,
                createdAt: t0,
                updatedAt: t0
            ),
            // 6a. Medicine (topical Butt Cream, nil dose & unit)
            EventDTO(
                profileId: profileId,
                eventType: .medicine,
                startedAt: t0,
                timezone: "America/Los_Angeles",
                metadata: .medicine(MedicineMetadata(name: "Butt Cream", category: .topical, dose: nil, unit: nil)),
                source: .manual,
                createdBy: userId,
                updatedBy: userId,
                createdAt: t0,
                updatedAt: t0
            ),
            // 6b. Medicine (Infant Tylenol 2.5 mL)
            EventDTO(
                profileId: profileId,
                eventType: .medicine,
                startedAt: t0,
                timezone: "America/Los_Angeles",
                metadata: .medicine(MedicineMetadata(name: "Infant Tylenol", category: .medicine, dose: 2.5, unit: .ml)),
                source: .manual,
                createdBy: userId,
                updatedBy: userId,
                createdAt: t0,
                updatedAt: t0
            ),
            // 2c. Nursing (breast feeding with side + split timer durations)
            EventDTO(
                profileId: profileId,
                eventType: .feeding,
                startedAt: t0,
                timezone: "America/Los_Angeles",
                metadata: .feeding(
                    FeedingMetadata(
                        method: .breast,
                        substance: .breastMilk,
                        amountMl: nil,
                        displayUnit: .oz,
                        side: .both,
                        durationMinutes: 12,
                        leftDurationSeconds: 420,
                        rightDurationSeconds: 300
                    )
                ),
                source: .manual,
                createdBy: userId,
                updatedBy: userId,
                createdAt: t0,
                updatedAt: t0
            ),
            // 2d. Pump (4.5 oz both sides)
            EventDTO(
                profileId: profileId,
                eventType: .pump,
                startedAt: t0,
                timezone: "America/Los_Angeles",
                metadata: .pump(PumpMetadata(amountOz: 4.5, side: .both, durationMinutes: 15)),
                source: .manual,
                createdBy: userId,
                updatedBy: userId,
                createdAt: t0,
                updatedAt: t0
            ),
            // 7. Note
            EventDTO(
                profileId: profileId,
                eventType: .note,
                startedAt: t0,
                timezone: "America/Los_Angeles",
                notes: "Happy and babbling all morning!",
                metadata: .note(NoteMetadata()),
                source: .paperScan,
                scanId: scanId,
                externalId: "hb:abc123",
                createdBy: userId,
                updatedBy: userId,
                createdAt: t0,
                updatedAt: t0
            )
        ]

        // Ensure every EventType case is represented.
        let coveredTypes = Set(events.map(\.eventType))
        #expect(coveredTypes == Set(EventType.allCases))

        for original in events {
            let data = try encoder.encode(original)
            let json = try #require(String(data: data, encoding: .utf8))
            let decoded = try decoder.decode(EventDTO.self, from: data)
            #expect(decoded == original)
            #expect(decoded.metadata.eventType == decoded.eventType)

            // Verify canonical flat snake_case metadata keys.
            switch original.metadata {
            case .sleep:
                #expect(json.contains("\"sleep_type\":\"nap\""))
                #expect(json.contains("\"location\":\"crib\""))
            case .feeding(let meta):
                #expect(json.contains("\"display_unit\":\"\(meta.displayUnit.rawValue)\""))
                if meta.method == .bottle {
                    #expect(json.contains("\"amount_ml\":"))
                    if meta.displayUnit == .oz {
                        #expect(meta.amountOz == 3.25)
                    }
                } else {
                    #expect(json.contains("\"method\":\"breast\""))
                    #expect(json.contains("\"side\":\"both\""))
                    #expect(json.contains("\"left_duration_seconds\":420"))
                }
            case .pump(let meta):
                #expect(json.contains("\"side\":\"both\""))
                #expect(json.contains("\"amount_ml\":"))
                #expect(meta.amountOz == 4.5)
            case .diaper:
                #expect(json.contains("\"pee_size\":\"L\""))
                #expect(json.contains("\"poop_size\":\"M\""))
                #expect(json.contains("\"rash\":true"))
            case .meal:
                #expect(json.contains("\"meal_slot\":\"lunch\""))
                #expect(json.contains("\"portion_eaten\":\"most\""))
            case .bath:
                #expect(json.contains("\"washed_hair\":true"))
            case .medicine(let meta):
                #expect(json.contains("\"category\":\"\(meta.category.rawValue)\""))
                if meta.category == .topical {
                    #expect(!json.contains("\"dose\""))
                    #expect(!json.contains("\"unit\""))
                } else {
                    #expect(json.contains("\"dose\":2.5"))
                    #expect(json.contains("\"unit\":\"ml\""))
                }
            case .note:
                #expect(json.contains("\"metadata\":{}"))
            }
        }
    }

    @Test("Empty metadata inside meal EventDTO decodes as .meal rather than .note")
    func emptyMealMetadataPreservesMealType() throws {
        let id = UUID()
        let profileId = UUID()
        let userId = UUID()
        let rawJSON = """
        {
          "id": "\(id.uuidString)",
          "profile_id": "\(profileId.uuidString)",
          "event_type": "meal",
          "started_at": "2026-11-25T20:00:00Z",
          "timezone": "America/Los_Angeles",
          "notes": "Pears",
          "metadata": {},
          "source": "manual",
          "created_by": "\(userId.uuidString)",
          "updated_by": "\(userId.uuidString)",
          "created_at": "2026-11-25T20:00:00Z",
          "updated_at": "2026-11-25T20:00:00Z"
        }
        """
        let decoded = try decoder.decode(EventDTO.self, from: Data(rawJSON.utf8))
        #expect(decoded.eventType == .meal)
        #expect(decoded.metadata == .meal(MealMetadata(mealSlot: nil, portionEaten: nil)))
    }

    @Test("Standalone EventMetadata decodes flat canonical JSON objects")
    func standaloneEventMetadataDecoding() throws {
        let bathJSON = Data(#"{"washed_hair":false}"#.utf8)
        let bath = try decoder.decode(EventMetadata.self, from: bathJSON)
        #expect(bath == .bath(BathMetadata(washedHair: false)))

        let diaperJSON = Data(#"{"pee_size":"L"}"#.utf8)
        let diaper = try decoder.decode(EventMetadata.self, from: diaperJSON)
        #expect(diaper == .diaper(DiaperMetadata(peeSize: .large, poopSize: nil, rash: false)))

        let medJSON = Data(#"{"name":"Butt Cream","category":"topical","dose":null,"unit":null}"#.utf8)
        let med = try decoder.decode(EventMetadata.self, from: medJSON)
        #expect(med == .medicine(MedicineMetadata(name: "Butt Cream", category: .topical, dose: nil, unit: nil)))

        let explicitMeal = try EventMetadata.decode(from: Data("{}".utf8), as: .meal, using: decoder)
        #expect(explicitMeal == .meal(MealMetadata()))
    }

    @Test("ISO-8601 date parsing accepts fractional seconds, Postgres microseconds, offsets, and plain Z")
    func iso8601DateParsingVariants() throws {
        let withMillis = try #require(BlythesLifeJSONCoding.parseISO8601("2026-11-25T22:45:43.123Z"))
        let withMicros = try #require(BlythesLifeJSONCoding.parseISO8601("2026-11-25T22:45:43.123456Z"))
        let plainZ = try #require(BlythesLifeJSONCoding.parseISO8601("2026-11-25T22:45:43Z"))
        let offset = try #require(BlythesLifeJSONCoding.parseISO8601("2026-11-25T14:45:43-08:00"))
        let offsetMillis = try #require(BlythesLifeJSONCoding.parseISO8601("2026-11-25T14:45:43.123-08:00"))

        #expect(abs(plainZ.timeIntervalSince(offset)) < 0.001)
        #expect(abs(withMillis.timeIntervalSince(offsetMillis)) < 0.001)
        #expect(abs(withMicros.timeIntervalSince(withMillis)) < 0.001)
        #expect(BlythesLifeJSONCoding.parseISO8601("not-a-date") == nil)
    }

    @Test("Sync DTOs round-trip cleanly with snake_case keys")
    func syncDTOsRoundTrip() throws {
        let householdId = UUID()
        let profileId = UUID()
        let userId = UUID()
        let eventId = UUID()
        let now = fixedDate("2026-11-25T22:00:00.500Z")

        let profile = ProfileDTO(
            id: profileId,
            householdId: householdId,
            displayName: "Blythe",
            birthDate: "2026-03-10",
            defaultTimezone: "America/Los_Angeles",
            scheduleConfig: ScheduleConfig(targetDailyMilkOzMin: 20, targetDailyMilkOzMax: 28),
            createdAt: now,
            updatedAt: now
        )
        let event = EventDTO(
            id: eventId,
            profileId: profileId,
            eventType: .diaper,
            startedAt: now,
            timezone: "America/Los_Angeles",
            metadata: .diaper(DiaperMetadata(peeSize: .small, poopSize: nil, rash: false)),
            source: .manual,
            createdBy: userId,
            updatedBy: userId,
            createdAt: now,
            updatedAt: now
        )

        let pushReq = SyncPushRequest(events: [event], profiles: [profile])
        #expect(try decoder.decode(SyncPushRequest.self, from: encoder.encode(pushReq)) == pushReq)

        let pushRes = SyncPushResponse(
            acceptedEventIds: [eventId],
            acceptedProfileIds: [profileId],
            rejected: [SyncRejectedItem(id: UUID(), reason: "stale_lww_timestamp")],
            serverWatermark: now
        )
        let pushResData = try encoder.encode(pushRes)
        let pushResJSON = try #require(String(data: pushResData, encoding: .utf8))
        #expect(pushResJSON.contains("\"accepted_event_ids\""))
        #expect(pushResJSON.contains("\"server_watermark\""))
        #expect(try decoder.decode(SyncPushResponse.self, from: pushResData) == pushRes)

        let pullRes = SyncPullResponse(events: [event], profiles: [profile], serverWatermark: now, hasMore: true)
        #expect(try decoder.decode(SyncPullResponse.self, from: encoder.encode(pullRes)) == pullRes)

        let notification = SyncStreamNotification(
            householdId: householdId,
            profileId: profileId,
            entityType: "event",
            entityId: eventId,
            updatedAt: now
        )
        #expect(try decoder.decode(SyncStreamNotification.self, from: encoder.encode(notification)) == notification)
    }

    @Test("PaperScan DTOs & CompanionSuggestion round-trip cleanly")
    func paperScanDTOsRoundTrip() throws {
        let scanId = UUID()
        let profileId = UUID()
        let userId = UUID()
        let matchedId = UUID()
        let bottleTime = fixedDate("2026-11-25T16:15:00.000Z")
        let diaperTime = fixedDate("2026-11-25T19:20:00.000Z")

        let vitDCompanion = CompanionSuggestion(
            eventType: .medicine,
            startedAt: bottleTime,
            metadata: .medicine(MedicineMetadata(name: "Vitamin D", category: .supplement, dose: 1, unit: .drops)),
            reason: "Row has + VIT D badge",
            isSelectedByDefault: true
        )

        let bottleDraft = ExtractedEventDraft(
            eventType: .feeding,
            startedAt: bottleTime,
            metadata: .feeding(FeedingMetadata(method: .bottle, substance: .breastMilk, amountOz: 2.5)),
            confidence: .high,
            rawOcrText: "8:15  2½ oz  + VIT D",
            boundingBox: NormalizedBoundingBox(x: 0.12, y: 0.24, width: 0.76, height: 0.06),
            matchAction: .create,
            suggestedCompanion: vitDCompanion
        )

        let diaperDraft = ExtractedEventDraft(
            eventType: .diaper,
            startedAt: diaperTime,
            metadata: .diaper(DiaperMetadata(peeSize: .large, poopSize: nil, rash: false)),
            confidence: .low,
            ambiguityReason: "Overwritten digit: 11:20 vs 11:30",
            rawOcrText: "11:20/30 PEE L",
            boundingBox: NormalizedBoundingBox(x: 0.10, y: 0.52, width: 0.40, height: 0.05),
            matchAction: .updateExisting,
            matchedEventId: matchedId
        )

        let extraction = PaperScanExtraction(
            detectedDate: "2026-11-25",
            timezone: "America/Los_Angeles",
            sheetNotes: "Great mood today",
            ignoredTargetNotes: ["TARGET 9:30–11", "TARGET 2–4 oz"],
            events: [bottleDraft, diaperDraft]
        )

        let scan = PaperScanDTO(
            id: scanId,
            profileId: profileId,
            scanDate: "2026-11-25",
            timezone: "America/Los_Angeles",
            storageKey: "scans/\(profileId.uuidString)/\(scanId.uuidString).jpg",
            imageUrl: "https://r2.example.com/presigned",
            modelId: "gemini-3.8-flash",
            rawExtraction: extraction,
            sheetNotes: "Great mood today",
            status: .pendingReview,
            scannedBy: userId,
            createdAt: bottleTime,
            updatedAt: diaperTime
        )

        let encodedScan = try encoder.encode(scan)
        let decodedScan = try decoder.decode(PaperScanDTO.self, from: encodedScan)
        #expect(decodedScan == scan)
        #expect(decodedScan.rawExtraction?.events.first?.suggestedCompanion?.metadata == .medicine(MedicineMetadata(name: "Vitamin D", category: .supplement, dose: 1, unit: .drops)))

        // Presign, Extract, Confirm DTOs
        let presignReq = PresignUploadRequest(profileId: profileId, contentType: "image/jpeg", fileSizeBytes: 580_000)
        #expect(try decoder.decode(PresignUploadRequest.self, from: encoder.encode(presignReq)) == presignReq)

        let presignRes = PresignUploadResponse(
            scanId: scanId,
            storageKey: scan.storageKey,
            uploadUrl: "https://r2.example.com/put",
            uploadHeaders: ["Content-Type": "image/jpeg"],
            expiresAt: diaperTime
        )
        #expect(try decoder.decode(PresignUploadResponse.self, from: encoder.encode(presignRes)) == presignRes)

        let extractReq = ExtractPaperScanRequest(
            scanId: scanId,
            profileId: profileId,
            storageKey: scan.storageKey,
            scanDate: "2026-11-25",
            timezone: "America/Los_Angeles"
        )
        #expect(try decoder.decode(ExtractPaperScanRequest.self, from: encoder.encode(extractReq)) == extractReq)

        let confirmReq = ConfirmPaperScanRequest(
            scanId: scanId,
            profileId: profileId,
            scanDate: "2026-11-25",
            sheetNotes: "Great mood today",
            events: [],
            status: .confirmed
        )
        #expect(try decoder.decode(ConfirmPaperScanRequest.self, from: encoder.encode(confirmReq)) == confirmReq)

        // Raw VLM draft JSON omitting draft_id and match_action should decode cleanly with defaults.
        let rawVlmDraftJSON = """
        {
          "event_type": "bath",
          "started_at": "2026-11-25T18:45:00-08:00",
          "metadata": { "washed_hair": false },
          "confidence": "high",
          "raw_ocr_text": "6:45 PM bath no shampoo"
        }
        """
        let decodedDraft = try decoder.decode(ExtractedEventDraft.self, from: Data(rawVlmDraftJSON.utf8))
        #expect(decodedDraft.eventType == .bath)
        #expect(decodedDraft.metadata == .bath(BathMetadata(washedHair: false)))
        #expect(decodedDraft.matchAction == .create)

        let companionDraft = vitDCompanion.toDraft(suggestedByDraftId: bottleDraft.draftId)
        #expect(companionDraft.eventType == .medicine)
        #expect(companionDraft.suggestedByDraftId == bottleDraft.draftId)

        // Exact VLM extraction-schema.json payload (using `companion_suggestion` without `draft_id`)
        let vlmExtractionJSON = """
        {
          "detected_date": "2026-11-18",
          "timezone": "America/Los_Angeles",
          "sheet_notes": null,
          "ignored_target_notes": ["TARGET 10:00"],
          "events": [
            {
              "event_type": "feeding",
              "started_at": "2026-11-18T08:15:00-08:00",
              "ended_at": null,
              "notes": null,
              "metadata": {
                "method": "bottle",
                "substance": "breast_milk",
                "amount_ml": 73.9,
                "display_unit": "oz"
              },
              "confidence": "high",
              "ambiguity_reason": null,
              "raw_ocr_text": "8:15 2½ oz + VIT D",
              "bounding_box": { "x": 0.1, "y": 0.2, "width": 0.7, "height": 0.05 },
              "match_action": "create",
              "matched_event_id": null,
              "companion_suggestion": {
                "event_type": "medicine",
                "started_at": "2026-11-18T08:15:00-08:00",
                "notes": null,
                "metadata": {
                  "name": "Vitamin D",
                  "category": "supplement",
                  "dose": null,
                  "unit": null
                },
                "reason": "Row marked + VIT D"
              }
            }
          ]
        }
        """
        let decodedVlm = try decoder.decode(PaperScanExtraction.self, from: Data(vlmExtractionJSON.utf8))
        #expect(decodedVlm.detectedDate == "2026-11-18")
        #expect(decodedVlm.ignoredTargetNotes == ["TARGET 10:00"])
        #expect(decodedVlm.events.count == 1)
        let firstVlmEvent = try #require(decodedVlm.events.first)
        #expect(firstVlmEvent.suggestedCompanion?.metadata == .medicine(MedicineMetadata(name: "Vitamin D", category: .supplement, dose: nil, unit: nil)))
    }

    @Test("Auth, Profile, and LosslessExportBundleV1 DTOs round-trip cleanly")
    func authAndExportBundleRoundTrip() throws {
        let now = fixedDate("2026-11-25T22:00:00.000Z")
        let userId = UUID()
        let householdId = UUID()
        let profileId = UUID()

        let user = UserDTO(id: userId, displayName: "Brian", primaryEmail: "brian@example.com", createdAt: now)
        let member = HouseholdMemberDTO(householdId: householdId, userId: userId, role: .owner, displayName: "Brian")
        let household = HouseholdDTO(
            id: householdId,
            name: "Phan Family",
            inviteCode: "482910",
            inviteExpiresAt: now.addingTimeInterval(86_400),
            createdBy: userId,
            createdAt: now,
            role: .owner,
            members: [member]
        )

        let appleReq = AppleAuthRequest(
            identityToken: "eyJ.mock.token",
            rawNonce: "nonce123",
            authorizationCode: "code456",
            displayName: "Brian",
            deviceId: "iphone-duo-1",
            deviceName: "Brian's iPhone Duo",
            platform: "ios"
        )
        #expect(try decoder.decode(AppleAuthRequest.self, from: encoder.encode(appleReq)) == appleReq)

        let session = AuthSessionResponse(
            accessToken: "jwt-access",
            expiresIn: 900,
            refreshToken: "opaque-refresh",
            user: user,
            households: [household]
        )
        #expect(try decoder.decode(AuthSessionResponse.self, from: encoder.encode(session)) == session)

        let refreshReq = RefreshTokenRequest(refreshToken: "opaque-refresh", deviceId: "iphone-duo-1")
        #expect(try decoder.decode(RefreshTokenRequest.self, from: encoder.encode(refreshReq)) == refreshReq)

        let logoutReq = LogoutRequest(refreshToken: "opaque-refresh", deviceId: "iphone-duo-1", revokeAllDevices: false)
        #expect(try decoder.decode(LogoutRequest.self, from: encoder.encode(logoutReq)) == logoutReq)

        let createHouseholdReq = CreateHouseholdRequest(name: "Phan Family")
        #expect(try decoder.decode(CreateHouseholdRequest.self, from: encoder.encode(createHouseholdReq)) == createHouseholdReq)

        let joinHouseholdReq = JoinHouseholdRequest(inviteCode: "482910", displayName: "Grandma")
        #expect(try decoder.decode(JoinHouseholdRequest.self, from: encoder.encode(joinHouseholdReq)) == joinHouseholdReq)

        let createProfileReq = CreateProfileRequest(
            id: profileId,
            householdId: householdId,
            displayName: "Blythe",
            birthDate: "2026-03-10",
            defaultTimezone: "America/Los_Angeles",
            scheduleConfig: ScheduleConfig()
        )
        #expect(try decoder.decode(CreateProfileRequest.self, from: encoder.encode(createProfileReq)) == createProfileReq)

        let updateProfileReq = UpdateProfileRequest(
            displayName: "Blythe P.",
            scheduleConfig: ScheduleConfig(wakeWindowsMinutes: [180, 180])
        )
        #expect(try decoder.decode(UpdateProfileRequest.self, from: encoder.encode(updateProfileReq)) == updateProfileReq)

        let profile = ProfileDTO(
            id: profileId,
            householdId: householdId,
            displayName: "Blythe",
            birthDate: "2026-03-10",
            defaultTimezone: "America/Los_Angeles",
            scheduleConfig: ScheduleConfig(),
            createdAt: now,
            updatedAt: now
        )
        let bundle = LosslessExportBundleV1(
            exportedAt: now,
            household: household,
            profiles: [profile],
            events: []
        )
        let bundleData = try encoder.encode(bundle)
        let bundleJSON = try #require(String(data: bundleData, encoding: .utf8))
        #expect(bundleJSON.contains("\"schema_version\":1"))
        #expect(try decoder.decode(LosslessExportBundleV1.self, from: bundleData) == bundle)
    }

    @Test("ScheduleConfig partial JSON decodes with canonical defaults and multi-nap presets")
    func scheduleConfigDefaults() throws {
        let decoded = try decoder.decode(ScheduleConfig.self, from: Data("{}".utf8))
        #expect(decoded.wakeWindowsMinutes == [150, 195])
        #expect(decoded.napCapMinutes == 90)
        #expect(decoded.shortNapThresholdMinutes == 45)
        #expect(decoded.shortNapNextWindowMinutes == 150)
        #expect(decoded.backupCatnapCutoffMinutesFromMidnight == 1020)
        #expect(decoded.backupCatnapDurationMinutes == 25)
        #expect(decoded.targetDailyMilkOzMin == nil)
        #expect(decoded.targetDailyMilkOzMax == nil)
        #expect(decoded.targetBedtimeMinutesFromMidnight == 1170)
        #expect(decoded.bedtimeWakeWindowMinutes == 225)
        #expect(decoded.nightWindowStartMinutesFromMidnight == 1125)
        #expect(decoded.feedingIntervalMinutes == 180)
        #expect(decoded.mealTargetMinutesFromMidnight == [510, 750, 1050])
        #expect(decoded.minMinutesAfterFeedForMeal == 45)

        #expect(ScheduleConfig.defaultWakeWindows(forNapCount: -2) == [300])
        #expect(ScheduleConfig.defaultWakeWindows(forNapCount: 0) == [300])
        #expect(ScheduleConfig.defaultWakeWindows(forNapCount: 1) == [300])
        #expect(ScheduleConfig.defaultWakeWindows(forNapCount: 2) == [150, 195])
        #expect(ScheduleConfig.defaultWakeWindows(forNapCount: 3) == [105, 135, 150])
        #expect(ScheduleConfig.defaultWakeWindows(forNapCount: 4) == [75, 90, 90, 105])
        #expect(ScheduleConfig.defaultWakeWindows(forNapCount: 5) == [75, 90, 90, 105])
        #expect(ScheduleConfig.defaultWakeWindows(forNapCount: 99) == [75, 90, 90, 105])

        #expect(ScheduleConfig.defaultBedtimeWakeWindow(forNapCount: -1) == 315)
        #expect(ScheduleConfig.defaultBedtimeWakeWindow(forNapCount: 0) == 315)
        #expect(ScheduleConfig.defaultBedtimeWakeWindow(forNapCount: 1) == 315)
        #expect(ScheduleConfig.defaultBedtimeWakeWindow(forNapCount: 2) == 225)
        #expect(ScheduleConfig.defaultBedtimeWakeWindow(forNapCount: 3) == 165)
        #expect(ScheduleConfig.defaultBedtimeWakeWindow(forNapCount: 4) == 120)
        #expect(ScheduleConfig.defaultBedtimeWakeWindow(forNapCount: 5) == 120)
        #expect(ScheduleConfig.defaultBedtimeWakeWindow(forNapCount: 99) == 120)

        // Initializer derives bedtimeWakeWindowMinutes from wakeWindowsMinutes.count when omitted
        #expect(ScheduleConfig(wakeWindowsMinutes: [300]).bedtimeWakeWindowMinutes == 315)
        #expect(ScheduleConfig(wakeWindowsMinutes: [150, 195]).bedtimeWakeWindowMinutes == 225)
        #expect(ScheduleConfig(wakeWindowsMinutes: [105, 135, 150]).bedtimeWakeWindowMinutes == 165)
        #expect(ScheduleConfig(wakeWindowsMinutes: [75, 90, 90, 105]).bedtimeWakeWindowMinutes == 120)

        #expect(ScheduleConfig.defaultMealTargets(forMealCount: -1) == [1050])
        #expect(ScheduleConfig.defaultMealTargets(forMealCount: 0) == [1050])
        #expect(ScheduleConfig.defaultMealTargets(forMealCount: 1) == [1050])
        #expect(ScheduleConfig.defaultMealTargets(forMealCount: 2) == [720, 1050])
        #expect(ScheduleConfig.defaultMealTargets(forMealCount: 3) == [510, 750, 1050])
        #expect(ScheduleConfig.defaultMealTargets(forMealCount: 4) == [510, 750, 1050])
    }

    @Test("ScheduleConfig legacy JSON migrates bedtime_window_start_minutes_from_midnight and full config round-trips")
    func scheduleConfigLegacyCompatibilityAndRoundTrip() throws {
        // Legacy JSON with no bedtime fields -> defaults to 7:30 PM (1170) and derives bedtime wake window from nap count
        let legacyNoBedtimeJSON = """
        {
          "wake_windows_minutes": [105, 135, 150],
          "nap_cap_minutes": 90,
          "short_nap_threshold_minutes": 45,
          "short_nap_next_window_minutes": 150,
          "backup_catnap_cutoff_minutes_from_midnight": 1020,
          "backup_catnap_duration_minutes": 25,
          "target_daily_milk_oz_min": 22.0,
          "target_daily_milk_oz_max": 30.0
        }
        """
        let decodedLegacy = try decoder.decode(ScheduleConfig.self, from: Data(legacyNoBedtimeJSON.utf8))
        #expect(decodedLegacy.wakeWindowsMinutes == [105, 135, 150])
        #expect(decodedLegacy.targetDailyMilkOzMin == 22.0)
        #expect(decodedLegacy.targetDailyMilkOzMax == 30.0)
        #expect(decodedLegacy.targetBedtimeMinutesFromMidnight == ScheduleConfig.defaultTargetBedtimeMinutesFromMidnight)
        #expect(decodedLegacy.bedtimeWakeWindowMinutes == 165)
        #expect(decodedLegacy.nightWindowStartMinutesFromMidnight == 1125)
        #expect(decodedLegacy.feedingIntervalMinutes == ScheduleConfig.defaultFeedingIntervalMinutes)
        #expect(decodedLegacy.mealTargetMinutesFromMidnight == ScheduleConfig.defaultMealTargetMinutesFromMidnight)
        #expect(decodedLegacy.minMinutesAfterFeedForMeal == ScheduleConfig.defaultMinMinutesAfterFeedForMeal)

        // Legacy JSON with bedtime_window_start_minutes_from_midnight migrates by +45m, clamped to 1050...1380
        let legacyBedtimeJSON = Data(#"{"bedtime_window_start_minutes_from_midnight":1110}"#.utf8)
        let migratedBedtime = try decoder.decode(ScheduleConfig.self, from: legacyBedtimeJSON)
        #expect(migratedBedtime.targetBedtimeMinutesFromMidnight == 1155) // 6:30 PM + 45m = 7:15 PM
        #expect(migratedBedtime.nightWindowStartMinutesFromMidnight == 1110)

        let legacyTooEarly = try decoder.decode(
            ScheduleConfig.self,
            from: Data(#"{"bedtime_window_start_minutes_from_midnight":900}"#.utf8)
        )
        #expect(legacyTooEarly.targetBedtimeMinutesFromMidnight == 1050)

        let legacyTooLate = try decoder.decode(
            ScheduleConfig.self,
            from: Data(#"{"bedtime_window_start_minutes_from_midnight":1380}"#.utf8)
        )
        #expect(legacyTooLate.targetBedtimeMinutesFromMidnight == 1380)

        // Canonical key wins over legacy key if both are present
        let bothKeys = try decoder.decode(
            ScheduleConfig.self,
            from: Data(#"{"target_bedtime_minutes_from_midnight":1200,"bedtime_window_start_minutes_from_midnight":1110}"#.utf8)
        )
        #expect(bothKeys.targetBedtimeMinutesFromMidnight == 1200)

        let custom = ScheduleConfig(
            wakeWindowsMinutes: [150, 195],
            targetDailyMilkOzMin: 24,
            targetDailyMilkOzMax: 32,
            targetBedtimeMinutesFromMidnight: 1200,
            bedtimeWakeWindowMinutes: 240,
            feedingIntervalMinutes: 210,
            mealTargetMinutesFromMidnight: [720, 1050],
            minMinutesAfterFeedForMeal: 60
        )
        let encoded = try encoder.encode(custom)
        let jsonString = try #require(String(data: encoded, encoding: .utf8))
        #expect(jsonString.contains("\"target_bedtime_minutes_from_midnight\":1200"))
        #expect(jsonString.contains("\"bedtime_wake_window_minutes\":240"))
        #expect(!jsonString.contains("\"bedtime_window_start_minutes_from_midnight\""))
        #expect(jsonString.contains("\"feeding_interval_minutes\":210"))
        #expect(jsonString.contains("\"meal_target_minutes_from_midnight\":[720,1050]"))
        #expect(jsonString.contains("\"min_minutes_after_feed_for_meal\":60"))
        #expect(try decoder.decode(ScheduleConfig.self, from: encoded) == custom)
    }

    @Test("Household invites, join requests, and updated Household/AuthSession DTOs round-trip cleanly")
    func householdInvitesAndJoinRequestsRoundTrip() throws {
        let now = fixedDate("2026-11-26T16:00:00.000Z")
        let expires = fixedDate("2026-11-27T16:00:00.000Z")
        let usedAt = fixedDate("2026-11-26T18:30:00.000Z")
        let resolvedAt = fixedDate("2026-11-26T19:00:00.000Z")

        let ownerId = UUID()
        let grandmaId = UUID()
        let householdId = UUID()
        let inviteId = UUID()
        let joinRequestId = UUID()

        // Verify all HouseholdJoinRequestStatus cases round-trip.
        #expect(Set(HouseholdJoinRequestStatus.allCases) == [.pending, .approved, .declined])
        for status in HouseholdJoinRequestStatus.allCases {
            let encoded = try encoder.encode(status)
            let decoded = try decoder.decode(HouseholdJoinRequestStatus.self, from: encoded)
            #expect(decoded == status)
        }

        // HouseholdInviteDTO (active + used/revoked variant)
        let activeInvite = HouseholdInviteDTO(
            id: inviteId,
            householdId: householdId,
            code: "BLY-9K4M-7Q2P",
            label: "Grandma (Weekday Care)",
            role: .caregiver,
            createdBy: ownerId,
            createdAt: now,
            expiresAt: expires,
            usedAt: nil,
            usedBy: nil,
            revokedAt: nil
        )
        let activeInviteData = try encoder.encode(activeInvite)
        let activeInviteJSON = try #require(String(data: activeInviteData, encoding: .utf8))
        #expect(activeInviteJSON.contains("\"household_id\""))
        #expect(activeInviteJSON.contains("\"created_by\""))
        #expect(activeInviteJSON.contains("\"created_at\""))
        #expect(activeInviteJSON.contains("\"expires_at\""))
        #expect(activeInviteJSON.contains("\"role\":\"caregiver\""))
        #expect(try decoder.decode(HouseholdInviteDTO.self, from: activeInviteData) == activeInvite)

        let usedRevokedInvite = HouseholdInviteDTO(
            id: UUID(),
            householdId: householdId,
            code: "BLY-3X8N-5W1V",
            label: nil,
            role: .member,
            createdBy: ownerId,
            createdAt: now,
            expiresAt: expires,
            usedAt: usedAt,
            usedBy: grandmaId,
            revokedAt: resolvedAt
        )
        let usedInviteData = try encoder.encode(usedRevokedInvite)
        let usedInviteJSON = try #require(String(data: usedInviteData, encoding: .utf8))
        #expect(usedInviteJSON.contains("\"used_at\""))
        #expect(usedInviteJSON.contains("\"used_by\""))
        #expect(usedInviteJSON.contains("\"revoked_at\""))
        #expect(try decoder.decode(HouseholdInviteDTO.self, from: usedInviteData) == usedRevokedInvite)

        // HouseholdJoinRequestDTO (pending + resolved)
        let pendingRequest = HouseholdJoinRequestDTO(
            id: joinRequestId,
            householdId: householdId,
            householdName: "Phan Family",
            inviteId: inviteId,
            userId: grandmaId,
            displayName: "Grandma",
            requestedRole: .caregiver,
            status: .pending,
            createdAt: usedAt,
            resolvedAt: nil
        )
        let pendingReqData = try encoder.encode(pendingRequest)
        let pendingReqJSON = try #require(String(data: pendingReqData, encoding: .utf8))
        #expect(pendingReqJSON.contains("\"household_id\""))
        #expect(pendingReqJSON.contains("\"household_name\":\"Phan Family\""))
        #expect(pendingReqJSON.contains("\"invite_id\""))
        #expect(pendingReqJSON.contains("\"user_id\""))
        #expect(pendingReqJSON.contains("\"display_name\":\"Grandma\""))
        #expect(pendingReqJSON.contains("\"requested_role\":\"caregiver\""))
        #expect(pendingReqJSON.contains("\"status\":\"pending\""))
        #expect(try decoder.decode(HouseholdJoinRequestDTO.self, from: pendingReqData) == pendingRequest)

        let declinedRequest = HouseholdJoinRequestDTO(
            id: UUID(),
            householdId: householdId,
            householdName: "Phan Family",
            inviteId: nil,
            userId: grandmaId,
            displayName: "Unknown Device",
            requestedRole: .member,
            status: .declined,
            createdAt: usedAt,
            resolvedAt: resolvedAt
        )
        let declinedData = try encoder.encode(declinedRequest)
        let declinedJSON = try #require(String(data: declinedData, encoding: .utf8))
        #expect(declinedJSON.contains("\"resolved_at\""))
        #expect(declinedJSON.contains("\"status\":\"declined\""))
        #expect(try decoder.decode(HouseholdJoinRequestDTO.self, from: declinedData) == declinedRequest)

        // CreateHouseholdInviteRequest: custom payload + empty `{}` default decoding
        let createInviteReq = CreateHouseholdInviteRequest(
            label: "Babysitter",
            role: .caregiver,
            ttlHours: 72
        )
        let createInviteData = try encoder.encode(createInviteReq)
        let createInviteJSON = try #require(String(data: createInviteData, encoding: .utf8))
        #expect(createInviteJSON.contains("\"ttl_hours\":72"))
        #expect(try decoder.decode(CreateHouseholdInviteRequest.self, from: createInviteData) == createInviteReq)

        let emptyCreateInvite = try decoder.decode(CreateHouseholdInviteRequest.self, from: Data("{}".utf8))
        #expect(emptyCreateInvite.label == nil)
        #expect(emptyCreateInvite.role == .member)
        #expect(emptyCreateInvite.ttlHours == 24)

        let partialCreateInvite = try decoder.decode(
            CreateHouseholdInviteRequest.self,
            from: Data(#"{"label":"Spouse"}"#.utf8)
        )
        #expect(partialCreateInvite.label == "Spouse")
        #expect(partialCreateInvite.role == .member)
        #expect(partialCreateInvite.ttlHours == 24)

        // HouseholdDTO with active_invites & pending_join_requests
        let member = HouseholdMemberDTO(householdId: householdId, userId: ownerId, role: .owner, displayName: "Brian")
        let household = HouseholdDTO(
            id: householdId,
            name: "Phan Family",
            inviteCode: nil,
            inviteExpiresAt: nil,
            createdBy: ownerId,
            createdAt: now,
            role: .owner,
            members: [member],
            activeInvites: [activeInvite],
            pendingJoinRequests: [pendingRequest]
        )
        let householdData = try encoder.encode(household)
        let householdJSON = try #require(String(data: householdData, encoding: .utf8))
        #expect(householdJSON.contains("\"active_invites\""))
        #expect(householdJSON.contains("\"pending_join_requests\""))
        #expect(try decoder.decode(HouseholdDTO.self, from: householdData) == household)

        // JoinHouseholdResponse (pending + approved)
        let pendingJoinResponse = JoinHouseholdResponse(
            status: .pending,
            household: nil,
            joinRequest: pendingRequest
        )
        let pendingJoinData = try encoder.encode(pendingJoinResponse)
        let pendingJoinJSON = try #require(String(data: pendingJoinData, encoding: .utf8))
        #expect(pendingJoinJSON.contains("\"status\":\"pending\""))
        #expect(pendingJoinJSON.contains("\"join_request\""))
        #expect(try decoder.decode(JoinHouseholdResponse.self, from: pendingJoinData) == pendingJoinResponse)

        let approvedJoinResponse = JoinHouseholdResponse(
            status: .approved,
            household: household,
            joinRequest: nil
        )
        let approvedJoinData = try encoder.encode(approvedJoinResponse)
        #expect(try decoder.decode(JoinHouseholdResponse.self, from: approvedJoinData) == approvedJoinResponse)

        // AuthSessionResponse with pending_join_requests
        let grandmaUser = UserDTO(id: grandmaId, displayName: "Grandma", primaryEmail: nil, createdAt: now)
        let sessionWithPending = AuthSessionResponse(
            accessToken: "jwt-access-grandma",
            expiresIn: 900,
            refreshToken: "opaque-refresh-grandma",
            user: grandmaUser,
            households: [],
            pendingJoinRequests: [pendingRequest]
        )
        let sessionData = try encoder.encode(sessionWithPending)
        let sessionJSON = try #require(String(data: sessionData, encoding: .utf8))
        #expect(sessionJSON.contains("\"pending_join_requests\""))
        #expect(try decoder.decode(AuthSessionResponse.self, from: sessionData) == sessionWithPending)
    }

    @Test("Legacy HouseholdDTO and AuthSessionResponse JSON omitting new invite/join-request keys decode cleanly")
    func legacyHouseholdAndAuthSessionBackwardCompatibility() throws {
        let userId = UUID()
        let householdId = UUID()

        let legacyHouseholdJSON = """
        {
          "id": "\(householdId.uuidString)",
          "name": "Phan Family",
          "invite_code": "482910",
          "invite_expires_at": "2026-11-26T22:00:00Z",
          "created_by": "\(userId.uuidString)",
          "created_at": "2026-11-25T22:00:00Z",
          "role": "owner",
          "members": [
            {
              "household_id": "\(householdId.uuidString)",
              "user_id": "\(userId.uuidString)",
              "role": "owner",
              "display_name": "Brian"
            }
          ]
        }
        """
        let decodedHousehold = try decoder.decode(HouseholdDTO.self, from: Data(legacyHouseholdJSON.utf8))
        #expect(decodedHousehold.id == householdId)
        #expect(decodedHousehold.name == "Phan Family")
        #expect(decodedHousehold.inviteCode == "482910")
        #expect(decodedHousehold.activeInvites == nil)
        #expect(decodedHousehold.pendingJoinRequests == nil)

        let legacyAuthSessionJSON = """
        {
          "access_token": "jwt-legacy",
          "expires_in": 900,
          "refresh_token": "opaque-legacy",
          "user": {
            "id": "\(userId.uuidString)",
            "display_name": "Brian",
            "primary_email": "brian@example.com",
            "created_at": "2026-11-25T22:00:00Z"
          },
          "households": [
            \(legacyHouseholdJSON)
          ]
        }
        """
        let decodedSession = try decoder.decode(AuthSessionResponse.self, from: Data(legacyAuthSessionJSON.utf8))
        #expect(decodedSession.accessToken == "jwt-legacy")
        #expect(decodedSession.households.count == 1)
        #expect(decodedSession.households.first?.activeInvites == nil)
        #expect(decodedSession.households.first?.pendingJoinRequests == nil)
        #expect(decodedSession.pendingJoinRequests == nil)
    }
}

@Suite("UnitConversion")
struct UnitConversionTests {
    @Test("oz <-> mL conversions match README and preserve 2-decimal oz round-trips")
    func ozMlConversions() {
        #expect(UnitConversion.ozToMl(3.0) == 88.7)
        #expect(UnitConversion.ozToMl(2.5) == 73.9)
        #expect(UnitConversion.ozToMl(3.25) == 96.1)
        #expect(UnitConversion.ozToMl(0.0) == 0.0)

        #expect(UnitConversion.mlToOz(88.7) == 3.0)
        #expect(UnitConversion.mlToOz(85.0) == 2.87)

        for sampleOz in [0.25, 0.5, 1.0, 2.5, 3.0, 3.25, 4.7, 4.75, 6.15] {
            let ml = UnitConversion.ozToMl(sampleOz)
            #expect(UnitConversion.mlToOz(ml) == sampleOz)
        }
    }

    @Test("parseFlexibleNumber handles decimals, Unicode fractions, ASCII fractions, and units")
    func parseFlexibleNumberValidInputs() {
        // Arbitrary decimals
        #expect(UnitConversion.parseFlexibleNumber("3.25") == 3.25)
        #expect(UnitConversion.parseFlexibleNumber("4.7") == 4.7)
        #expect(UnitConversion.parseFlexibleNumber("85") == 85.0)
        #expect(UnitConversion.parseFlexibleNumber(".5") == 0.5)
        #expect(UnitConversion.parseFlexibleNumber("0.75") == 0.75)

        // Unicode fractions
        #expect(UnitConversion.parseFlexibleNumber("2½") == 2.5)
        #expect(UnitConversion.parseFlexibleNumber("2 ½") == 2.5)
        #expect(UnitConversion.parseFlexibleNumber("3¼") == 3.25)
        #expect(UnitConversion.parseFlexibleNumber("4¾") == 4.75)
        #expect(UnitConversion.parseFlexibleNumber("½") == 0.5)
        #expect(UnitConversion.parseFlexibleNumber("¼") == 0.25)
        #expect(UnitConversion.parseFlexibleNumber("¾") == 0.75)

        // ASCII fractions & mixed fractions
        #expect(UnitConversion.parseFlexibleNumber("1/2") == 0.5)
        #expect(UnitConversion.parseFlexibleNumber("3/4") == 0.75)
        #expect(UnitConversion.parseFlexibleNumber("2 1/2") == 2.5)
        #expect(UnitConversion.parseFlexibleNumber("3 1/4") == 3.25)
        #expect(UnitConversion.parseFlexibleNumber("4 3/4") == 4.75)
        #expect(UnitConversion.parseFlexibleNumber("2-1/2") == 2.5)

        // Optional unit suffixes
        #expect(UnitConversion.parseFlexibleNumber("2½ oz") == 2.5)
        #expect(UnitConversion.parseFlexibleNumber("3¼ oz.") == 3.25)
        #expect(UnitConversion.parseFlexibleNumber("2 1/2 fl. oz.") == 2.5)
        #expect(UnitConversion.parseFlexibleNumber("85 mL") == 85.0)
        #expect(UnitConversion.parseFlexibleNumber("85mL") == 85.0)
        #expect(UnitConversion.parseFlexibleNumber("2.5 mL") == 2.5)
        #expect(UnitConversion.parseFlexibleNumber("1 drops") == 1.0)
    }

    @Test("parseFlexibleNumber rejects empty strings, invalid text, zero denominators, and target ranges")
    func parseFlexibleNumberInvalidInputs() {
        #expect(UnitConversion.parseFlexibleNumber("") == nil)
        #expect(UnitConversion.parseFlexibleNumber("   ") == nil)
        #expect(UnitConversion.parseFlexibleNumber("oz") == nil)
        #expect(UnitConversion.parseFlexibleNumber("2-4 oz") == nil)
        #expect(UnitConversion.parseFlexibleNumber("2–4 oz") == nil)
        #expect(UnitConversion.parseFlexibleNumber("1/0") == nil)
        #expect(UnitConversion.parseFlexibleNumber("2 1/0") == nil)
        #expect(UnitConversion.parseFlexibleNumber("NaN") == nil)
        #expect(UnitConversion.parseFlexibleNumber("abc") == nil)
        #expect(UnitConversion.parseFlexibleNumber("3.2.1") == nil)
    }

    @Test("parseVolumeAmount extracts both value and volume unit")
    func parseVolumeAmount() throws {
        let oz = try #require(UnitConversion.parseVolumeAmount("2½ oz"))
        #expect(oz.value == 2.5)
        #expect(oz.unit == .oz)

        let ml = try #require(UnitConversion.parseVolumeAmount("85 mL"))
        #expect(ml.value == 85.0)
        #expect(ml.unit == .ml)

        let unitless = try #require(UnitConversion.parseVolumeAmount("3.25"))
        #expect(unitless.value == 3.25)
        #expect(unitless.unit == nil)
    }
}

@Suite("WakeWindowCalculator")
struct WakeWindowCalculatorTests {
    private var pacificCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return cal
    }

    private func localTime(_ hour: Int, _ minute: Int, day: Int = 25) -> Date {
        let components = DateComponents(
            timeZone: TimeZone(identifier: "America/Los_Angeles"),
            year: 2026,
            month: 11,
            day: day,
            hour: hour,
            minute: minute
        )
        return pacificCalendar.date(from: components)!
    }

    private func makeNap(start: Date, end: Date, deletedAt: Date? = nil) -> EventDTO {
        let id = UUID()
        return EventDTO(
            id: id,
            profileId: UUID(),
            eventType: .sleep,
            startedAt: start,
            endedAt: end,
            timezone: "America/Los_Angeles",
            metadata: .sleep(SleepMetadata(sleepType: .nap, location: .crib)),
            source: .manual,
            createdBy: UUID(),
            updatedBy: UUID(),
            createdAt: start,
            updatedAt: end,
            deletedAt: deletedAt
        )
    }

    @Test("Nov 18 flat schedule ([180, 180]) predicts 3h before Nap 1 and 3h before Nap 2")
    func nov18FlatSchedule() throws {
        let config = ScheduleConfig(wakeWindowsMinutes: [180, 180])
        let wake = localTime(7, 0, day: 18)

        let nap1Prediction = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(9, 0, day: 18),
                wakeUpTime: wake,
                completedNapsToday: [],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(nap1Prediction.wakeWindowMinutes == 180)
        #expect(nap1Prediction.recommendedStart == localTime(10, 0, day: 18))
        #expect(nap1Prediction.windowStart == localTime(9, 45, day: 18))
        #expect(nap1Prediction.windowEnd == localTime(10, 15, day: 18))
        #expect(nap1Prediction.maxNapEnd == localTime(11, 30, day: 18))
        #expect(nap1Prediction.isBackupCatnap == false)

        let completedNap1 = makeNap(start: localTime(10, 0, day: 18), end: localTime(11, 30, day: 18))
        let nap2Prediction = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(12, 0, day: 18),
                wakeUpTime: wake,
                completedNapsToday: [completedNap1],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(nap2Prediction.wakeWindowMinutes == 180)
        #expect(nap2Prediction.recommendedStart == localTime(14, 30, day: 18))
        #expect(nap2Prediction.maxNapEnd == localTime(16, 0, day: 18))
        #expect(nap2Prediction.isBackupCatnap == false)
    }

    @Test("Nov 25 asymmetric schedule ([150, 195]) predicts 2h30m before Nap 1 and 3h15m before Nap 2")
    func nov25AsymmetricSchedule() throws {
        let config = ScheduleConfig(wakeWindowsMinutes: [150, 195])
        let wake = localTime(7, 0)

        let nap1Prediction = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(8, 30),
                wakeUpTime: wake,
                completedNapsToday: [],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(nap1Prediction.wakeWindowMinutes == 150)
        #expect(nap1Prediction.recommendedStart == localTime(9, 30))
        #expect(nap1Prediction.maxNapEnd == localTime(11, 0))
        #expect(nap1Prediction.isBackupCatnap == false)

        let completedNap1 = makeNap(start: localTime(9, 30), end: localTime(11, 0))
        let nap2Prediction = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(12, 30),
                wakeUpTime: wake,
                completedNapsToday: [completedNap1],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(nap2Prediction.wakeWindowMinutes == 195)
        #expect(nap2Prediction.recommendedStart == localTime(14, 15))
        #expect(nap2Prediction.windowStart == localTime(14, 0))
        #expect(nap2Prediction.windowEnd == localTime(14, 30))
        #expect(nap2Prediction.maxNapEnd == localTime(15, 45))
        #expect(nap2Prediction.isBackupCatnap == false)
    }

    @Test("Short nap (<45m) resets next wake window to shortNapNextWindowMinutes (150m)")
    func shortNapResetRule() throws {
        let config = ScheduleConfig(wakeWindowsMinutes: [150, 195])
        let wake = localTime(7, 0)

        // 35-minute short Nap 1 (9:30 - 10:05) -> should reset Nap 2 wake window from 195m to 150m
        let shortNap1 = makeNap(start: localTime(9, 30), end: localTime(10, 5))
        let prediction = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(10, 30),
                wakeUpTime: wake,
                completedNapsToday: [shortNap1],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(prediction.wakeWindowMinutes == 150)
        #expect(prediction.recommendedStart == localTime(12, 35))
        #expect(prediction.maxNapEnd == localTime(14, 5))
        #expect(prediction.isBackupCatnap == false)

        // Exactly 45-minute nap does NOT trigger short-nap reset
        let thresholdNap1 = makeNap(start: localTime(9, 30), end: localTime(10, 15))
        let normalPrediction = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(10, 30),
                wakeUpTime: wake,
                completedNapsToday: [thresholdNap1],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(normalPrediction.wakeWindowMinutes == 195)
        #expect(normalPrediction.recommendedStart == localTime(13, 30))
    }

    @Test("Backup catnap triggers before 5:00 PM cutoff and returns nil past cutoff or after 3rd nap")
    func backupCatnapCutoffRule() throws {
        let config = ScheduleConfig(wakeWindowsMinutes: [150, 195])
        let wake = localTime(7, 0)

        // Scenario 1: Early Nap 2 ends at 1:35 PM -> +195m = 4:50 PM (<= 5:00 PM cutoff) -> 25m backup catnap!
        let shortNap1 = makeNap(start: localTime(9, 30), end: localTime(10, 5))
        let earlyNap2 = makeNap(start: localTime(12, 35), end: localTime(13, 35))
        let catnapPrediction = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(14, 0),
                wakeUpTime: wake,
                completedNapsToday: [shortNap1, earlyNap2],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(catnapPrediction.isBackupCatnap == true)
        #expect(catnapPrediction.wakeWindowMinutes == 195)
        #expect(catnapPrediction.recommendedStart == localTime(16, 50))
        #expect(catnapPrediction.maxNapEnd == localTime(17, 15))

        // Scenario 1b: Same naps, but `asOf` is already past 5:00 PM cutoff -> nil
        let pastCutoffAsOf = WakeWindowCalculator.predictNextNap(
            asOf: localTime(17, 5),
            wakeUpTime: wake,
            completedNapsToday: [shortNap1, earlyNap2],
            config: config,
            calendar: pacificCalendar
        )
        #expect(pastCutoffAsOf == nil)

        // Scenario 2: Short Nap 2 ends at 1:10 PM (35m) -> short-nap reset 150m -> 3:40 PM backup catnap
        let shortNap2 = makeNap(start: localTime(12, 35), end: localTime(13, 10))
        let shortNapCatnap = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(13, 30),
                wakeUpTime: wake,
                completedNapsToday: [shortNap1, shortNap2],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(shortNapCatnap.isBackupCatnap == true)
        #expect(shortNapCatnap.wakeWindowMinutes == 150)
        #expect(shortNapCatnap.recommendedStart == localTime(15, 40))
        #expect(shortNapCatnap.maxNapEnd == localTime(16, 5))

        // Scenario 3: Normal Nap 2 ends at 3:30 PM -> +195m = 6:45 PM (> 5:00 PM cutoff) -> nil (bedtime next)
        let normalNap1 = makeNap(start: localTime(9, 30), end: localTime(11, 0))
        let normalNap2 = makeNap(start: localTime(14, 15), end: localTime(15, 30))
        let noCatnap = WakeWindowCalculator.predictNextNap(
            asOf: localTime(16, 0),
            wakeUpTime: wake,
            completedNapsToday: [normalNap1, normalNap2],
            config: config,
            calendar: pacificCalendar
        )
        #expect(noCatnap == nil)

        // Scenario 4: Backup catnap already taken (3 naps on a 2-nap schedule) -> nil
        let catnapDone = makeNap(start: localTime(15, 40), end: localTime(16, 5))
        let allDone = WakeWindowCalculator.predictNextNap(
            asOf: localTime(16, 15),
            wakeUpTime: wake,
            completedNapsToday: [shortNap1, shortNap2, catnapDone],
            config: config,
            calendar: pacificCalendar
        )
        #expect(allDone == nil)
    }

    @Test("Ignores deleted naps, night sleep, and returns nil without wake anchor")
    func filtersNonNapAndDeletedEvents() throws {
        let config = ScheduleConfig(wakeWindowsMinutes: [150, 195])
        let wake = localTime(7, 0)

        let deletedNap = makeNap(
            start: localTime(9, 30),
            end: localTime(11, 0),
            deletedAt: localTime(11, 5)
        )
        let nightSleep = EventDTO(
            profileId: UUID(),
            eventType: .sleep,
            startedAt: localTime(0, 0),
            endedAt: wake,
            timezone: "America/Los_Angeles",
            metadata: .sleep(SleepMetadata(sleepType: .night, location: .crib)),
            source: .manual,
            createdBy: UUID(),
            updatedBy: UUID(),
            createdAt: wake,
            updatedAt: wake
        )

        let prediction = try #require(
            predictNextNap(
                asOf: localTime(8, 0),
                wakeUpTime: wake,
                completedNapsToday: [deletedNap, nightSleep],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(prediction.wakeWindowMinutes == 150)
        #expect(prediction.recommendedStart == localTime(9, 30))

        // Nil wakeUpTime + no completed naps -> nil
        let noAnchor = WakeWindowCalculator.predictNextNap(
            asOf: localTime(8, 0),
            wakeUpTime: nil,
            completedNapsToday: [],
            config: config,
            calendar: pacificCalendar
        )
        #expect(noAnchor == nil)
    }

    @Test("1-nap schedule ([300]) predicts Nap 1, normal bedtime, short-nap backup catnap, and stops after catnap")
    func oneNapScheduleTransitions() throws {
        let config = ScheduleConfig(wakeWindowsMinutes: ScheduleConfig.defaultWakeWindows(forNapCount: 1))
        #expect(config.wakeWindowsMinutes == [300])
        let wake = localTime(7, 0)

        // Nap 1: 7:00 AM + 5h = 12:00 PM
        let nap1Prediction = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(10, 0),
                wakeUpTime: wake,
                completedNapsToday: [],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(nap1Prediction.wakeWindowMinutes == 300)
        #expect(nap1Prediction.recommendedStart == localTime(12, 0))
        #expect(nap1Prediction.windowStart == localTime(11, 45))
        #expect(nap1Prediction.windowEnd == localTime(12, 15))
        #expect(nap1Prediction.maxNapEnd == localTime(13, 30))
        #expect(nap1Prediction.isBackupCatnap == false)

        // Normal Nap 1 (12:00 - 13:30, 90m) -> +5h = 18:30 (> 17:00 cutoff) -> nil (bedtime next)
        let normalNap1 = makeNap(start: localTime(12, 0), end: localTime(13, 30))
        let afterNormalNap1 = WakeWindowCalculator.predictNextNap(
            asOf: localTime(14, 0),
            wakeUpTime: wake,
            completedNapsToday: [normalNap1],
            config: config,
            calendar: pacificCalendar
        )
        #expect(afterNormalNap1 == nil)

        // Short Nap 1 (11:30 - 12:05, 35m < 45m) -> resets wake window to 150m -> 2:35 PM backup catnap (<= 5:00 PM)
        let shortNap1 = makeNap(start: localTime(11, 30), end: localTime(12, 5))
        let backupCatnap = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(13, 0),
                wakeUpTime: wake,
                completedNapsToday: [shortNap1],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(backupCatnap.isBackupCatnap == true)
        #expect(backupCatnap.wakeWindowMinutes == 150)
        #expect(backupCatnap.recommendedStart == localTime(14, 35))
        #expect(backupCatnap.maxNapEnd == localTime(15, 0))

        // After backup catnap taken (2 naps on 1-nap schedule) -> nil
        let catnapDone = makeNap(start: localTime(14, 35), end: localTime(15, 0))
        let afterCatnap = WakeWindowCalculator.predictNextNap(
            asOf: localTime(15, 15),
            wakeUpTime: wake,
            completedNapsToday: [shortNap1, catnapDone],
            config: config,
            calendar: pacificCalendar
        )
        #expect(afterCatnap == nil)
    }

    @Test("3-nap schedule ([105, 135, 150]) predicts Naps 1-3, backup catnap before cutoff, and bedtime after")
    func threeNapScheduleTransitions() throws {
        let config = ScheduleConfig(wakeWindowsMinutes: ScheduleConfig.defaultWakeWindows(forNapCount: 3))
        #expect(config.wakeWindowsMinutes == [105, 135, 150])
        let wake = localTime(7, 0)

        // Nap 1: 7:00 AM + 105m = 8:45 AM
        let nap1Prediction = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(8, 0),
                wakeUpTime: wake,
                completedNapsToday: [],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(nap1Prediction.wakeWindowMinutes == 105)
        #expect(nap1Prediction.recommendedStart == localTime(8, 45))
        #expect(nap1Prediction.windowStart == localTime(8, 30))
        #expect(nap1Prediction.windowEnd == localTime(9, 0))
        #expect(nap1Prediction.maxNapEnd == localTime(10, 15))
        #expect(nap1Prediction.isBackupCatnap == false)

        // Nap 2 after Nap 1 (8:45 - 9:45, 60m): 9:45 AM + 135m = 12:00 PM
        let nap1 = makeNap(start: localTime(8, 45), end: localTime(9, 45))
        let nap2Prediction = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(10, 30),
                wakeUpTime: wake,
                completedNapsToday: [nap1],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(nap2Prediction.wakeWindowMinutes == 135)
        #expect(nap2Prediction.recommendedStart == localTime(12, 0))
        #expect(nap2Prediction.maxNapEnd == localTime(13, 30))
        #expect(nap2Prediction.isBackupCatnap == false)

        // Nap 3 after Nap 2 (12:00 - 13:00, 60m): 1:00 PM + 150m = 3:30 PM
        let nap2 = makeNap(start: localTime(12, 0), end: localTime(13, 0))
        let nap3Prediction = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(14, 0),
                wakeUpTime: wake,
                completedNapsToday: [nap1, nap2],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(nap3Prediction.wakeWindowMinutes == 150)
        #expect(nap3Prediction.recommendedStart == localTime(15, 30))
        #expect(nap3Prediction.maxNapEnd == localTime(17, 0))
        #expect(nap3Prediction.isBackupCatnap == false)

        // Normal Nap 3 (15:30 - 16:15, 45m): 4:15 PM + 150m = 6:45 PM (> 5:00 PM cutoff) -> nil
        let nap3 = makeNap(start: localTime(15, 30), end: localTime(16, 15))
        let afterNormalNap3 = WakeWindowCalculator.predictNextNap(
            asOf: localTime(16, 30),
            wakeUpTime: wake,
            completedNapsToday: [nap1, nap2, nap3],
            config: config,
            calendar: pacificCalendar
        )
        #expect(afterNormalNap3 == nil)

        // Early 3-nap day ending at 2:00 PM -> backup catnap at 4:30 PM (<= 5:00 PM cutoff, 25m cap)
        let earlyNap1 = makeNap(start: localTime(8, 0), end: localTime(8, 45))
        let earlyNap2 = makeNap(start: localTime(10, 30), end: localTime(11, 15))
        let earlyNap3 = makeNap(start: localTime(13, 15), end: localTime(14, 0))
        let backupCatnap = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(14, 30),
                wakeUpTime: wake,
                completedNapsToday: [earlyNap1, earlyNap2, earlyNap3],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(backupCatnap.isBackupCatnap == true)
        #expect(backupCatnap.wakeWindowMinutes == 150)
        #expect(backupCatnap.recommendedStart == localTime(16, 30))
        #expect(backupCatnap.maxNapEnd == localTime(16, 55))

        // After 4th nap (backup catnap taken) -> nil
        let catnapDone = makeNap(start: localTime(16, 30), end: localTime(16, 55))
        let afterCatnap = WakeWindowCalculator.predictNextNap(
            asOf: localTime(17, 0),
            wakeUpTime: wake,
            completedNapsToday: [earlyNap1, earlyNap2, earlyNap3, catnapDone],
            config: config,
            calendar: pacificCalendar
        )
        #expect(afterCatnap == nil)
    }

    @Test("4-nap schedule ([75, 90, 90, 105]) predicts Naps 1-4, backup catnap before cutoff, and bedtime after")
    func fourNapScheduleTransitions() throws {
        let config = ScheduleConfig(wakeWindowsMinutes: ScheduleConfig.defaultWakeWindows(forNapCount: 4))
        #expect(config.wakeWindowsMinutes == [75, 90, 90, 105])
        let wake = localTime(6, 30)

        // Nap 1: 6:30 AM + 75m = 7:45 AM
        let nap1Prediction = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(7, 0),
                wakeUpTime: wake,
                completedNapsToday: [],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(nap1Prediction.wakeWindowMinutes == 75)
        #expect(nap1Prediction.recommendedStart == localTime(7, 45))
        #expect(nap1Prediction.windowStart == localTime(7, 30))
        #expect(nap1Prediction.windowEnd == localTime(8, 0))
        #expect(nap1Prediction.maxNapEnd == localTime(9, 15))
        #expect(nap1Prediction.isBackupCatnap == false)

        // Nap 2 after Nap 1 (7:45 - 8:45, 60m): 8:45 AM + 90m = 10:15 AM
        let nap1 = makeNap(start: localTime(7, 45), end: localTime(8, 45))
        let nap2Prediction = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(9, 15),
                wakeUpTime: wake,
                completedNapsToday: [nap1],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(nap2Prediction.wakeWindowMinutes == 90)
        #expect(nap2Prediction.recommendedStart == localTime(10, 15))
        #expect(nap2Prediction.maxNapEnd == localTime(11, 45))
        #expect(nap2Prediction.isBackupCatnap == false)

        // Nap 3 after Nap 2 (10:15 - 11:15, 60m): 11:15 AM + 90m = 12:45 PM
        let nap2 = makeNap(start: localTime(10, 15), end: localTime(11, 15))
        let nap3Prediction = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(11, 45),
                wakeUpTime: wake,
                completedNapsToday: [nap1, nap2],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(nap3Prediction.wakeWindowMinutes == 90)
        #expect(nap3Prediction.recommendedStart == localTime(12, 45))
        #expect(nap3Prediction.maxNapEnd == localTime(14, 15))
        #expect(nap3Prediction.isBackupCatnap == false)

        // Nap 4 after Nap 3 (12:45 - 13:45, 60m): 1:45 PM + 105m = 3:30 PM
        let nap3 = makeNap(start: localTime(12, 45), end: localTime(13, 45))
        let nap4Prediction = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(14, 30),
                wakeUpTime: wake,
                completedNapsToday: [nap1, nap2, nap3],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(nap4Prediction.wakeWindowMinutes == 105)
        #expect(nap4Prediction.recommendedStart == localTime(15, 30))
        #expect(nap4Prediction.maxNapEnd == localTime(17, 0))
        #expect(nap4Prediction.isBackupCatnap == false)

        // Normal Nap 4 (15:30 - 16:15, 45m): 4:15 PM + 105m = 6:00 PM (> 5:00 PM cutoff) -> nil
        let nap4 = makeNap(start: localTime(15, 30), end: localTime(16, 15))
        let afterNormalNap4 = WakeWindowCalculator.predictNextNap(
            asOf: localTime(16, 30),
            wakeUpTime: wake,
            completedNapsToday: [nap1, nap2, nap3, nap4],
            config: config,
            calendar: pacificCalendar
        )
        #expect(afterNormalNap4 == nil)

        // Early 4-nap day ending at 2:15 PM -> backup catnap at 4:00 PM (+105m <= 5:00 PM cutoff, 25m cap)
        let earlyNap1 = makeNap(start: localTime(7, 30), end: localTime(8, 15))
        let earlyNap2 = makeNap(start: localTime(9, 30), end: localTime(10, 15))
        let earlyNap3 = makeNap(start: localTime(11, 30), end: localTime(12, 15))
        let earlyNap4 = makeNap(start: localTime(13, 30), end: localTime(14, 15))
        let backupCatnap = try #require(
            WakeWindowCalculator.predictNextNap(
                asOf: localTime(14, 45),
                wakeUpTime: wake,
                completedNapsToday: [earlyNap1, earlyNap2, earlyNap3, earlyNap4],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(backupCatnap.isBackupCatnap == true)
        #expect(backupCatnap.wakeWindowMinutes == 105)
        #expect(backupCatnap.recommendedStart == localTime(16, 0))
        #expect(backupCatnap.maxNapEnd == localTime(16, 25))

        // After 5th nap (backup catnap taken) -> nil
        let catnapDone = makeNap(start: localTime(16, 0), end: localTime(16, 25))
        let afterCatnap = WakeWindowCalculator.predictNextNap(
            asOf: localTime(16, 30),
            wakeUpTime: wake,
            completedNapsToday: [earlyNap1, earlyNap2, earlyNap3, earlyNap4, catnapDone],
            config: config,
            calendar: pacificCalendar
        )
        #expect(afterCatnap == nil)
    }

    @Test("SleepClassifier classifies daytime, twilight, clearly-night, duration guard, overnight, and switch-to-night suggestion")
    func sleepClassifierComprehensiveRules() {
        let config = ScheduleConfig() // targetBedtime = 7:30 PM (1170) -> twilight 5:15 PM (1035), night 6:45 PM (1125)

        // Zone boundaries
        #expect(SleepClassifier.zone(for: localTime(5, 59), config: config, calendar: pacificCalendar) == .night)
        #expect(SleepClassifier.zone(for: localTime(6, 0), config: config, calendar: pacificCalendar) == .daytime)
        #expect(SleepClassifier.zone(for: localTime(17, 14), config: config, calendar: pacificCalendar) == .daytime)
        #expect(SleepClassifier.zone(for: localTime(17, 15), config: config, calendar: pacificCalendar) == .twilight)
        #expect(SleepClassifier.zone(for: localTime(18, 44), config: config, calendar: pacificCalendar) == .twilight)
        #expect(SleepClassifier.zone(for: localTime(18, 45), config: config, calendar: pacificCalendar) == .night)
        #expect(SleepClassifier.zone(for: localTime(20, 0), config: config, calendar: pacificCalendar) == .night)
        #expect(SleepClassifier.zone(for: localTime(2, 0), config: config, calendar: pacificCalendar) == .night)

        let nap1 = makeNap(start: localTime(9, 30), end: localTime(11, 0))
        let nap2 = makeNap(start: localTime(13, 30), end: localTime(14, 45))

        // Zone 1 (clearly night at 7:00 PM - 8:00 PM): ALWAYS .night even with 0 or 1 naps!
        #expect(
            SleepClassifier.classify(
                start: localTime(19, 0),
                completedNapsToday: [],
                lastWakeAt: localTime(18, 0),
                config: config,
                calendar: pacificCalendar
            ) == .night
        )
        #expect(
            SleepClassifier.classify(
                start: localTime(20, 0),
                completedNapsToday: [nap1],
                lastWakeAt: localTime(18, 30),
                config: config,
                calendar: pacificCalendar
            ) == .night
        )

        // Zone 2 (daytime): .nap
        #expect(
            SleepClassifier.classify(
                start: localTime(10, 0),
                completedNapsToday: [],
                lastWakeAt: localTime(7, 0),
                config: config,
                calendar: pacificCalendar
            ) == .nap
        )
        #expect(
            SleepClassifier.classify(
                start: localTime(16, 40),
                completedNapsToday: [nap1, nap2],
                lastWakeAt: localTime(14, 45),
                config: config,
                calendar: pacificCalendar
            ) == .nap
        )

        // Zone 3 (twilight): past backup catnap cutoff (5:00 PM) -> .night
        #expect(
            SleepClassifier.classify(
                start: localTime(17, 30),
                completedNapsToday: [],
                lastWakeAt: localTime(16, 30),
                config: config,
                calendar: pacificCalendar
            ) == .night
        )

        // Zone 3 (twilight) BEFORE cutoff: test using earlier target bedtime (6:30 PM -> twilight starts 4:15 PM, cutoff 5:00 PM)
        let earlyBedtimeConfig = ScheduleConfig(
            wakeWindowsMinutes: [150, 195],
            backupCatnapCutoffMinutesFromMidnight: 1020, // 5:00 PM
            targetBedtimeMinutesFromMidnight: 1110, // 6:30 PM -> twilight 4:15 PM, night 5:45 PM
            bedtimeWakeWindowMinutes: 225 // 3h45m -> threshold = 195m (3h15m)
        )
        #expect(SleepClassifier.zone(for: localTime(16, 30), config: earlyBedtimeConfig, calendar: pacificCalendar) == .twilight)

        // Twilight before cutoff, < 2 naps, short wake stretch (2h < 3h15m) -> .nap
        #expect(
            SleepClassifier.classify(
                start: localTime(16, 30),
                completedNapsToday: [nap1],
                lastWakeAt: localTime(14, 30),
                config: earlyBedtimeConfig,
                calendar: pacificCalendar
            ) == .nap
        )

        // Twilight before cutoff, 2 naps already done (nap quota met) -> .night
        #expect(
            SleepClassifier.classify(
                start: localTime(16, 30),
                completedNapsToday: [nap1, nap2],
                lastWakeAt: localTime(14, 45),
                config: earlyBedtimeConfig,
                calendar: pacificCalendar
            ) == .night
        )

        // Deleted or yesterday's nap does NOT count toward twilight nap quota
        let deletedNap2 = makeNap(start: localTime(13, 30), end: localTime(14, 45), deletedAt: localTime(15, 0))
        let yesterdayNap = makeNap(start: localTime(13, 30, day: 24), end: localTime(14, 45, day: 24))
        #expect(
            SleepClassifier.classify(
                start: localTime(16, 30),
                completedNapsToday: [nap1, deletedNap2, yesterdayNap],
                lastWakeAt: localTime(14, 30),
                config: earlyBedtimeConfig,
                calendar: pacificCalendar
            ) == .nap
        )

        // Twilight before cutoff, 1 nap done, long wake stretch (>= 225 - 30 = 195m) -> .night
        #expect(
            SleepClassifier.classify(
                start: localTime(16, 30),
                completedNapsToday: [nap1],
                lastWakeAt: localTime(13, 15), // exactly 195m (3h15m) awake
                config: earlyBedtimeConfig,
                calendar: pacificCalendar
            ) == .night
        )

        // Duration guard: >= 3.5h (210m) even in daytime -> .night
        #expect(
            SleepClassifier.classify(
                start: localTime(10, 0),
                end: localTime(13, 30), // exactly 210m
                config: config,
                calendar: pacificCalendar
            ) == .night
        )
        #expect(
            SleepClassifier.classify(
                start: localTime(10, 0),
                end: localTime(13, 29), // 209m < 210m
                config: config,
                calendar: pacificCalendar
            ) == .nap
        )

        // Duration guard: crossing midnight (even < 3.5h) -> .night
        #expect(
            SleepClassifier.classify(
                start: localTime(23, 0, day: 25),
                end: localTime(0, 30, day: 26),
                config: config,
                calendar: pacificCalendar
            ) == .night
        )
        // Daytime start crossing midnight (edge case) -> .night
        #expect(
            SleepClassifier.classify(
                start: localTime(16, 0, day: 25),
                end: localTime(0, 10, day: 26),
                config: config,
                calendar: pacificCalendar
            ) == .night
        )

        // shouldSuggestSwitchToNight (default napCap = 90m -> threshold = 150m = 2h 30m, earliest start = 4:30 PM)
        #expect(
            SleepClassifier.shouldSuggestSwitchToNight(
                startedAt: localTime(16, 45),
                asOf: localTime(19, 20), // 2h 35m
                sleepType: .nap,
                config: config,
                calendar: pacificCalendar
            ) == true
        )
        #expect(
            SleepClassifier.shouldSuggestSwitchToNight(
                startedAt: localTime(16, 30),
                asOf: localTime(19, 0), // exactly 2h 30m at 4:30 PM boundary
                sleepType: .nap,
                config: config,
                calendar: pacificCalendar
            ) == true
        )
        #expect(
            SleepClassifier.shouldSuggestSwitchToNight(
                startedAt: localTime(10, 0),
                asOf: localTime(12, 35), // 2h 35m morning nap -> false
                sleepType: .nap,
                config: config,
                calendar: pacificCalendar
            ) == false
        )
        #expect(
            SleepClassifier.shouldSuggestSwitchToNight(
                startedAt: localTime(16, 29),
                asOf: localTime(19, 30), // started before 4:30 PM -> false
                sleepType: .nap,
                config: config,
                calendar: pacificCalendar
            ) == false
        )
        #expect(
            SleepClassifier.shouldSuggestSwitchToNight(
                startedAt: localTime(17, 0),
                asOf: localTime(18, 0), // only 1h -> false
                sleepType: .nap,
                config: config,
                calendar: pacificCalendar
            ) == false
        )
        #expect(
            SleepClassifier.shouldSuggestSwitchToNight(
                startedAt: localTime(16, 45),
                asOf: localTime(19, 20),
                sleepType: .night, // already night -> false
                config: config,
                calendar: pacificCalendar
            ) == false
        )
    }

    @Test("isWithinNightSleepWindow checks evening/overnight boundaries and suppresses evening/twilight nap predictions")
    func nightSleepWindowAndEveningSuppression() {
        let config = ScheduleConfig() // targetBedtime = 1170 (7:30 PM) -> nightStart = 1125 (6:45 PM), nightEnd = 360 (6:00 AM)

        #expect(WakeWindowCalculator.isWithinNightSleepWindow(localTime(18, 44), config: config, calendar: pacificCalendar) == false)
        #expect(WakeWindowCalculator.isWithinNightSleepWindow(localTime(18, 45), config: config, calendar: pacificCalendar) == true)
        #expect(WakeWindowCalculator.isWithinNightSleepWindow(localTime(19, 30), config: config, calendar: pacificCalendar) == true)
        #expect(WakeWindowCalculator.isWithinNightSleepWindow(localTime(2, 0), config: config, calendar: pacificCalendar) == true)
        #expect(WakeWindowCalculator.isWithinNightSleepWindow(localTime(5, 59), config: config, calendar: pacificCalendar) == true)
        #expect(WakeWindowCalculator.isWithinNightSleepWindow(localTime(6, 0), config: config, calendar: pacificCalendar) == false)

        // Custom earlier target bedtime (6:30 PM -> clearly night starts at 5:45 PM)
        let earlyBedtimeConfig = ScheduleConfig(targetBedtimeMinutesFromMidnight: 1110)
        #expect(WakeWindowCalculator.isWithinNightSleepWindow(localTime(17, 44), config: earlyBedtimeConfig, calendar: pacificCalendar) == false)
        #expect(WakeWindowCalculator.isWithinNightSleepWindow(localTime(17, 45), config: earlyBedtimeConfig, calendar: pacificCalendar) == true)

        let wake = localTime(7, 0)

        // At 7:15 PM with 0 naps logged -> must return nil (never suggest a daytime nap in evening window)
        let eveningZeroNaps = WakeWindowCalculator.predictNextNap(
            asOf: localTime(19, 15),
            wakeUpTime: wake,
            completedNapsToday: [],
            config: config,
            calendar: pacificCalendar
        )
        #expect(eveningZeroNaps == nil)

        // At 7:15 PM with only 1 nap logged -> must still return nil
        let nap1 = makeNap(start: localTime(9, 30), end: localTime(11, 0))
        let eveningOneNap = WakeWindowCalculator.predictNextNap(
            asOf: localTime(19, 15),
            wakeUpTime: wake,
            completedNapsToday: [nap1],
            config: config,
            calendar: pacificCalendar
        )
        #expect(eveningOneNap == nil)

        // In twilight (5:30 PM, past 5:00 PM cutoff) with only 1 nap logged -> classified as .night -> nil
        let twilightOneNap = WakeWindowCalculator.predictNextNap(
            asOf: localTime(17, 30),
            wakeUpTime: wake,
            completedNapsToday: [nap1],
            config: config,
            calendar: pacificCalendar
        )
        #expect(twilightOneNap == nil)

        // Daytime asOf (5:00 PM), but Nap 1 ended late at 3:30 PM -> +195m = 6:45 PM (inside night window) -> nil
        let lateNap1 = makeNap(start: localTime(14, 0), end: localTime(15, 30))
        let recommendedInNightWindow = WakeWindowCalculator.predictNextNap(
            asOf: localTime(17, 0),
            wakeUpTime: wake,
            completedNapsToday: [lateNap1],
            config: config,
            calendar: pacificCalendar
        )
        #expect(recommendedInNightWindow == nil)

        // Daytime asOf (4:00 PM), Nap 1 ended at 2:30 PM -> +195m = 5:45 PM (twilight past 5:00 PM cutoff -> .night) -> nil
        let midAfternoonNap1 = makeNap(start: localTime(13, 0), end: localTime(14, 30))
        let recommendedInTwilightBedtime = WakeWindowCalculator.predictNextNap(
            asOf: localTime(16, 0),
            wakeUpTime: wake,
            completedNapsToday: [midAfternoonNap1],
            config: config,
            calendar: pacificCalendar
        )
        #expect(recommendedInTwilightBedtime == nil)

        // 4:40 PM backup catnap before 5:00 PM cutoff STILL predicts cleanly
        let shortNap1 = makeNap(start: localTime(9, 30), end: localTime(10, 5))
        let earlyNap2 = makeNap(start: localTime(12, 25), end: localTime(13, 25))
        let fourFortyCatnap = WakeWindowCalculator.predictNextNap(
            asOf: localTime(14, 0),
            wakeUpTime: wake,
            completedNapsToday: [shortNap1, earlyNap2],
            config: config,
            calendar: pacificCalendar
        )
        #expect(fourFortyCatnap?.isBackupCatnap == true)
        #expect(fourFortyCatnap?.recommendedStart == localTime(16, 40))
    }
}

@Suite("CareRhythmPredictors")
struct CareRhythmPredictorsTests {
    private let encoder = BlythesLifeJSONCoding.makeEncoder(sortedKeys: true)
    private let decoder = BlythesLifeJSONCoding.makeDecoder()

    private var pacificCalendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return cal
    }

    private func localTime(_ hour: Int, _ minute: Int, day: Int = 25) -> Date {
        let components = DateComponents(
            timeZone: TimeZone(identifier: "America/Los_Angeles"),
            year: 2026,
            month: 11,
            day: day,
            hour: hour,
            minute: minute
        )
        return pacificCalendar.date(from: components)!
    }

    private func makeBottle(at start: Date, amountOz: Double = 4.0, deletedAt: Date? = nil) -> EventDTO {
        EventDTO(
            profileId: UUID(),
            eventType: .feeding,
            startedAt: start,
            endedAt: nil,
            timezone: "America/Los_Angeles",
            metadata: .feeding(FeedingMetadata(method: .bottle, substance: .breastMilk, amountOz: amountOz)),
            source: .manual,
            createdBy: UUID(),
            updatedBy: UUID(),
            createdAt: start,
            updatedAt: start,
            deletedAt: deletedAt
        )
    }

    private func makeNursing(
        start: Date,
        end: Date? = nil,
        durationMinutes: Double? = nil,
        leftDurationSeconds: Int? = nil,
        rightDurationSeconds: Int? = nil,
        deletedAt: Date? = nil
    ) -> EventDTO {
        EventDTO(
            profileId: UUID(),
            eventType: .feeding,
            startedAt: start,
            endedAt: end,
            timezone: "America/Los_Angeles",
            metadata: .feeding(
                FeedingMetadata(
                    method: .breast,
                    substance: .breastMilk,
                    side: .both,
                    durationMinutes: durationMinutes,
                    leftDurationSeconds: leftDurationSeconds,
                    rightDurationSeconds: rightDurationSeconds
                )
            ),
            source: .manual,
            createdBy: UUID(),
            updatedBy: UUID(),
            createdAt: start,
            updatedAt: end ?? start,
            deletedAt: deletedAt
        )
    }

    private func makePump(at start: Date) -> EventDTO {
        EventDTO(
            profileId: UUID(),
            eventType: .pump,
            startedAt: start,
            endedAt: start.addingTimeInterval(15 * 60),
            timezone: "America/Los_Angeles",
            metadata: .pump(PumpMetadata(amountOz: 4.0, side: .both, durationMinutes: 15)),
            source: .manual,
            createdBy: UUID(),
            updatedBy: UUID(),
            createdAt: start,
            updatedAt: start
        )
    }

    private func makeMeal(at start: Date, slot: MealSlot? = nil, deletedAt: Date? = nil) -> EventDTO {
        EventDTO(
            profileId: UUID(),
            eventType: .meal,
            startedAt: start,
            endedAt: nil,
            timezone: "America/Los_Angeles",
            metadata: .meal(MealMetadata(mealSlot: slot, portionEaten: .most)),
            source: .manual,
            createdBy: UUID(),
            updatedBy: UUID(),
            createdAt: start,
            updatedAt: start,
            deletedAt: deletedAt
        )
    }

    @Test("MealSlotClassifier classifies clock zones, late-wake Breakfast anchor, and duplicate-lunch guard")
    func mealSlotClassifierBoundariesAndContext() {
        // Breakfast: < 10:30 AM (< 630)
        #expect(MealSlotClassifier.classify(minutesFromMidnight: 0) == .breakfast)
        #expect(MealSlotClassifier.classify(minutesFromMidnight: 480) == .breakfast) // 8:00 AM
        #expect(MealSlotClassifier.classify(minutesFromMidnight: 629) == .breakfast) // 10:29 AM
        #expect(MealSlotClassifier.classify(date: localTime(8, 0), calendar: pacificCalendar) == .breakfast)
        #expect(MealSlotClassifier.classify(date: localTime(10, 29), calendar: pacificCalendar) == .breakfast)

        // Lunch: 10:30 AM – 2:29 PM (630..<870)
        #expect(MealSlotClassifier.classify(minutesFromMidnight: 630) == .lunch) // 10:30 AM
        #expect(MealSlotClassifier.classify(minutesFromMidnight: 720) == .lunch) // 12:00 PM
        #expect(MealSlotClassifier.classify(minutesFromMidnight: 869) == .lunch) // 2:29 PM
        #expect(MealSlotClassifier.classify(date: localTime(10, 30), calendar: pacificCalendar) == .lunch)
        #expect(MealSlotClassifier.classify(date: localTime(12, 0), calendar: pacificCalendar) == .lunch)
        #expect(MealSlotClassifier.classify(date: localTime(14, 29), calendar: pacificCalendar) == .lunch)

        // Snack: 2:30 PM – 4:29 PM (870..<990)
        #expect(MealSlotClassifier.classify(minutesFromMidnight: 870) == .snack) // 2:30 PM
        #expect(MealSlotClassifier.classify(minutesFromMidnight: 900) == .snack) // 3:00 PM
        #expect(MealSlotClassifier.classify(minutesFromMidnight: 989) == .snack) // 4:29 PM
        #expect(MealSlotClassifier.classify(date: localTime(14, 30), calendar: pacificCalendar) == .snack)
        #expect(MealSlotClassifier.classify(date: localTime(15, 0), calendar: pacificCalendar) == .snack)
        #expect(MealSlotClassifier.classify(date: localTime(16, 29), calendar: pacificCalendar) == .snack)

        // Dinner: 4:30 PM onward (>= 990), including single meal at 5:00 PM with 0 prior meals (NEVER shifted to lunch!)
        #expect(MealSlotClassifier.classify(minutesFromMidnight: 990) == .dinner) // 4:30 PM
        #expect(MealSlotClassifier.classify(minutesFromMidnight: 1020) == .dinner) // 5:00 PM
        #expect(MealSlotClassifier.classify(minutesFromMidnight: 1439) == .dinner) // 11:59 PM
        #expect(MealSlotClassifier.classify(date: localTime(16, 30), calendar: pacificCalendar) == .dinner)
        #expect(MealSlotClassifier.classify(date: localTime(17, 0), existingMealsToday: [], calendar: pacificCalendar) == .dinner)

        // Late-wake Breakfast anchor: 8:30 AM wake + 10:45 AM first meal (<= wake+2h30m & < 11:15 AM) -> .breakfast
        let lateWake = localTime(8, 30)
        #expect(
            MealSlotClassifier.classify(
                date: localTime(10, 45),
                morningWakeAt: lateWake,
                existingMealsToday: [],
                calendar: pacificCalendar
            ) == .breakfast
        )
        // If Breakfast was already logged, 10:45 AM falls back to .lunch
        let earlierBreakfast = makeMeal(at: localTime(9, 0), slot: .breakfast)
        #expect(
            MealSlotClassifier.classify(
                date: localTime(10, 45),
                morningWakeAt: lateWake,
                existingMealsToday: [earlierBreakfast],
                calendar: pacificCalendar
            ) == .lunch
        )
        // At or after 11:15 AM (mins == 675), late-wake Breakfast anchor does NOT apply -> .lunch
        #expect(
            MealSlotClassifier.classify(
                date: localTime(11, 15),
                morningWakeAt: localTime(9, 0),
                existingMealsToday: [],
                calendar: pacificCalendar
            ) == .lunch
        )
        // More than 2h30m after wake (7:00 AM wake + 10:45 AM meal = 3h45m) -> .lunch
        #expect(
            MealSlotClassifier.classify(
                date: localTime(10, 45),
                morningWakeAt: localTime(7, 0),
                existingMealsToday: [],
                calendar: pacificCalendar
            ) == .lunch
        )

        // Duplicate-lunch guard: 12:00 PM lunch already logged -> 2:00 PM second meal becomes .snack
        let noonLunch = makeMeal(at: localTime(12, 0), slot: nil)
        #expect(
            MealSlotClassifier.classify(
                date: localTime(14, 0),
                existingMealsToday: [noonLunch],
                calendar: pacificCalendar
            ) == .snack
        )
        // Deleted or yesterday's lunch does NOT trigger duplicate-lunch guard
        let deletedLunch = makeMeal(at: localTime(12, 0), slot: .lunch, deletedAt: localTime(12, 10))
        let yesterdayLunch = makeMeal(at: localTime(12, 0, day: 24), slot: .lunch)
        #expect(
            MealSlotClassifier.classify(
                date: localTime(14, 0),
                existingMealsToday: [deletedLunch, yesterdayLunch],
                calendar: pacificCalendar
            ) == .lunch
        )

        // Normalization for negative and >= 1440 values
        #expect(MealSlotClassifier.classify(minutesFromMidnight: -60) == .dinner) // 11:00 PM
        #expect(MealSlotClassifier.classify(minutesFromMidnight: 1440 + 480) == .breakfast) // 8:00 AM
    }

    @Test("FeedPredictor predicts daytime intervals, bedtime feed cap, light-feed notes, first feed, and night suppression")
    func feedPredictorScenarios() throws {
        let config = ScheduleConfig() // 180m interval, targetBedtime = 7:30 PM -> cap 7:00 PM, doneAfter 6:45 PM, lateCutoff 8:30 PM
        let wake = localTime(7, 0)

        // 1. First feed 30m after morning wake when no feed logged today
        let firstFeed = try #require(
            FeedPredictor.predictNextFeed(
                asOf: localTime(7, 10),
                wakeUpTime: wake,
                eventsToday: [makePump(at: localTime(7, 5))], // pump does not count as feeding
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(firstFeed.recommendedStart == localTime(7, 30))
        #expect(firstFeed.windowStart == localTime(7, 15))
        #expect(firstFeed.windowEnd == localTime(7, 45))
        #expect(firstFeed.intervalMinutes == 30)
        #expect(firstFeed.lastFeedAt == nil)
        #expect(firstFeed.isBedtimeFeed == false)
        #expect(firstFeed.isLightFeedNote == false)
        #expect(firstFeed.reason == "First feed after morning wake")

        // No wakeUpTime and no feeds -> nil
        #expect(
            FeedPredictor.predictNextFeed(
                asOf: localTime(7, 10),
                wakeUpTime: nil,
                eventsToday: [],
                config: config,
                calendar: pacificCalendar
            ) == nil
        )

        // 2. Daytime 3h interval from bottle (ignoring deleted feed and yesterday's feed)
        let yesterdayBottle = makeBottle(at: localTime(16, 0, day: 24))
        let morningBottle = makeBottle(at: localTime(8, 15), amountOz: 4.0)
        let deletedLaterBottle = makeBottle(at: localTime(10, 0), deletedAt: localTime(10, 5))
        let afterBottle = try #require(
            FeedPredictor.predictNextFeed(
                asOf: localTime(10, 30),
                wakeUpTime: wake,
                eventsToday: [yesterdayBottle, morningBottle, deletedLaterBottle],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(afterBottle.recommendedStart == localTime(11, 15))
        #expect(afterBottle.windowStart == localTime(11, 0))
        #expect(afterBottle.windowEnd == localTime(11, 30))
        #expect(afterBottle.intervalMinutes == 180)
        #expect(afterBottle.lastFeedAt == localTime(8, 15))
        #expect(afterBottle.isBedtimeFeed == false)
        #expect(afterBottle.isLightFeedNote == false)

        // 3. Daytime 3h interval anchored to nursing `endedAt`
        let nursing = makeNursing(start: localTime(11, 15), end: localTime(11, 35))
        let afterNursing = try #require(
            FeedPredictor.predictNextFeed(
                asOf: localTime(13, 0),
                wakeUpTime: wake,
                eventsToday: [morningBottle, nursing],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(afterNursing.lastFeedAt == localTime(11, 35))
        #expect(afterNursing.recommendedStart == localTime(14, 35))
        #expect(afterNursing.windowStart == localTime(14, 20))
        #expect(afterNursing.windowEnd == localTime(14, 50))
        #expect(afterNursing.isBedtimeFeed == false)
        #expect(afterNursing.isLightFeedNote == false)

        // Inverted nursing timestamps (endedAt < startedAt) fall back to startedAt
        let invertedNursing = makeNursing(start: localTime(11, 30), end: localTime(11, 10))
        let afterInverted = try #require(
            FeedPredictor.predictNextFeed(
                asOf: localTime(13, 0),
                wakeUpTime: wake,
                eventsToday: [invertedNursing],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(afterInverted.lastFeedAt == localTime(11, 30))
        #expect(afterInverted.recommendedStart == localTime(14, 30))
        #expect(afterInverted.isLightFeedNote == false)

        // 4. Bedtime feed cap: 5:15 PM + 3h (8:15 PM) is capped to 7:00 PM with isBedtimeFeed == true
        let lateAfternoonBottle = makeBottle(at: localTime(17, 15))
        let bedtimeFeed = try #require(
            FeedPredictor.predictNextFeed(
                asOf: localTime(18, 0),
                wakeUpTime: wake,
                eventsToday: [lateAfternoonBottle],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(bedtimeFeed.recommendedStart == localTime(19, 0))
        #expect(bedtimeFeed.windowStart == localTime(18, 45))
        #expect(bedtimeFeed.windowEnd == localTime(19, 15))
        #expect(bedtimeFeed.isBedtimeFeed == true)
        #expect(bedtimeFeed.reason == "Bedtime feed before 7:30 PM")

        // 5. Bedtime feed already taken at 6:55 PM (>= 6:45 PM bedtimeDoneAfter) -> nil
        let bedtimeDoneBottle = makeBottle(at: localTime(18, 55))
        #expect(
            FeedPredictor.predictNextFeed(
                asOf: localTime(19, 10),
                wakeUpTime: wake,
                eventsToday: [bedtimeDoneBottle],
                config: config,
                calendar: pacificCalendar
            ) == nil
        )

        // Feed at exact 6:45 PM boundary (>= bedtimeDoneAfter) -> nil
        #expect(
            FeedPredictor.predictNextFeed(
                asOf: localTime(19, 0),
                wakeUpTime: wake,
                eventsToday: [makeBottle(at: localTime(18, 45))],
                config: config,
                calendar: pacificCalendar
            ) == nil
        )

        // Late evening cutoff: asOf > 8:30 PM (targetBedtime + 60m) -> nil
        #expect(
            FeedPredictor.predictNextFeed(
                asOf: localTime(20, 35),
                wakeUpTime: wake,
                eventsToday: [lateAfternoonBottle],
                config: config,
                calendar: pacificCalendar
            ) == nil
        )

        // 6. Light feed note: 1.0 oz bottle with no nearby meal -> isLightFeedNote == true
        let lightBottle = makeBottle(at: localTime(13, 0), amountOz: 1.0)
        let afterLightBottle = try #require(
            FeedPredictor.predictNextFeed(
                asOf: localTime(13, 30),
                wakeUpTime: wake,
                eventsToday: [lightBottle],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(afterLightBottle.isLightFeedNote == true)
        #expect(afterLightBottle.recommendedStart == localTime(16, 0))

        // 1.0 oz bottle right after a solid meal (within ±45m) -> isLightFeedNote == false
        let lunchMeal = makeMeal(at: localTime(12, 30), slot: .lunch)
        let afterLightBottleWithMeal = try #require(
            FeedPredictor.predictNextFeed(
                asOf: localTime(13, 30),
                wakeUpTime: wake,
                eventsToday: [lunchMeal, lightBottle],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(afterLightBottleWithMeal.isLightFeedNote == false)

        // Brief nursing (2m via durationMinutes, via left+right seconds, and via endedAt - startedAt) -> isLightFeedNote == true
        let briefNursingDuration = makeNursing(start: localTime(14, 0), durationMinutes: 2.0)
        let afterBriefDuration = try #require(
            FeedPredictor.predictNextFeed(
                asOf: localTime(14, 15),
                wakeUpTime: wake,
                eventsToday: [briefNursingDuration],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(afterBriefDuration.isLightFeedNote == true)

        let briefNursingSplit = makeNursing(start: localTime(14, 0), leftDurationSeconds: 70, rightDurationSeconds: 50)
        let afterBriefSplit = try #require(
            FeedPredictor.predictNextFeed(
                asOf: localTime(14, 15),
                wakeUpTime: wake,
                eventsToday: [briefNursingSplit],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(afterBriefSplit.isLightFeedNote == true)

        let briefNursingTimestamps = makeNursing(start: localTime(14, 0), end: localTime(14, 2))
        let afterBriefTimestamps = try #require(
            FeedPredictor.predictNextFeed(
                asOf: localTime(14, 15),
                wakeUpTime: wake,
                eventsToday: [briefNursingTimestamps],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(afterBriefTimestamps.isLightFeedNote == true)

        // Brief nursing right after a meal -> isLightFeedNote == false
        let snackMeal = makeMeal(at: localTime(13, 45), slot: .snack)
        let afterBriefNursingWithMeal = try #require(
            FeedPredictor.predictNextFeed(
                asOf: localTime(14, 15),
                wakeUpTime: wake,
                eventsToday: [snackMeal, briefNursingTimestamps],
                config: config,
                calendar: pacificCalendar
            )
        )
        #expect(afterBriefNursingWithMeal.isLightFeedNote == false)

        // 7. Active night sleep suppresses feed prediction
        #expect(
            FeedPredictor.predictNextFeed(
                asOf: localTime(18, 0),
                wakeUpTime: wake,
                eventsToday: [lateAfternoonBottle],
                isNightSleepActive: true,
                config: config,
                calendar: pacificCalendar
            ) == nil
        )

        // Non-positive feeding interval suppresses feed prediction
        let disabledConfig = ScheduleConfig(feedingIntervalMinutes: 0)
        #expect(
            FeedPredictor.predictNextFeed(
                asOf: localTime(10, 30),
                wakeUpTime: wake,
                eventsToday: [morningBottle],
                config: disabledConfig,
                calendar: pacificCalendar
            ) == nil
        )

        // Codable snake_case round-trip (including is_bedtime_feed & is_light_feed_note)
        let encoded = try encoder.encode(bedtimeFeed)
        let json = try #require(String(data: encoded, encoding: .utf8))
        #expect(json.contains("\"recommended_start\""))
        #expect(json.contains("\"window_start\""))
        #expect(json.contains("\"window_end\""))
        #expect(json.contains("\"interval_minutes\":180"))
        #expect(json.contains("\"last_feed_at\""))
        #expect(json.contains("\"is_bedtime_feed\":true"))
        #expect(json.contains("\"is_light_feed_note\":false"))
        #expect(try decoder.decode(NextFeedPrediction.self, from: encoded) == bedtimeFeed)

        // Backward-compatible decoding when new booleans are omitted
        let legacyFeedPredJSON = """
        {
          "recommended_start": "2026-11-25T19:15:00Z",
          "window_start": "2026-11-25T19:00:00Z",
          "window_end": "2026-11-25T19:30:00Z",
          "interval_minutes": 180,
          "reason": "Every 3h after last feed"
        }
        """
        let decodedLegacyFeedPred = try decoder.decode(NextFeedPrediction.self, from: Data(legacyFeedPredJSON.utf8))
        #expect(decodedLegacyFeedPred.isBedtimeFeed == false)
        #expect(decodedLegacyFeedPred.isLightFeedNote == false)
    }

    @Test("MealPredictor handles active nap waiting, 5:00 PM dinner slot, missed lunch rollover, optional feed spacing, and bedtime cutoff")
    func mealPredictorScenarios() throws {
        // 1. 1-meal Dinner-only schedule
        let oneMealConfig = ScheduleConfig(
            mealTargetMinutesFromMidnight: ScheduleConfig.defaultMealTargets(forMealCount: 1)
        )
        let dinnerOnly = try #require(
            MealPredictor.predictNextMeal(
                asOf: localTime(15, 0),
                eventsToday: [],
                config: oneMealConfig,
                calendar: pacificCalendar
            )
        )
        #expect(dinnerOnly.slot == .dinner)
        #expect(dinnerOnly.recommendedStart == localTime(17, 30))
        #expect(dinnerOnly.windowStart == localTime(17, 10))
        #expect(dinnerOnly.windowEnd == localTime(17, 50))
        #expect(dinnerOnly.isSpacedAfterFeed == false)
        #expect(dinnerOnly.isWaitingForNap == false)

        // After single meal at 5:00 PM (with nil explicit slot -> resolves to .dinner) -> nil
        let fivePmMeal = makeMeal(at: localTime(17, 0), slot: nil)
        #expect(
            MealPredictor.predictNextMeal(
                asOf: localTime(17, 30),
                eventsToday: [fivePmMeal],
                config: oneMealConfig,
                calendar: pacificCalendar
            ) == nil
        )

        // 2. 3-meal progression: Breakfast -> Lunch -> Dinner -> nil
        let threeMealConfig = ScheduleConfig(
            mealTargetMinutesFromMidnight: ScheduleConfig.defaultMealTargets(forMealCount: 3)
        )
        let breakfastPred = try #require(
            MealPredictor.predictNextMeal(
                asOf: localTime(7, 30),
                eventsToday: [],
                config: threeMealConfig,
                calendar: pacificCalendar
            )
        )
        #expect(breakfastPred.slot == .breakfast)
        #expect(breakfastPred.recommendedStart == localTime(8, 30))
        #expect(breakfastPred.windowStart == localTime(8, 10))
        #expect(breakfastPred.windowEnd == localTime(8, 50))
        #expect(breakfastPred.isWaitingForNap == false)

        let breakfastDone = makeMeal(at: localTime(8, 35), slot: nil)
        let lunchPred = try #require(
            MealPredictor.predictNextMeal(
                asOf: localTime(11, 0),
                eventsToday: [breakfastDone],
                config: threeMealConfig,
                calendar: pacificCalendar
            )
        )
        #expect(lunchPred.slot == .lunch)
        #expect(lunchPred.recommendedStart == localTime(12, 30))
        #expect(lunchPred.isWaitingForNap == false)

        // 2b. Active nap during lunch window (asOf >= recommendedStart - 20m) -> isWaitingForNap == true
        let lunchWaitingForNap = try #require(
            MealPredictor.predictNextMeal(
                asOf: localTime(12, 15),
                eventsToday: [breakfastDone],
                isNapActive: true,
                config: threeMealConfig,
                calendar: pacificCalendar
            )
        )
        #expect(lunchWaitingForNap.slot == .lunch)
        #expect(lunchWaitingForNap.recommendedStart == localTime(12, 30))
        #expect(lunchWaitingForNap.isWaitingForNap == true)
        #expect(lunchWaitingForNap.reason == "Waiting until after nap")

        // Active nap well before lunch window (10:00 AM < 12:10 PM) -> isWaitingForNap == false
        let morningNapBeforeLunch = try #require(
            MealPredictor.predictNextMeal(
                asOf: localTime(10, 0),
                eventsToday: [breakfastDone],
                isNapActive: true,
                config: threeMealConfig,
                calendar: pacificCalendar
            )
        )
        #expect(morningNapBeforeLunch.slot == .lunch)
        #expect(morningNapBeforeLunch.isWaitingForNap == false)

        let lunchDone = makeMeal(at: localTime(12, 20), slot: nil)
        let dinnerPred = try #require(
            MealPredictor.predictNextMeal(
                asOf: localTime(15, 30),
                eventsToday: [breakfastDone, lunchDone],
                config: threeMealConfig,
                calendar: pacificCalendar
            )
        )
        #expect(dinnerPred.slot == .dinner)
        #expect(dinnerPred.recommendedStart == localTime(17, 30))

        let dinnerDone = makeMeal(at: localTime(17, 25), slot: .dinner)
        #expect(
            MealPredictor.predictNextMeal(
                asOf: localTime(18, 0),
                eventsToday: [breakfastDone, lunchDone, dinnerDone],
                config: threeMealConfig,
                calendar: pacificCalendar
            ) == nil
        )

        // 3. Single meal logged at 5:00 PM (slot: nil) marks Dinner done — NEVER Lunch!
        let twoMealConfig = ScheduleConfig(
            mealTargetMinutesFromMidnight: ScheduleConfig.defaultMealTargets(forMealCount: 2) // 12:00 PM Lunch, 5:30 PM Dinner
        )
        // At 5:15 PM after logging the 5:00 PM meal -> Dinner is done and Lunch was >90m ago -> nil (not Dinner, not stale Lunch)
        #expect(
            MealPredictor.predictNextMeal(
                asOf: localTime(17, 15),
                eventsToday: [fivePmMeal],
                config: twoMealConfig,
                calendar: pacificCalendar
            ) == nil
        )
        // Also verify explicitly that Lunch was NOT marked done (if checked during lunch window at 12:30 PM, Lunch is still unlogged)
        let stillNeedsLunch = try #require(
            MealPredictor.predictNextMeal(
                asOf: localTime(12, 30),
                eventsToday: [fivePmMeal],
                config: twoMealConfig,
                calendar: pacificCalendar
            )
        )
        #expect(stillNeedsLunch.slot == .lunch)

        // 4. Missed Lunch at 4:00 PM rolls over cleanly to Dinner at 5:30 PM
        let skippedLunch = try #require(
            MealPredictor.predictNextMeal(
                asOf: localTime(16, 0),
                eventsToday: [],
                config: twoMealConfig,
                calendar: pacificCalendar
            )
        )
        #expect(skippedLunch.slot == .dinner)
        #expect(skippedLunch.recommendedStart == localTime(17, 30))
        #expect(skippedLunch.isSpacedAfterFeed == false)

        // 5. Optional feed spacing: 45m nudges 5:30 PM Dinner after 5:15 PM bottle to 6:00 PM; 0 (Off) does NOT nudge
        let recentBottle = makeBottle(at: localTime(17, 15))
        let spacedDinner = try #require(
            MealPredictor.predictNextMeal(
                asOf: localTime(17, 20),
                eventsToday: [breakfastDone, lunchDone, recentBottle],
                config: threeMealConfig, // default 45m spacing
                calendar: pacificCalendar
            )
        )
        #expect(spacedDinner.slot == .dinner)
        #expect(spacedDinner.recommendedStart == localTime(18, 0))
        #expect(spacedDinner.windowStart == localTime(17, 40))
        #expect(spacedDinner.windowEnd == localTime(18, 20))
        #expect(spacedDinner.isSpacedAfterFeed == true)

        let noFeedSpacingConfig = ScheduleConfig(
            mealTargetMinutesFromMidnight: ScheduleConfig.defaultMealTargets(forMealCount: 3),
            minMinutesAfterFeedForMeal: 0
        )
        let spacingOffDinner = try #require(
            MealPredictor.predictNextMeal(
                asOf: localTime(17, 20),
                eventsToday: [breakfastDone, lunchDone, recentBottle],
                config: noFeedSpacingConfig,
                calendar: pacificCalendar
            )
        )
        #expect(spacingOffDinner.recommendedStart == localTime(17, 30))
        #expect(spacingOffDinner.isSpacedAfterFeed == false)

        // Earlier bottle at 4:30 PM (60m before 5:30 PM Dinner >= 45m) does NOT nudge
        let earlierBottle = makeBottle(at: localTime(16, 30))
        let unspacedDinner = try #require(
            MealPredictor.predictNextMeal(
                asOf: localTime(16, 45),
                eventsToday: [breakfastDone, lunchDone, earlierBottle],
                config: threeMealConfig,
                calendar: pacificCalendar
            )
        )
        #expect(unspacedDinner.recommendedStart == localTime(17, 30))
        #expect(unspacedDinner.isSpacedAfterFeed == false)

        // 6. Active night sleep suppresses meal prediction
        #expect(
            MealPredictor.predictNextMeal(
                asOf: localTime(16, 0),
                eventsToday: [],
                isNightSleepActive: true,
                config: threeMealConfig,
                calendar: pacificCalendar
            ) == nil
        )

        // 7. At or after target bedtime (7:30 PM = 1170) suppresses meal prediction
        #expect(
            MealPredictor.predictNextMeal(
                asOf: localTime(19, 30),
                eventsToday: [],
                config: oneMealConfig,
                calendar: pacificCalendar
            ) == nil
        )
        #expect(
            MealPredictor.predictNextMeal(
                asOf: localTime(19, 35),
                eventsToday: [],
                config: oneMealConfig,
                calendar: pacificCalendar
            ) == nil
        )

        // Deleted meals and empty meal target schedule handled cleanly
        let deletedDinner = makeMeal(at: localTime(17, 0), slot: .dinner, deletedAt: localTime(17, 5))
        let stillNeedsDinner = try #require(
            MealPredictor.predictNextMeal(
                asOf: localTime(17, 10),
                eventsToday: [deletedDinner],
                config: oneMealConfig,
                calendar: pacificCalendar
            )
        )
        #expect(stillNeedsDinner.slot == .dinner)

        let noMealsConfig = ScheduleConfig(mealTargetMinutesFromMidnight: [])
        #expect(
            MealPredictor.predictNextMeal(
                asOf: localTime(12, 0),
                eventsToday: [],
                config: noMealsConfig,
                calendar: pacificCalendar
            ) == nil
        )

        // Codable snake_case round-trip (including is_waiting_for_nap)
        let encoded = try encoder.encode(lunchWaitingForNap)
        let json = try #require(String(data: encoded, encoding: .utf8))
        #expect(json.contains("\"slot\":\"lunch\""))
        #expect(json.contains("\"recommended_start\""))
        #expect(json.contains("\"window_start\""))
        #expect(json.contains("\"window_end\""))
        #expect(json.contains("\"is_spaced_after_feed\":false"))
        #expect(json.contains("\"is_waiting_for_nap\":true"))
        #expect(try decoder.decode(NextMealPrediction.self, from: encoded) == lunchWaitingForNap)

        // Backward-compatible decoding when is_waiting_for_nap is omitted
        let legacyMealPredJSON = """
        {
          "slot": "dinner",
          "recommended_start": "2026-11-26T02:00:00Z",
          "window_start": "2026-11-26T01:40:00Z",
          "window_end": "2026-11-26T02:20:00Z",
          "is_spaced_after_feed": true,
          "reason": "Dinner spaced 45m after last feed"
        }
        """
        let decodedLegacyMealPred = try decoder.decode(NextMealPrediction.self, from: Data(legacyMealPredJSON.utf8))
        #expect(decodedLegacyMealPred.isWaitingForNap == false)
    }
}
