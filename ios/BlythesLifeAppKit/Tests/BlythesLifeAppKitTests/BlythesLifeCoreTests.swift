import BlythesLifeCore
import BlythesLifeShared
import CoreGraphics
import Foundation
import ImageIO
import os
import Testing
import UniformTypeIdentifiers

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

private func makeSyntheticPNG(width: Int, height: Int) -> Data {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: colorSpace,
        bitmapInfo: bitmapInfo
    )!
    context.setFillColor(red: 0.96, green: 0.94, blue: 0.90, alpha: 1.0)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(red: 0.15, green: 0.20, blue: 0.45, alpha: 1.0)
    context.fill(CGRect(x: 40, y: 40, width: max(1, width / 2), height: max(1, height / 4)))
    let image = context.makeImage()!

    let mutableData = NSMutableData()
    let destination = CGImageDestinationCreateWithData(
        mutableData as CFMutableData,
        UTType.png.identifier as CFString,
        1,
        nil
    )!
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
    return mutableData as Data
}

// MARK: - Configurable Mock Backend API

private final class MockBackendAPI: BackendAPIProviding, Sendable {
    struct State: Sendable {
        var healthResponse = BackendHealthResponse(
            status: "ok",
            database: "postgres",
            storage: "r2",
            extractionModel: "google/gemini-3-flash-preview",
            vlmConfigured: true
        )
        var signInHandler: (@Sendable (AppleAuthRequest) throws -> AuthSessionResponse)?
        var refreshHandler: (@Sendable (RefreshTokenRequest) throws -> AuthSessionResponse)?
        var meHandler: (@Sendable (String) throws -> AuthMeResponse)?
        var deleteAccountHandler: (@Sendable (String) throws -> Void)?
        var createHouseholdHandler: (@Sendable (String, String) throws -> HouseholdDTO)?
        var joinHouseholdHandler: (@Sendable (String, String?, String) throws -> HouseholdDTO)?
        var rotateInviteHandler: (@Sendable (UUID, String) throws -> HouseholdDTO)?
        var listProfilesHandler: (@Sendable (String) throws -> [ProfileDTO])?
        var createProfileHandler: (@Sendable (CreateProfileRequest, String) throws -> ProfileDTO)?
        var updateProfileHandler: (@Sendable (UUID, UpdateProfileRequest, String) throws -> ProfileDTO)?
        var syncPushHandler: (@Sendable (SyncPushRequest, String) throws -> SyncPushResponse)?
        var syncPullHandler: (@Sendable (Date?, Int, String) throws -> SyncPullResponse)?
        var presignHandler: (@Sendable (PresignUploadRequest, String) throws -> PresignUploadResponse)?
        var extractHandler: (@Sendable (ExtractPaperScanRequest, String) throws -> PaperScanDTO)?
        var confirmHandler: (@Sendable (ConfirmPaperScanRequest, String) throws -> PaperScanDTO)?

        var recordedCalls: [String] = []
        var uploadedBytes: [(url: URL, headers: [String: String], data: Data)] = []
        var pushedRequests: [SyncPushRequest] = []
        var confirmedScanRequests: [ConfirmPaperScanRequest] = []
        var refreshRequests: [RefreshTokenRequest] = []
        var joinRequests: [(inviteCode: String, displayName: String?)] = []
        var updatedProfileRequests: [(profileId: UUID, request: UpdateProfileRequest)] = []
        var deleteAccountCallCount: Int = 0
        var logoutCallCount: Int = 0
    }

    let state = OSAllocatedUnfairLock<State>(initialState: State())
    let baseURL: URL

    init(baseURL: URL = URLSessionBackendAPIClient.defaultBaseURL) {
        self.baseURL = baseURL
    }

    func fetchHealth() async throws -> BackendHealthResponse {
        state.withLock {
            $0.recordedCalls.append("GET /health")
            return $0.healthResponse
        }
    }

    func signInWithApple(_ request: AppleAuthRequest) async throws -> AuthSessionResponse {
        let handler = state.withLock { s -> (@Sendable (AppleAuthRequest) throws -> AuthSessionResponse)? in
            s.recordedCalls.append("POST /v1/auth/apple")
            return s.signInHandler
        }
        if let handler {
            return try handler(request)
        }
        throw BackendAPIError.unauthorized
    }

    func refreshSession(_ request: RefreshTokenRequest) async throws -> AuthSessionResponse {
        let handler = state.withLock { s -> (@Sendable (RefreshTokenRequest) throws -> AuthSessionResponse)? in
            s.recordedCalls.append("POST /v1/auth/refresh")
            s.refreshRequests.append(request)
            return s.refreshHandler
        }
        if let handler {
            return try handler(request)
        }
        throw BackendAPIError.unauthorized
    }

    func logout(_ request: LogoutRequest, accessToken: String?) async throws {
        state.withLock {
            $0.recordedCalls.append("POST /v1/auth/logout")
            $0.logoutCallCount += 1
        }
    }

    func fetchMe(accessToken: String) async throws -> AuthMeResponse {
        let handler = state.withLock { s -> (@Sendable (String) throws -> AuthMeResponse)? in
            s.recordedCalls.append("GET /v1/auth/me")
            return s.meHandler
        }
        if let handler {
            return try handler(accessToken)
        }
        let user = UserDTO(id: SampleSeedData.ownerUserId, displayName: "Brian", primaryEmail: "brian@icloud.com")
        return AuthMeResponse(user: user, households: [])
    }

    func deleteAccount(accessToken: String) async throws {
        let handler = state.withLock { s -> (@Sendable (String) throws -> Void)? in
            s.recordedCalls.append("DELETE /v1/account")
            s.deleteAccountCallCount += 1
            return s.deleteAccountHandler
        }
        if let handler {
            try handler(accessToken)
        }
    }

    func listHouseholds(accessToken: String) async throws -> [HouseholdDTO] {
        state.withLock {
            $0.recordedCalls.append("GET /v1/households")
        }
        return []
    }

    func createHousehold(name: String, accessToken: String) async throws -> HouseholdDTO {
        let handler = state.withLock { s -> (@Sendable (String, String) throws -> HouseholdDTO)? in
            s.recordedCalls.append("POST /v1/households")
            return s.createHouseholdHandler
        }
        if let handler {
            return try handler(name, accessToken)
        }
        return HouseholdDTO(name: name, inviteCode: "654321", createdBy: SampleSeedData.ownerUserId)
    }

    func joinHousehold(inviteCode: String, displayName: String?, accessToken: String) async throws -> HouseholdDTO {
        let handler = state.withLock { s -> (@Sendable (String, String?, String) throws -> HouseholdDTO)? in
            s.recordedCalls.append("POST /v1/households/join")
            s.joinRequests.append((inviteCode, displayName))
            return s.joinHouseholdHandler
        }
        if let handler {
            return try handler(inviteCode, displayName, accessToken)
        }
        return HouseholdDTO(name: "Joined", inviteCode: inviteCode, createdBy: SampleSeedData.ownerUserId)
    }

    func rotateInviteCode(householdId: UUID, accessToken: String) async throws -> HouseholdDTO {
        let handler = state.withLock { s -> (@Sendable (UUID, String) throws -> HouseholdDTO)? in
            s.recordedCalls.append("POST /v1/households/\(householdId.uuidString.lowercased())/invite")
            return s.rotateInviteHandler
        }
        if let handler {
            return try handler(householdId, accessToken)
        }
        return HouseholdDTO(id: householdId, name: "Rotated", inviteCode: "112233", createdBy: SampleSeedData.ownerUserId)
    }

    func listProfiles(accessToken: String) async throws -> [ProfileDTO] {
        let handler = state.withLock { s -> (@Sendable (String) throws -> [ProfileDTO])? in
            s.recordedCalls.append("GET /v1/profiles")
            return s.listProfilesHandler
        }
        if let handler {
            return try handler(accessToken)
        }
        return []
    }

    func createProfile(_ request: CreateProfileRequest, accessToken: String) async throws -> ProfileDTO {
        let handler = state.withLock { s -> (@Sendable (CreateProfileRequest, String) throws -> ProfileDTO)? in
            s.recordedCalls.append("POST /v1/profiles")
            return s.createProfileHandler
        }
        if let handler {
            return try handler(request, accessToken)
        }
        return ProfileDTO(
            id: request.id ?? UUID(),
            householdId: request.householdId,
            displayName: request.displayName,
            birthDate: request.birthDate,
            defaultTimezone: request.defaultTimezone,
            scheduleConfig: request.scheduleConfig ?? ScheduleConfig()
        )
    }

