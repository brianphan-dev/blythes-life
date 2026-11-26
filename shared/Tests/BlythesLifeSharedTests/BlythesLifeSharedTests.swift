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

    @Test("ScheduleConfig partial JSON decodes with canonical defaults")
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
}