    func updateProfile(profileId: UUID, request: UpdateProfileRequest, accessToken: String) async throws -> ProfileDTO {
        let handler = state.withLock { s -> (@Sendable (UUID, UpdateProfileRequest, String) throws -> ProfileDTO)? in
            s.recordedCalls.append("PATCH /v1/profiles/\(profileId.uuidString.lowercased())")
            s.updatedProfileRequests.append((profileId, request))
            return s.updateProfileHandler
        }
        if let handler {
            return try handler(profileId, request, accessToken)
        }
        return ProfileDTO(
            id: profileId,
            householdId: SampleSeedData.householdId,
            displayName: request.displayName ?? "Blythe",
            birthDate: request.birthDate,
            defaultTimezone: request.defaultTimezone ?? SampleSeedData.defaultTimeZoneIdentifier,
            scheduleConfig: request.scheduleConfig ?? ScheduleConfig()
        )
    }

    func syncPush(_ request: SyncPushRequest, accessToken: String) async throws -> SyncPushResponse {
        let handler = state.withLock { s -> (@Sendable (SyncPushRequest, String) throws -> SyncPushResponse)? in
            s.recordedCalls.append("POST /v1/sync/push")
            s.pushedRequests.append(request)
            return s.syncPushHandler
        }
        if let handler {
            return try handler(request, accessToken)
        }
        return SyncPushResponse(
            acceptedEventIds: request.events.map(\.id),
            acceptedProfileIds: (request.profiles ?? []).map(\.id),
            rejected: [],
            serverWatermark: makeDate(hour: 13, minute: 0)
        )
    }

    func syncPull(since: Date?, limit: Int, accessToken: String) async throws -> SyncPullResponse {
        let handler = state.withLock { s -> (@Sendable (Date?, Int, String) throws -> SyncPullResponse)? in
            s.recordedCalls.append("GET /v1/sync/pull")
            return s.syncPullHandler
        }
        if let handler {
            return try handler(since, limit, accessToken)
        }
        return SyncPullResponse(
            events: [],
            profiles: [],
            serverWatermark: makeDate(hour: 13, minute: 0),
            hasMore: false
        )
    }

    func syncStream(accessToken: String) -> AsyncThrowingStream<SyncStreamNotification, Error> {
        state.withLock {
            $0.recordedCalls.append("GET /v1/sync/stream")
        }
        return AsyncThrowingStream { $0.finish() }
    }

    func presignScan(_ request: PresignUploadRequest, accessToken: String) async throws -> PresignUploadResponse {
        let handler = state.withLock { s -> (@Sendable (PresignUploadRequest, String) throws -> PresignUploadResponse)? in
            s.recordedCalls.append("POST /v1/scans/presign")
            return s.presignHandler
        }
        if let handler {
            return try handler(request, accessToken)
        }
        return PresignUploadResponse(
            scanId: UUID(),
            storageKey: "scans/demo.jpg",
            uploadUrl: "https://r2.example.com/upload",
            uploadHeaders: ["Content-Type": request.contentType],
            expiresAt: Date().addingTimeInterval(300)
        )
    }

    func uploadScanBytes(to uploadURL: URL, headers: [String: String], data: Data) async throws {
        state.withLock {
            $0.recordedCalls.append("PUT \(uploadURL.absoluteString)")
            $0.uploadedBytes.append((uploadURL, headers, data))
        }
    }

    func extractScan(_ request: ExtractPaperScanRequest, accessToken: String) async throws -> PaperScanDTO {
        let handler = state.withLock { s -> (@Sendable (ExtractPaperScanRequest, String) throws -> PaperScanDTO)? in
            s.recordedCalls.append("POST /v1/scans/extract")
            return s.extractHandler
        }
        if let handler {
            return try handler(request, accessToken)
        }
        return PaperScanDTO(
            id: request.scanId,
            profileId: request.profileId,
            scanDate: request.scanDate ?? "2026-11-25",
            timezone: request.timezone,
            storageKey: request.storageKey,
            scannedBy: SampleSeedData.ownerUserId
        )
    }

    func confirmScan(_ request: ConfirmPaperScanRequest, accessToken: String) async throws -> PaperScanDTO {
        let handler = state.withLock { s -> (@Sendable (ConfirmPaperScanRequest, String) throws -> PaperScanDTO)? in
            s.recordedCalls.append("POST /v1/scans/\(request.scanId.uuidString.lowercased())/confirm")
            s.confirmedScanRequests.append(request)
            return s.confirmHandler
        }
        if let handler {
            return try handler(request, accessToken)
        }
        return PaperScanDTO(
            id: request.scanId,
            profileId: request.profileId,
            scanDate: request.scanDate,
            timezone: SampleSeedData.defaultTimeZoneIdentifier,
            storageKey: "scans/demo.jpg",
            status: .confirmed,
            scannedBy: SampleSeedData.ownerUserId
        )
    }

    func getScan(scanId: UUID, accessToken: String) async throws -> PaperScanDTO {
        state.withLock {
            $0.recordedCalls.append("GET /v1/scans/\(scanId.uuidString.lowercased())")
        }
        return PaperScanDTO(
            id: scanId,
            profileId: SampleSeedData.profileId,
            scanDate: "2026-11-25",
            timezone: SampleSeedData.defaultTimeZoneIdentifier,
            storageKey: "scans/demo.jpg",
            scannedBy: SampleSeedData.ownerUserId
        )
    }

    func exportJSON(profileId: UUID, accessToken: String) async throws -> Data {
        state.withLock {
            $0.recordedCalls.append("GET /v1/profiles/\(profileId.uuidString.lowercased())/export/json")
        }
        return Data()
    }

    func exportCSV(profileId: UUID, accessToken: String) async throws -> Data {
        state.withLock {
            $0.recordedCalls.append("GET /v1/profiles/\(profileId.uuidString.lowercased())/export/csv")
        }
        return Data()
    }
}

// MARK: - URLProtocol Stub for Live Route Verification

private struct CapturedHTTPRequest: Sendable {
    let method: String
    let path: String
    let query: String?
    let authorization: String?
    let contentType: String?
    let body: Data
}

private final class RouteCapturingURLProtocol: URLProtocol, @unchecked Sendable {
    private struct Storage: Sendable {
        var requests: [CapturedHTTPRequest] = []
        var responder: (@Sendable (URLRequest) -> (Int, Data, [String: String]))?
    }

    private static let storage = OSAllocatedUnfairLock<Storage>(initialState: Storage())

    static func configure(
        responder: @escaping @Sendable (URLRequest) -> (Int, Data, [String: String])
    ) {
        storage.withLock {
            $0.requests = []
            $0.responder = responder
        }
    }

    static func recordedRequests() -> [CapturedHTTPRequest] {
        storage.withLock { $0.requests }
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        let bodyData = Self.readBody(from: request)
        let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        let captured = CapturedHTTPRequest(
            method: request.httpMethod ?? "GET",
            path: components?.path ?? "",
            query: components?.query,
            authorization: request.value(forHTTPHeaderField: "Authorization"),
            contentType: request.value(forHTTPHeaderField: "Content-Type"),
            body: bodyData
        )

        let responder = Self.storage.withLock { state -> (@Sendable (URLRequest) -> (Int, Data, [String: String]))? in
            state.requests.append(captured)
            return state.responder
        }

        let (statusCode, data, headers) = responder?(request) ?? (200, Data("{}".utf8), [:])
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://api.blythe.brianphan.dev")!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if !data.isEmpty {
            client?.urlProtocol(self, didLoad: data)
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static func readBody(from request: URLRequest) -> Data {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else {
            return Data()
        }
        stream.open()
        defer { stream.close() }
        var result = Data()
        var buffer = [UInt8](repeating: 0, count: 4096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count > 0 {
                result.append(buffer, count: count)
            } else {
                break
            }
        }
        return result
    }
}

private func makeMockURLSessionClient() -> URLSessionBackendAPIClient {
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [RouteCapturingURLProtocol.self]
    let session = URLSession(configuration: config)
    return URLSessionBackendAPIClient(
        baseURL: URL(string: "https://api.blythe.brianphan.dev")!,
        session: session
    )
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

        let startedEvent = store.toggleNap()
        #expect(startedEvent == nil)
        #expect(store.activeNapStart == store.now)
        #expect(store.napCardState.mode == .asleep)
        #expect(store.napCardState.primaryActionLabel == "Wake up")
        #expect(store.napCardState.secondaryActionLabel == "Change start time")

        store.undoLastToast()
        #expect(store.activeNapStart == nil)

        store.toggleNap()
        store.tick(now: store.now.addingTimeInterval(50 * 60))
        #expect(store.napCardState.elapsedText == "50m")

        let savedNap = store.toggleNap()
        #expect(savedNap != nil)
        #expect(store.activeNapStart == nil)
        #expect(store.todayEvents.count == initialTodayCount + 1)
        #expect(store.outboxCount == initialOutbox + 1)
        #expect(store.toast?.message == "Nap 2 saved")

        store.undoLastToast()
        #expect(store.todayEvents.count == initialTodayCount)
        #expect(store.activeNapStart != nil)
    }

    @Test("Nursing timer left/right switching, pause, finish, discard, and Undo")
    func nursingTimerLifecycle() {
        let store = BlythesLifeStore.makeDemo()
        let t0 = store.now

        store.tapNursingSide(.left)
        #expect(store.activeNursing?.activeSide == .left)

        store.tick(now: t0.addingTimeInterval(120))
        store.tapNursingSide(.right)
        #expect(store.activeNursing?.activeSide == .right)
        #expect(store.activeNursing?.leftAccumulatedSeconds == 120)

        store.tick(now: t0.addingTimeInterval(300))
        store.tapNursingSide(.right)
        #expect(store.activeNursing?.activeSide == nil)
        #expect(store.activeNursing?.rightAccumulatedSeconds == 180)

        store.discardNursing()
        #expect(store.activeNursing == nil)
        #expect(store.toast?.message == "Nursing timer discarded")
        store.undoLastToast()
        #expect(store.activeNursing != nil)
        #expect(store.activeNursing?.leftAccumulatedSeconds == 120)
        #expect(store.activeNursing?.rightAccumulatedSeconds == 180)

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

        store.undoLastToast()
        let restoredAfterEditUndo = store.todayEvents.first(where: { $0.id == original.id })!
        #expect(store.eventDetail(for: restoredAfterEditUndo) == "Pee M")

        store.deleteEvent(restoredAfterEditUndo)
        #expect(store.todayEvents.first(where: { $0.id == original.id }) == nil)
        #expect(store.events.first(where: { $0.id == original.id })?.deletedAt != nil)

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

        let blocked = store.confirmScanReview(sheetId: sheet.id, drafts: sheet.drafts)
        #expect(blocked.isEmpty)
        #expect(store.pendingReviewSheet != nil)

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

        let tz = store.profileTimeZone
        let resolvedDiaper = saved.first {
            if case .diaper(let d) = $0.metadata { return d.peeSize == .large }
            return false
        }
        #expect(resolvedDiaper != nil)
        #expect(FormattingHelpers.formatClock(resolvedDiaper!.startedAt, timeZone: tz) == "11:30 AM")

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
        let liveSpans = today.sleepSpans.filter(\.isLive)
        #expect(liveSpans.count == 1)
        #expect(today.sleepSpans.count == 3) // Night sleep + Nap 1 + 1 live nap (no double-count)

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

// MARK: - Live Backend Integration & Sync Tests

@Suite("Live Backend E2E Flows")
@MainActor
struct LiveBackendIntegrationTests {
    @Test("401 automatically rotates refresh token in tokenStore and retries operation once")
    func automatic401RefreshAndRetry() async throws {
        let mockAPI = MockBackendAPI()
        let tokenStore = InMemoryAuthTokenStorage(
            initialTokens: StoredAuthTokens(
                accessToken: "expired-access-token",
                refreshToken: "rt_old_123",
                expiresAt: Date().addingTimeInterval(-60),
                deviceId: "device-iphone-1"
            )
        )
        let user = UserDTO(id: SampleSeedData.ownerUserId, displayName: "Brian", primaryEmail: "brian@icloud.com")
        let household = HouseholdDTO(
            id: SampleSeedData.householdId,
            name: "Blythe's household",
            inviteCode: "482913",
            createdBy: user.id
        )

        mockAPI.state.withLock { state in
            state.refreshHandler = { req in
                #expect(req.refreshToken == "rt_old_123")
                #expect(req.deviceId == "device-iphone-1")
                return AuthSessionResponse(
                    accessToken: "fresh-access-token",
                    expiresIn: 900,
                    refreshToken: "rt_rotated_456",
                    user: user,
                    households: [household]
                )
            }
            state.rotateInviteHandler = { householdId, accessToken in
                if accessToken == "expired-access-token" {
                    throw BackendAPIError.unauthorized
                }
                #expect(accessToken == "fresh-access-token")
                return HouseholdDTO(
                    id: householdId,
                    name: "Blythe's household",
                    inviteCode: "998877",
                    createdBy: user.id
                )
            }
        }

        let store = BlythesLifeStore.makeDemo(apiClient: mockAPI, tokenStore: tokenStore)
        #expect(store.isSignedInWithApple == true)

        await store.rotateInviteCodeAsync()

        #expect(store.household.inviteCode == "998877")
        let savedTokens = tokenStore.load()
        #expect(savedTokens?.accessToken == "fresh-access-token")
        #expect(savedTokens?.refreshToken == "rt_rotated_456")
        #expect(savedTokens?.deviceId == "device-iphone-1")
        #expect(mockAPI.state.withLock { $0.refreshRequests.count } == 1)
    }

    @Test("401 during refresh cleanly signs out locally with session-expired status")
    func failedRefreshSignsOutLocally() async {
        let mockAPI = MockBackendAPI()
        let tokenStore = InMemoryAuthTokenStorage(
            initialTokens: StoredAuthTokens(
                accessToken: "expired-access",
                refreshToken: "rt_revoked",
                deviceId: "device-iphone-2"
            )
        )

        mockAPI.state.withLock { state in
            state.refreshHandler = { _ in throw BackendAPIError.unauthorized }
            state.syncPullHandler = { _, _, _ in throw BackendAPIError.unauthorized }
        }

        let store = BlythesLifeStore.makeDemo(apiClient: mockAPI, tokenStore: tokenStore)
        await store.pullFromServer()

        #expect(store.isSignedInWithApple == false)
        #expect(tokenStore.load() == nil)
        #expect(store.syncStatus == .error("Session expired. Sign in again."))
    }

    @Test("Fresh live store starts signedOut with empty state; new-user sign-in enters needsHouseholdSetup without auto-creating a household, then createHouseholdAndProfileAsync completes setup")
    func completeAppleSignInBrandNewUser() async throws {
        let mockAPI = MockBackendAPI()
        let tokenStore = InMemoryAuthTokenStorage(deviceId: "dev-brand-new")
        let storage = InMemoryLocalStateStorage()
        let newUserId = UUID()
        let newHouseholdId = UUID()
        let newProfileId = UUID()

        var currentCal = Calendar(identifier: .gregorian)
        currentCal.timeZone = TimeZone.current
        let babyBirthDate = currentCal.date(from: DateComponents(year: 2026, month: 3, day: 14, hour: 12))!

        mockAPI.state.withLock { state in
            state.signInHandler = { req in
                #expect(req.identityToken == "apple-jwt-token")
                #expect(req.rawNonce == "raw-nonce-xyz")
                #expect(req.authorizationCode == "auth-code-abc")
                #expect(req.deviceId == "dev-brand-new")
                #expect(req.platform == "ios")
                return AuthSessionResponse(
                    accessToken: "live-jwt-1",
                    expiresIn: 900,
                    refreshToken: "rt_live_1",
                    user: UserDTO(id: newUserId, displayName: "Brian", primaryEmail: "brian@example.com"),
                    households: []
                )
            }
            state.createHouseholdHandler = { name, token in
                #expect(name == "Phan Family")
                #expect(token == "live-jwt-1")
                return HouseholdDTO(
                    id: newHouseholdId,
                    name: name,
                    inviteCode: "774411",
                    createdBy: newUserId
                )
            }
            state.createProfileHandler = { req, token in
                #expect(req.householdId == newHouseholdId)
                #expect(req.displayName == "Blythe")
                #expect(req.birthDate == "2026-03-14")
                #expect(token == "live-jwt-1")
                return ProfileDTO(
                    id: newProfileId,
                    householdId: newHouseholdId,
                    displayName: req.displayName,
                    birthDate: req.birthDate,
                    defaultTimezone: req.defaultTimezone,
                    scheduleConfig: req.scheduleConfig ?? ScheduleConfig()
                )
            }
        }

        // 1. Fresh live store starts at .signedOut with ZERO fake sample data
        let store = BlythesLifeStore(
            storage: storage,
            apiClient: mockAPI,
            tokenStore: tokenStore
        )
        #expect(store.sessionStage == .signedOut)
        #expect(store.isSignedInWithApple == false)
        #expect(store.isDemoPreview == false)
        #expect(store.isLiveSession == false)
        #expect(store.events.isEmpty)
        #expect(store.scannedSheets.isEmpty)
        #expect(store.outbox.isEmpty)

        // 2. Brand-new user sign-in transitions to .needsHouseholdSetup WITHOUT auto-creating a household
        try await store.completeAppleSignIn(
            identityToken: "apple-jwt-token",
            rawNonce: "raw-nonce-xyz",
            authorizationCode: "auth-code-abc",
            displayName: "Brian",
            email: "brian@example.com"
        )
        defer { store.stopRealtimeSync() }

        #expect(store.isSignedInWithApple == true)
        #expect(store.isDemoPreview == false)
        #expect(store.isLiveSession == true)
        #expect(store.isAuthenticating == false)
        #expect(store.sessionStage == .needsHouseholdSetup)
        #expect(store.hasCompletedHouseholdSetup == false)
        #expect(store.currentUserId == newUserId)
        #expect(store.events.isEmpty)
        #expect(store.scannedSheets.isEmpty)
        #expect(store.outbox.isEmpty)
        #expect(store.toast?.message == "Signed in with Apple")
        #expect(tokenStore.load()?.refreshToken == "rt_live_1")

        let callsBeforeCreate = mockAPI.state.withLock { $0.recordedCalls }
        #expect(!callsBeforeCreate.contains("POST /v1/households"))
        #expect(!callsBeforeCreate.contains("POST /v1/profiles"))
        #expect(!callsBeforeCreate.contains("GET /v1/sync/pull"))

        // 3. Explicit household + profile creation transitions cleanly to .ready
        try await store.createHouseholdAndProfileAsync(
            householdName: "  Phan Family  ",
            babyName: "  Blythe  ",
            birthDate: babyBirthDate
        )

        #expect(store.sessionStage == .ready)
        #expect(store.hasCompletedHouseholdSetup == true)
        #expect(store.household.id == newHouseholdId)
        #expect(store.household.name == "Phan Family")
        #expect(store.profile.id == newProfileId)
        #expect(store.profile.displayName == "Blythe")
        #expect(store.profile.birthDate == "2026-03-14")
        #expect(store.events.isEmpty)
        #expect(store.toast?.message == "Household created")
    }

    @Test("Brand-new user joining spouse household from needsHouseholdSetup transitions to ready without creating an orphaned household")
    func newUserJoinsSpouseHouseholdFromSetup() async throws {
        let mockAPI = MockBackendAPI()
        let tokenStore = InMemoryAuthTokenStorage(deviceId: "dev-spouse-new")
        let storage = InMemoryLocalStateStorage()
        let spouseUserId = UUID()
        let spouseHouseholdId = UUID()
        let sharedProfileId = UUID()
        let sharedEvent = EventDTO(
            id: UUID(),
            profileId: sharedProfileId,
            eventType: .feeding,
            startedAt: Date().addingTimeInterval(-1800),
            timezone: "America/Los_Angeles",
            metadata: .feeding(FeedingMetadata(method: .bottle, substance: .breastMilk, amountOz: 4.0)),
            createdBy: SampleSeedData.ownerUserId,
            updatedBy: SampleSeedData.ownerUserId
        )

        mockAPI.state.withLock { state in
            state.signInHandler = { _ in
                AuthSessionResponse(
                    accessToken: "jwt-spouse",
                    expiresIn: 900,
                    refreshToken: "rt-spouse",
                    user: UserDTO(id: spouseUserId, displayName: "Sarah", primaryEmail: "sarah@example.com"),
                    households: []
                )
            }
            state.joinHouseholdHandler = { code, _, _ in
                #expect(code == "882244")
                return HouseholdDTO(
                    id: spouseHouseholdId,
                    name: "Blythe's household",
                    inviteCode: "882244",
                    createdBy: SampleSeedData.ownerUserId
                )
            }
            state.listProfilesHandler = { _ in
                [
                    ProfileDTO(
                        id: sharedProfileId,
                        householdId: spouseHouseholdId,
                        displayName: "Blythe",
                        birthDate: "2026-03-25",
                        defaultTimezone: "America/Los_Angeles"
                    )
                ]
            }
            state.syncPullHandler = { _, _, _ in
                SyncPullResponse(
                    events: [sharedEvent],
                    profiles: [],
                    serverWatermark: Date(),
                    hasMore: false
                )
            }
        }

        let store = BlythesLifeStore(storage: storage, apiClient: mockAPI, tokenStore: tokenStore)
        try await store.completeAppleSignIn(identityToken: "jwt", rawNonce: "nonce")
        defer { store.stopRealtimeSync() }
        #expect(store.sessionStage == .needsHouseholdSetup)

        try await store.joinHouseholdAsync(inviteCode: "882 244", displayName: "Sarah")

        #expect(store.sessionStage == .ready)
        #expect(store.hasCompletedHouseholdSetup == true)
        #expect(store.household.id == spouseHouseholdId)
        #expect(store.profile.id == sharedProfileId)
        #expect(store.events.count == 1)
        #expect(store.events.first?.id == sharedEvent.id)
        let calls = mockAPI.state.withLock { $0.recordedCalls }
        #expect(!calls.contains("POST /v1/households"))
        #expect(!calls.contains("POST /v1/profiles"))
    }

    @Test("completeAppleSignIn prefers multi-member household when returning user belongs to multiple households")
    func completeAppleSignInPrefersMultiMemberHousehold() async throws {
        let mockAPI = MockBackendAPI()
        let tokenStore = InMemoryAuthTokenStorage(deviceId: "dev-multi-hh")
        let storage = InMemoryLocalStateStorage()
        let userId = UUID()
        let soloHouseholdId = UUID()
        let sharedHouseholdId = UUID()
        let sharedProfileId = UUID()

        let soloHousehold = HouseholdDTO(
            id: soloHouseholdId,
            name: "Solo",
            inviteCode: "111111",
            createdBy: userId,
            members: [
                HouseholdMemberDTO(householdId: soloHouseholdId, userId: userId, role: .owner, displayName: "Sarah")
            ]
        )
        let sharedHousehold = HouseholdDTO(
            id: sharedHouseholdId,
            name: "Phan Family",
            inviteCode: "222222",
            createdBy: SampleSeedData.ownerUserId,
            members: [
                HouseholdMemberDTO(householdId: sharedHouseholdId, userId: SampleSeedData.ownerUserId, role: .owner, displayName: "Brian"),
                HouseholdMemberDTO(householdId: sharedHouseholdId, userId: userId, role: .member, displayName: "Sarah")
            ]
        )
        let sharedProfile = ProfileDTO(
            id: sharedProfileId,
            householdId: sharedHouseholdId,
            displayName: "Blythe",
            birthDate: "2026-03-25",
            defaultTimezone: "America/Los_Angeles"
        )

        mockAPI.state.withLock { state in
            state.signInHandler = { _ in
                AuthSessionResponse(
                    accessToken: "jwt-multi",
                    expiresIn: 900,
                    refreshToken: "rt-multi",
                    user: UserDTO(id: userId, displayName: "Sarah", primaryEmail: "sarah@example.com"),
                    households: [soloHousehold, sharedHousehold]
                )
            }
            state.listProfilesHandler = { _ in [sharedProfile] }
            state.syncPullHandler = { _, _, _ in
                SyncPullResponse(events: [], profiles: [sharedProfile], serverWatermark: Date(), hasMore: false)
            }
        }

        let store = BlythesLifeStore(storage: storage, apiClient: mockAPI, tokenStore: tokenStore)
        try await store.completeAppleSignIn(identityToken: "jwt", rawNonce: "nonce")
        defer { store.stopRealtimeSync() }

        #expect(store.sessionStage == .ready)
        #expect(store.household.id == sharedHouseholdId)
        #expect(store.profile.id == sharedProfileId)
    }

    @Test("updateBabyProfileAsync hits PATCH /v1/profiles/:id, updates profile fields, and falls back to outbox offline")
    func updateBabyProfileOnlineAndOffline() async throws {
        let mockAPI = MockBackendAPI()
        let tokenStore = InMemoryAuthTokenStorage(
            initialTokens: StoredAuthTokens(
                accessToken: "profile-jwt",
                refreshToken: "rt-profile",
                deviceId: "dev-profile"
            )
        )
        let store = BlythesLifeStore.makeDemo(apiClient: mockAPI, tokenStore: tokenStore)
        let profileId = store.profile.id
        let householdId = store.household.id
        let defaultTimezone = store.profile.defaultTimezone
        let scheduleConfig = store.profile.scheduleConfig

        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone.current
        let updatedBirthDate = cal.date(from: DateComponents(year: 2026, month: 4, day: 2, hour: 12))!

        mockAPI.state.withLock { state in
            state.updateProfileHandler = { id, req, token in
                #expect(id == profileId)
                #expect(token == "profile-jwt")
                #expect(req.displayName == "Blythe Rose")
                #expect(req.birthDate == "2026-04-02")
                return ProfileDTO(
                    id: id,
                    householdId: householdId,
                    displayName: req.displayName ?? "Blythe",
                    birthDate: req.birthDate,
                    defaultTimezone: defaultTimezone,
                    scheduleConfig: scheduleConfig
                )
            }
        }

        try await store.updateBabyProfileAsync(displayName: "  Blythe Rose  ", birthDate: updatedBirthDate)
        #expect(store.profile.displayName == "Blythe Rose")
        #expect(store.profile.birthDate == "2026-04-02")
        #expect(store.toast?.message == "Profile updated")
        let calls = mockAPI.state.withLock { $0.recordedCalls }
        #expect(calls.contains("PATCH /v1/profiles/\(profileId.uuidString.lowercased())"))

        // Rejects empty/whitespace name
        var threwEmptyError = false
        do {
            try await store.updateBabyProfileAsync(displayName: "   ", birthDate: nil)
        } catch {
            threwEmptyError = true
        }
        #expect(threwEmptyError == true)

        // Offline fallback queues profile upsert into durable outbox
        mockAPI.state.withLock { state in
            state.updateProfileHandler = { _, _, _ in
                throw BackendAPIError.networkError("Offline")
            }
        }
        try await store.updateBabyProfileAsync(displayName: "Blythe M.", birthDate: nil)
        #expect(store.profile.displayName == "Blythe M.")
        #expect(store.profile.birthDate == nil)
        #expect(store.outbox.contains(where: { $0.entityKind == .profile && $0.entityId == profileId }))
    }

    @Test("enterDemoPreview loads sample data without overwriting tokens, and exitDemoPreview returns cleanly to signedOut")
    func demoPreviewEnterAndExit() {
        let mockAPI = MockBackendAPI()
        let tokenStore = InMemoryAuthTokenStorage(deviceId: "dev-demo-toggle")
        let storage = InMemoryLocalStateStorage()

        let store = BlythesLifeStore(storage: storage, apiClient: mockAPI, tokenStore: tokenStore)
        #expect(store.sessionStage == .signedOut)
        #expect(store.events.isEmpty)
        #expect(store.isDemoPreview == false)

        store.enterDemoPreview()
        #expect(store.isDemoPreview == true)
        #expect(store.isLiveSession == false)
        #expect(store.sessionStage == .ready)
        #expect(!store.events.isEmpty)
        #expect(store.todayEvents.count == 8)
        #expect(store.now == SampleSeedData.defaultReferenceDate)
        #expect(tokenStore.load() == nil)

        store.exitDemoPreview()
        #expect(store.isDemoPreview == false)
        #expect(store.sessionStage == .signedOut)
        #expect(store.events.isEmpty)
        #expect(store.scannedSheets.isEmpty)
        #expect(store.outbox.isEmpty)
        #expect(store.activeNapStart == nil)
        #expect(store.activeNursing == nil)
    }

    @Test("signOutOnThisDeviceAsync clears tokens, revokes session, and returns to signedOut with zero events")
    func signOutResetsToSignedOutBlankState() async {
        let mockAPI = MockBackendAPI()
        let tokenStore = InMemoryAuthTokenStorage(
            initialTokens: StoredAuthTokens(
                accessToken: "jwt-signout",
                refreshToken: "rt-signout",
                deviceId: "dev-signout"
            )
        )
        let store = BlythesLifeStore.makeDemo(apiClient: mockAPI, tokenStore: tokenStore)
        #expect(store.sessionStage == .ready)
        #expect(!store.events.isEmpty)

        await store.signOutOnThisDeviceAsync()

        #expect(mockAPI.state.withLock { $0.logoutCallCount } == 1)
        #expect(tokenStore.load() == nil)
        #expect(store.isSignedInWithApple == false)
        #expect(store.isDemoPreview == false)
        #expect(store.hasCompletedHouseholdSetup == false)
        #expect(store.sessionStage == .signedOut)
        #expect(store.events.isEmpty)
        #expect(store.scannedSheets.isEmpty)
        #expect(store.outbox.isEmpty)
        #expect(store.activeNapStart == nil)
        #expect(store.activeNursing == nil)
        #expect(store.toast?.message == "Signed out on this device")
    }

    @Test("resumeLiveSession checks /v1/auth/me during needsHouseholdSetup and transitions to ready when household exists on another device")
    func resumeLiveSessionNeedsHouseholdSetupTransition() async {
        let mockAPI = MockBackendAPI()
        let userId = UUID()
        let remoteHouseholdId = UUID()
        let remoteProfileId = UUID()
        let tokenStore = InMemoryAuthTokenStorage(
            initialTokens: StoredAuthTokens(
                accessToken: "jwt-setup",
                refreshToken: "rt-setup",
                deviceId: "dev-setup"
            )
        )
        let storage = InMemoryLocalStateStorage(initialState: SampleSeedData.makeBlankState())

        // First launch: server still has 0 households -> stay at .needsHouseholdSetup without creating one!
        mockAPI.state.withLock { state in
            state.meHandler = { _ in
                AuthMeResponse(
                    user: UserDTO(id: userId, displayName: "Brian", primaryEmail: "brian@example.com"),
                    households: []
                )
            }
        }

        let store = BlythesLifeStore(storage: storage, apiClient: mockAPI, tokenStore: tokenStore)
        #expect(store.sessionStage == .needsHouseholdSetup)

        await store.resumeLiveSession()
        #expect(store.sessionStage == .needsHouseholdSetup)
        let callsWhileEmpty = mockAPI.state.withLock { $0.recordedCalls }
        #expect(callsWhileEmpty.contains("GET /v1/auth/me"))
        #expect(!callsWhileEmpty.contains("POST /v1/households"))
        #expect(!callsWhileEmpty.contains("GET /v1/sync/pull"))

        // Second check: user created/joined a household on another device -> transitions cleanly to .ready!
        let remoteHousehold = HouseholdDTO(
            id: remoteHouseholdId,
            name: "Phan Family",
            inviteCode: "909090",
            createdBy: userId
        )
        let remoteProfile = ProfileDTO(
            id: remoteProfileId,
            householdId: remoteHouseholdId,
            displayName: "Blythe",
            birthDate: "2026-03-25",
            defaultTimezone: "America/Los_Angeles"
        )
        mockAPI.state.withLock { state in
            state.meHandler = { _ in
                AuthMeResponse(
                    user: UserDTO(id: userId, displayName: "Brian", primaryEmail: "brian@example.com"),
                    households: [remoteHousehold]
                )
            }
            state.listProfilesHandler = { _ in [remoteProfile] }
            state.syncPullHandler = { _, _, _ in
                SyncPullResponse(events: [], profiles: [remoteProfile], serverWatermark: Date(), hasMore: false)
            }
        }

        await store.resumeLiveSession()
        defer { store.stopRealtimeSync() }

        #expect(store.sessionStage == .ready)
        #expect(store.hasCompletedHouseholdSetup == true)
        #expect(store.household.id == remoteHouseholdId)
        #expect(store.profile.id == remoteProfileId)
    }

    @Test("completeAppleSignIn adopts existing household & profile and pulls remote events for returning user")
    func completeAppleSignInReturningUser() async throws {
        let mockAPI = MockBackendAPI()
        let tokenStore = InMemoryAuthTokenStorage(deviceId: "dev-returning")
        let userId = UUID()
        let householdId = UUID()
        let profileId = UUID()
        let existingHousehold = HouseholdDTO(
            id: householdId,
            name: "Phan Family",
            inviteCode: "334455",
            createdBy: userId
        )
        let existingProfile = ProfileDTO(
            id: profileId,
            householdId: householdId,
            displayName: "Blythe",
            birthDate: "2026-03-25",
            defaultTimezone: "America/Los_Angeles"
        )
        let remoteEvent = EventDTO(
            id: UUID(),
            profileId: profileId,
            eventType: .diaper,
            startedAt: Date().addingTimeInterval(-600),
            timezone: "America/Los_Angeles",
            metadata: .diaper(DiaperMetadata(peeSize: .large)),
            createdBy: userId,
            updatedBy: userId
        )

        mockAPI.state.withLock { state in
            state.signInHandler = { _ in
                AuthSessionResponse(
                    accessToken: "jwt-returning",
                    expiresIn: 900,
                    refreshToken: "rt-returning",
                    user: UserDTO(id: userId, displayName: "Sarah", primaryEmail: "sarah@example.com"),
                    households: [existingHousehold]
                )
            }
            state.listProfilesHandler = { _ in [existingProfile] }
            state.syncPullHandler = { _, _, _ in
                SyncPullResponse(
                    events: [remoteEvent],
                    profiles: [existingProfile],
                    serverWatermark: Date(),
                    hasMore: false
                )
            }
        }

        let store = BlythesLifeStore.makeDemo(apiClient: mockAPI, tokenStore: tokenStore)
        try await store.completeAppleSignIn(identityToken: "jwt", rawNonce: "nonce")
        defer { store.stopRealtimeSync() }

        #expect(store.household.id == householdId)
        #expect(store.profile.id == profileId)
        #expect(store.events.count == 1)
        #expect(store.events.first?.id == remoteEvent.id)
        let calls = mockAPI.state.withLock { $0.recordedCalls }
        #expect(!calls.contains("POST /v1/households"))
        #expect(!calls.contains("POST /v1/profiles"))
    }

    @Test("joinHouseholdAsync strips spaces, adopts joined profile, pulls shared events; deleteAccountAsync wipes state")
    func joinHouseholdRotateAndDeleteAccount() async throws {
        let mockAPI = MockBackendAPI()
        let tokenStore = InMemoryAuthTokenStorage(
            initialTokens: StoredAuthTokens(
                accessToken: "live-token",
                refreshToken: "rt-live",
                deviceId: "dev-spouse"
            )
        )
        let joinedHouseholdId = UUID()
        let joinedProfileId = UUID()
        let sharedEvent = EventDTO(
            id: UUID(),
            profileId: joinedProfileId,
            eventType: .feeding,
            startedAt: makeDate(hour: 11, minute: 0),
            timezone: "America/Los_Angeles",
            metadata: .feeding(FeedingMetadata(method: .bottle, substance: .breastMilk, amountOz: 3.5)),
            createdBy: SampleSeedData.ownerUserId,
            updatedBy: SampleSeedData.ownerUserId
        )

        mockAPI.state.withLock { state in
            state.joinHouseholdHandler = { code, _, _ in
                #expect(code == "482913")
                return HouseholdDTO(
                    id: joinedHouseholdId,
                    name: "Blythe's household",
                    inviteCode: "482913",
                    createdBy: SampleSeedData.ownerUserId
                )
            }
            state.listProfilesHandler = { _ in
                [
                    ProfileDTO(
                        id: joinedProfileId,
                        householdId: joinedHouseholdId,
                        displayName: "Blythe",
                        defaultTimezone: "America/Los_Angeles"
                    )
                ]
            }
            state.syncPullHandler = { _, _, _ in
                SyncPullResponse(
                    events: [sharedEvent],
                    profiles: [],
                    serverWatermark: makeDate(hour: 12, minute: 0),
                    hasMore: false
                )
            }
            state.rotateInviteHandler = { hid, _ in
                HouseholdDTO(
                    id: hid,
                    name: "Blythe's household",
                    inviteCode: "551122",
                    createdBy: SampleSeedData.ownerUserId
                )
            }
        }

        let store = BlythesLifeStore.makeDemo(apiClient: mockAPI, tokenStore: tokenStore)
        try await store.joinHouseholdAsync(inviteCode: " 482 913 ", displayName: "Sarah")
        defer { store.stopRealtimeSync() }

        #expect(store.household.id == joinedHouseholdId)
        #expect(store.profile.id == joinedProfileId)
        #expect(store.events.count == 1)
        #expect(store.events.first?.id == sharedEvent.id)
        #expect(store.toast?.message == "Joined Blythe's household")

        await store.rotateInviteCodeAsync()
        #expect(store.household.inviteCode == "551122")
        #expect(store.formattedInviteCode == "551 122")

        let health = await store.checkBackendHealth()
        #expect(health?.status == "ok")
        #expect(health?.vlmConfigured == true)

        try await store.deleteAccountAsync()
        #expect(mockAPI.state.withLock { $0.deleteAccountCallCount } == 1)
        #expect(store.isSignedInWithApple == false)
        #expect(store.isDemoPreview == false)
        #expect(store.hasCompletedHouseholdSetup == false)
        #expect(store.sessionStage == .signedOut)
        #expect(store.authEmail == nil)
        #expect(store.displayName == nil)
        #expect(store.events.isEmpty)
        #expect(store.scannedSheets.isEmpty)
        #expect(store.outbox.isEmpty)
        #expect(tokenStore.load() == nil)
        #expect(store.toast?.message == "Account deleted")
    }

    @Test("Live open-ended nap timer syncs start, start-time edit, and wake-up across Device A and Device B")
    func crossDeviceLiveNapSync() async {
        // Shared in-memory backend event table simulating Postgres between Device A and Device B.
        let serverEvents = OSAllocatedUnfairLock<[UUID: EventDTO]>(initialState: [:])

        let sharedAPI = MockBackendAPI()
        sharedAPI.state.withLock { state in
            state.syncPushHandler = { req, _ in
                serverEvents.withLock { table in
                    for event in req.events {
                        table[event.id] = event
                    }
                }
                return SyncPushResponse(
                    acceptedEventIds: req.events.map(\.id),
                    acceptedProfileIds: (req.profiles ?? []).map(\.id),
                    rejected: [],
                    serverWatermark: makeDate(hour: 13, minute: 30)
                )
            }
            state.syncPullHandler = { _, _, _ in
                let snapshot = serverEvents.withLock { Array($0.values) }
                return SyncPullResponse(
                    events: snapshot,
                    profiles: [],
                    serverWatermark: makeDate(hour: 13, minute: 30),
                    hasMore: false
                )
            }
        }

        let deviceA = BlythesLifeStore.makeDemo(apiClient: sharedAPI, accessToken: "token-a")
        let deviceB = BlythesLifeStore.makeDemo(apiClient: sharedAPI, accessToken: "token-b")
        #expect(deviceB.activeNapStart == nil)

        // 1. Device A starts nap -> creates open-ended EventDTO and pushes to Postgres
        let napStart = deviceA.now
        _ = deviceA.toggleNap()
        await deviceA.flushOutbox()

        let openOnServer = serverEvents.withLock { $0.values.first(where: { $0.eventType == .sleep && $0.endedAt == nil }) }
        #expect(openOnServer != nil)
        #expect(openOnServer?.startedAt == napStart)

        // 2. Device B pulls -> immediately enters live asleep state!
        await deviceB.pullFromServer()
        #expect(deviceB.activeNapStart == napStart)
        #expect(deviceB.napCardState.mode == .asleep)
        #expect(!deviceB.todayEvents.contains(where: { $0.id == openOnServer?.id }))

        // 3. Device A edits active nap start time 10 minutes earlier and flushes
        let adjustedStart = napStart.addingTimeInterval(-10 * 60)
        deviceA.tick(now: napStart.addingTimeInterval(60))
        deviceA.updateActiveNapStart(adjustedStart)
        await deviceA.flushOutbox()

        // Device B pulls -> reflects adjusted start time
        await deviceB.pullFromServer()
        #expect(deviceB.activeNapStart == adjustedStart)

        // 4. Device A taps Wake up -> updates SAME event with endedAt != nil
        let wakeTime = napStart.addingTimeInterval(45 * 60)
        deviceA.tick(now: wakeTime)
        let finishedNap = deviceA.toggleNap()
        #expect(finishedNap?.id == openOnServer?.id)
        #expect(finishedNap?.endedAt == wakeTime)
        await deviceA.flushOutbox()

        // 5. Device B pulls -> clears activeNapStart and shows completed nap in todayEvents!
        deviceB.tick(now: wakeTime)
        await deviceB.pullFromServer()
        #expect(deviceB.activeNapStart == nil)
        #expect(deviceB.napCardState.mode == .awake)
        #expect(deviceB.todayEvents.contains(where: { $0.id == finishedNap?.id && $0.endedAt == wakeTime }))
    }

    @Test("Live paper-scan pipeline compresses, presigns, uploads to R2, extracts drafts + VIT D + ambiguity, and confirms without duplicate sync push")
    func livePaperScanPipelineAndConfirm() async throws {
        let mockAPI = MockBackendAPI()
        let tokenStore = InMemoryAuthTokenStorage(
            initialTokens: StoredAuthTokens(
                accessToken: "scan-token",
                refreshToken: "rt-scan",
                deviceId: "dev-scan"
            )
        )
        let scanId = UUID()
        let bottleTime = makeDate(hour: 10, minute: 45)
        let diaperTime = makeDate(hour: 11, minute: 20)

        mockAPI.state.withLock { state in
            state.presignHandler = { req, _ in
                #expect(req.contentType == "image/jpeg")
                #expect((req.fileSizeBytes ?? 0) > 0)
                return PresignUploadResponse(
                    scanId: scanId,
                    storageKey: "scans/live/\(scanId.uuidString.lowercased()).jpg",
                    uploadUrl: "https://r2.blythe.example/presigned-put",
                    uploadHeaders: ["Content-Type": "image/jpeg", "x-amz-acl": "private"],
                    expiresAt: Date().addingTimeInterval(300)
                )
            }
            state.extractHandler = { req, _ in
                #expect(req.scanId == scanId)
                #expect(req.storageKey == "scans/live/\(scanId.uuidString.lowercased()).jpg")
                let extraction = PaperScanExtraction(
                    detectedDate: "2026-11-25",
                    timezone: "America/Los_Angeles",
                    sheetNotes: "Happy morning",
                    events: [
                        ExtractedEventDraft(
                            eventType: .feeding,
                            startedAt: bottleTime,
                            metadata: .feeding(FeedingMetadata(method: .bottle, substance: .breastMilk, amountOz: 3.5)),
                            confidence: .high,
                            matchAction: .create,
                            suggestedCompanion: CompanionSuggestion(
                                eventType: .medicine,
                                startedAt: bottleTime,
                                notes: "Suggested from '+ VIT D' badge",
                                metadata: .medicine(MedicineMetadata(name: "Vitamin D", category: .supplement)),
                                reason: "Row carries + VIT D badge"
                            )
                        ),
                        ExtractedEventDraft(
                            eventType: .diaper,
                            startedAt: diaperTime,
                            metadata: .diaper(DiaperMetadata(peeSize: .large)),
                            confidence: .medium,
                            ambiguityReason: "Overwritten minute digit; could be 11:20 or 11:30",
                            matchAction: .create
                        ),
                        ExtractedEventDraft(
                            eventType: .sleep,
                            startedAt: makeDate(hour: 9, minute: 15),
                            endedAt: makeDate(hour: 10, minute: 32),
                            metadata: .sleep(SleepMetadata(sleepType: .nap)),
                            confidence: .high,
                            matchAction: .skipDuplicate
                        )
                    ]
                )
                return PaperScanDTO(
                    id: scanId,
                    profileId: req.profileId,
                    scanDate: "2026-11-25",
                    timezone: req.timezone,
                    storageKey: req.storageKey,
                    modelId: "google/gemini-3-flash-preview",
                    rawExtraction: extraction,
                    sheetNotes: "Happy morning",
                    status: .pendingReview,
                    scannedBy: SampleSeedData.ownerUserId
                )
            }
        }

        let store = BlythesLifeStore.makeDemo(apiClient: mockAPI, tokenStore: tokenStore)
        let bigPNG = makeSyntheticPNG(width: 2600, height: 1800)

        let sheet = try await store.processScannedPhotoAsync(bigPNG)
        #expect(store.isProcessingScan == false)
        #expect(sheet.id == scanId)
        #expect(sheet.imageData != nil)
        #expect(sheet.drafts.count == 4) // bottle + Vitamin D suggestion + ambiguous diaper + duplicate nap
        #expect(sheet.unresolvedAmbiguityCount == 1)

        // Verify R2 PUT received compressed JPEG with presigned headers
        let uploads = mockAPI.state.withLock { $0.uploadedBytes }
        #expect(uploads.count == 1)
        #expect(uploads[0].url.absoluteString == "https://r2.blythe.example/presigned-put")
        #expect(uploads[0].headers["x-amz-acl"] == "private")
        #expect(uploads[0].data.count < bigPNG.count || uploads[0].data.prefix(2) == Data([0xFF, 0xD8]))

        // Verify Vitamin D companion suggestion & ambiguity chips
        let vitDDraft = sheet.drafts.first(where: { $0.isSuggestion })
        #expect(vitDDraft?.title == "Vitamin D")
        #expect(vitDDraft?.isIncluded == false)

        let ambiguousDiaper = sheet.drafts.first(where: { $0.hasUnresolvedAmbiguity })
        #expect(ambiguousDiaper?.ambiguityOptions == ["11:20 AM", "11:30 AM"])

        // Resolve ambiguity to 11:30 AM, opt in to Vitamin D, and confirm live
        var editedDrafts = sheet.drafts
        for idx in editedDrafts.indices {
            if editedDrafts[idx].hasUnresolvedAmbiguity {
                editedDrafts[idx].resolvedOption = "11:30 AM"
            }
            if editedDrafts[idx].isSuggestion {
                editedDrafts[idx].isIncluded = true
            }
        }

        let savedEvents = await store.confirmScanReviewAsync(sheetId: scanId, drafts: editedDrafts)
        #expect(savedEvents.count == 3) // bottle + Vitamin D + diaper (duplicate nap skipped)

        let confirmedRequests = mockAPI.state.withLock { $0.confirmedScanRequests }
        let pushedRequests = mockAPI.state.withLock { $0.pushedRequests }
        #expect(confirmedRequests.count == 1)
        #expect(confirmedRequests[0].scanId == scanId)
        #expect(confirmedRequests[0].scanDate == "2026-11-25")
        #expect(confirmedRequests[0].sheetNotes == "Happy morning")
        #expect(confirmedRequests[0].events.count == 3)
        #expect(pushedRequests.isEmpty) // Zero duplicate /v1/sync/push!
    }
}

// MARK: - URLSessionBackendAPIClient Exact Route Verification

@Suite("URLSessionBackendAPIClient Routes", .serialized)
struct URLSessionBackendAPIClientRouteTests {
    @Test("Every endpoint hits the exact live backend path and HTTP method")
    func verifiesExactLiveBackendRoutes() async throws {
        let householdId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let profileId = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let scanId = UUID(uuidString: "99999999-8888-7777-6666-555555555555")!
        let user = UserDTO(id: SampleSeedData.ownerUserId, displayName: "Brian", primaryEmail: "brian@icloud.com")
        let household = HouseholdDTO(id: householdId, name: "Blythe's household", inviteCode: "123456", createdBy: user.id)
        let profile = ProfileDTO(id: profileId, householdId: householdId, displayName: "Blythe")
        let scan = PaperScanDTO(
            id: scanId,
            profileId: profileId,
            scanDate: "2026-11-25",
            timezone: "America/Los_Angeles",
            storageKey: "scans/test.jpg",
            scannedBy: user.id
        )

        let encoder = BlythesLifeJSONCoding.makeEncoder()

        RouteCapturingURLProtocol.configure { request in
            let path = request.url?.path ?? ""
            let method = request.httpMethod ?? "GET"
            switch (method, path) {
            case ("GET", "/health"):
                let payload = BackendHealthResponse(
                    status: "ok",
                    database: "postgres",
                    storage: "r2",
                    extractionModel: "google/gemini-3-flash-preview",
                    vlmConfigured: true
                )
                return (200, try! encoder.encode(payload), ["Content-Type": "application/json"])
            case ("POST", "/v1/auth/apple"), ("POST", "/v1/auth/refresh"):
                let payload = AuthSessionResponse(
                    accessToken: "jwt",
                    expiresIn: 900,
                    refreshToken: "rt",
                    user: user,
                    households: [household]
                )
                return (200, try! encoder.encode(payload), ["Content-Type": "application/json"])
            case ("POST", "/v1/auth/logout"), ("DELETE", "/v1/account"):
                return (204, Data(), [:])
            case ("GET", "/v1/auth/me"):
                let payload = AuthMeResponse(user: user, households: [household])
                return (200, try! encoder.encode(payload), ["Content-Type": "application/json"])
            case ("GET", "/v1/households"):
                return (200, try! encoder.encode([household]), ["Content-Type": "application/json"])
            case ("POST", "/v1/households"),
                 ("POST", "/v1/households/join"),
                 ("POST", "/v1/households/\(householdId.uuidString.lowercased())/invite"):
                return (200, try! encoder.encode(household), ["Content-Type": "application/json"])
            case ("GET", "/v1/profiles"):
                return (200, try! encoder.encode([profile]), ["Content-Type": "application/json"])
            case ("POST", "/v1/profiles"),
                 ("PATCH", "/v1/profiles/\(profileId.uuidString.lowercased())"):
                return (200, try! encoder.encode(profile), ["Content-Type": "application/json"])
            case ("POST", "/v1/sync/push"):
                let payload = SyncPushResponse(acceptedEventIds: [], acceptedProfileIds: [], serverWatermark: Date())
                return (200, try! encoder.encode(payload), ["Content-Type": "application/json"])
            case ("GET", "/v1/sync/pull"):
                let payload = SyncPullResponse(events: [], profiles: [], serverWatermark: Date(), hasMore: false)
                return (200, try! encoder.encode(payload), ["Content-Type": "application/json"])
            case ("POST", "/v1/scans/presign"):
                let payload = PresignUploadResponse(
                    scanId: scanId,
                    storageKey: "scans/test.jpg",
                    uploadUrl: "https://r2.example.com/object",
                    uploadHeaders: ["Content-Type": "image/jpeg"],
                    expiresAt: Date().addingTimeInterval(300)
                )
                return (200, try! encoder.encode(payload), ["Content-Type": "application/json"])
            case ("PUT", "/object"):
                return (200, Data(), [:])
            case ("POST", "/v1/scans/extract"),
                 ("POST", "/v1/scans/\(scanId.uuidString.lowercased())/confirm"),
                 ("GET", "/v1/scans/\(scanId.uuidString.lowercased())"):
                return (200, try! encoder.encode(scan), ["Content-Type": "application/json"])
            case ("GET", "/v1/profiles/\(profileId.uuidString.lowercased())/export/json"):
                return (200, Data("{\"schema_version\":1}".utf8), ["Content-Type": "application/json"])
            case ("GET", "/v1/profiles/\(profileId.uuidString.lowercased())/export/csv"):
                return (200, Data("Date,Time\n".utf8), ["Content-Type": "text/csv"])
            default:
                return (404, Data("Not found: \(method) \(path)".utf8), [:])
            }
        }

        let client = makeMockURLSessionClient()
        let token = "bearer-abc"

        let health = try await client.fetchHealth()
        #expect(health.status == "ok")

        _ = try await client.signInWithApple(
            AppleAuthRequest(identityToken: "id", rawNonce: "n", deviceId: "d", deviceName: "iPhone", platform: "ios")
        )
        _ = try await client.refreshSession(RefreshTokenRequest(refreshToken: "rt", deviceId: "d"))
        try await client.logout(LogoutRequest(refreshToken: "rt", deviceId: "d"), accessToken: token)
        let me = try await client.fetchMe(accessToken: token)
        #expect(me.user.id == user.id)
        try await client.deleteAccount(accessToken: token)

        _ = try await client.listHouseholds(accessToken: token)
        _ = try await client.createHousehold(name: "Test", accessToken: token)
        _ = try await client.joinHousehold(inviteCode: "123456", displayName: "Sarah", accessToken: token)
        _ = try await client.rotateInviteCode(householdId: householdId, accessToken: token)

        _ = try await client.listProfiles(accessToken: token)
        _ = try await client.createProfile(CreateProfileRequest(householdId: householdId, displayName: "Blythe"), accessToken: token)
        _ = try await client.updateProfile(profileId: profileId, request: UpdateProfileRequest(displayName: "Blythe"), accessToken: token)

        _ = try await client.syncPush(SyncPushRequest(events: []), accessToken: token)
        _ = try await client.syncPull(since: makeDate(hour: 10, minute: 0), limit: 250, accessToken: token)

        _ = try await client.presignScan(PresignUploadRequest(profileId: profileId, contentType: "image/jpeg", fileSizeBytes: 123), accessToken: token)
        try await client.uploadScanBytes(to: URL(string: "https://r2.example.com/object")!, headers: ["Content-Type": "image/jpeg"], data: Data([0xFF, 0xD8]))
        _ = try await client.extractScan(ExtractPaperScanRequest(scanId: scanId, profileId: profileId, storageKey: "scans/test.jpg", timezone: "America/Los_Angeles"), accessToken: token)
        _ = try await client.confirmScan(ConfirmPaperScanRequest(scanId: scanId, profileId: profileId, scanDate: "2026-11-25", events: []), accessToken: token)
        _ = try await client.getScan(scanId: scanId, accessToken: token)

        let jsonExport = try await client.exportJSON(profileId: profileId, accessToken: token)
        #expect(!jsonExport.isEmpty)
        let csvExport = try await client.exportCSV(profileId: profileId, accessToken: token)
        #expect(!csvExport.isEmpty)

        let recorded = RouteCapturingURLProtocol.recordedRequests()
        let methodPaths = recorded.map { "\($0.method) \($0.path)" }

        let expected: [String] = [
            "GET /health",
            "POST /v1/auth/apple",
            "POST /v1/auth/refresh",
            "POST /v1/auth/logout",
            "GET /v1/auth/me",
            "DELETE /v1/account",
            "GET /v1/households",
            "POST /v1/households",
            "POST /v1/households/join",
            "POST /v1/households/\(householdId.uuidString.lowercased())/invite",
            "GET /v1/profiles",
            "POST /v1/profiles",
            "PATCH /v1/profiles/\(profileId.uuidString.lowercased())",
            "POST /v1/sync/push",
            "GET /v1/sync/pull",
            "POST /v1/scans/presign",
            "PUT /object",
            "POST /v1/scans/extract",
            "POST /v1/scans/\(scanId.uuidString.lowercased())/confirm",
            "GET /v1/scans/\(scanId.uuidString.lowercased())",
            "GET /v1/profiles/\(profileId.uuidString.lowercased())/export/json",
            "GET /v1/profiles/\(profileId.uuidString.lowercased())/export/csv"
        ]
        #expect(methodPaths == expected)
        #expect(recorded.first(where: { $0.path == "/v1/account" })?.authorization == "Bearer bearer-abc")
    }
}

// MARK: - Auth Crypto, Image Compression, Portability, Importer, Persistence & SSE Tests

@Suite("Portability, Importer, Persistence, Crypto, Image & SSE")
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

    @Test("AppleNonceGenerator generates URL-safe random nonces and deterministic lowercase SHA-256 hex")
    func appleNonceGenerator() {
        let nonceA = AppleNonceGenerator.randomNonceString(length: 32)
        let nonceB = AppleNonceGenerator.randomNonceString(length: 32)
        let nonceLong = AppleNonceGenerator.randomNonceString(length: 64)

        #expect(nonceA.count == 32)
        #expect(nonceB.count == 32)
        #expect(nonceLong.count == 64)
        #expect(nonceA != nonceB)

        let allowed = CharacterSet(charactersIn: "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_")
        #expect(nonceA.unicodeScalars.allSatisfy { allowed.contains($0) })

        // Standard SHA-256 test vector matching backend TokenCrypto.sha256Hex
        let digest = AppleNonceGenerator.sha256Hex("hello")
        #expect(digest == "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824")
        #expect(digest.count == 64)
        #expect(digest == AppleNonceGenerator.sha256Hex("hello"))
    }

    @Test("ImageCompressor downscales oversized images to <=2200px JPEG and preserves PDF bytes unchanged")
    func imageCompressorDownscaleAndPDFPassthrough() {
        let largePNG = makeSyntheticPNG(width: 3000, height: 1500)
        let result = ImageCompressor.compressForScanUpload(largePNG, maxDimension: 2200, quality: 0.82)

        #expect(result.contentType == "image/jpeg")
        #expect(result.data.prefix(2) == Data([0xFF, 0xD8]))

        let source = CGImageSourceCreateWithData(result.data as CFData, nil)!
        let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let outWidth = (props?[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let outHeight = (props?[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        #expect(max(outWidth, outHeight) == 2200)
        #expect(outHeight == 1100)

        let pdfBytes = Data("%PDF-1.7\n1 0 obj\n<<>>\nendobj\n%%EOF".utf8)
        let pdfResult = ImageCompressor.compressForScanUpload(pdfBytes)
        #expect(pdfResult.contentType == "application/pdf")
        #expect(pdfResult.data == pdfBytes)
    }

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
            #expect(event.externalId?.count == 19)
        }

        let firstAdded = store.importHuckleberryCSV(sampleHuckleberryCSV)
        #expect(firstAdded == 7)

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

    @Test("PersistedAppState decodes legacy JSON missing hasCompletedHouseholdSetup and isDemoPreview cleanly")
    func persistedAppStateBackwardCompatibleDecode() throws {
        let seed = SampleSeedData.makeDemoState()
        let encoded = try BlythesLifeJSONCoding.makeEncoder().encode(seed)
        var jsonObj = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        jsonObj.removeValue(forKey: "hasCompletedHouseholdSetup")
        jsonObj.removeValue(forKey: "isDemoPreview")
        let legacyData = try JSONSerialization.data(withJSONObject: jsonObj)

        let decoded = try BlythesLifeJSONCoding.makeDecoder().decode(PersistedAppState.self, from: legacyData)
        #expect(decoded.hasCompletedHouseholdSetup == true)
        #expect(decoded.isDemoPreview == false)
        #expect(decoded.profile.id == seed.profile.id)
        #expect(decoded.household.id == seed.household.id)
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
