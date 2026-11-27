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
        var listHouseholdsHandler: (@Sendable (String) throws -> [HouseholdDTO])?
        var createHouseholdHandler: (@Sendable (String, String) throws -> HouseholdDTO)?
        var createHouseholdInviteHandler: (@Sendable (UUID, CreateHouseholdInviteRequest, String) throws -> HouseholdInviteDTO)?
        var revokeHouseholdInviteHandler: (@Sendable (UUID, UUID, String) throws -> HouseholdDTO)?
        var joinHouseholdHandler: (@Sendable (JoinHouseholdRequest, String) throws -> JoinHouseholdResponse)?
        var listMyJoinRequestsHandler: (@Sendable (String) throws -> [HouseholdJoinRequestDTO])?
        var approveJoinRequestHandler: (@Sendable (UUID, UUID, String) throws -> HouseholdDTO)?
        var declineJoinRequestHandler: (@Sendable (UUID, UUID, String) throws -> HouseholdDTO)?
        var removeHouseholdMemberHandler: (@Sendable (UUID, UUID, String) throws -> HouseholdDTO)?
        var rotateInviteHandler: (@Sendable (UUID, String) throws -> HouseholdDTO)?
        var listProfilesHandler: (@Sendable (String) throws -> [ProfileDTO])?
        var createProfileHandler: (@Sendable (CreateProfileRequest, String) throws -> ProfileDTO)?
        var updateProfileHandler: (@Sendable (UUID, UpdateProfileRequest, String) throws -> ProfileDTO)?
        var syncPushHandler: (@Sendable (SyncPushRequest, String) throws -> SyncPushResponse)?
        var syncPullHandler: (@Sendable (Date?, Int, String) throws -> SyncPullResponse)?
        var syncStreamHandler: (@Sendable (String) -> AsyncThrowingStream<SyncStreamNotification, Error>)?
        var presignHandler: (@Sendable (PresignUploadRequest, String) throws -> PresignUploadResponse)?
        var extractHandler: (@Sendable (ExtractPaperScanRequest, String) throws -> PaperScanDTO)?
        var confirmHandler: (@Sendable (ConfirmPaperScanRequest, String) throws -> PaperScanDTO)?

        var recordedCalls: [String] = []
        var uploadedBytes: [(url: URL, headers: [String: String], data: Data)] = []
        var pushedRequests: [SyncPushRequest] = []
        var confirmedScanRequests: [ConfirmPaperScanRequest] = []
        var refreshRequests: [RefreshTokenRequest] = []
        var joinRequests: [JoinHouseholdRequest] = []
        var createdInviteRequests: [(householdId: UUID, request: CreateHouseholdInviteRequest)] = []
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
        let handler = state.withLock { s -> (@Sendable (String) throws -> [HouseholdDTO])? in
            s.recordedCalls.append("GET /v1/households")
            return s.listHouseholdsHandler
        }
        if let handler {
            return try handler(accessToken)
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

    func createHouseholdInvite(
        householdId: UUID,
        _ request: CreateHouseholdInviteRequest,
        accessToken: String
    ) async throws -> HouseholdInviteDTO {
        let handler = state.withLock { s -> (@Sendable (UUID, CreateHouseholdInviteRequest, String) throws -> HouseholdInviteDTO)? in
            s.recordedCalls.append("POST /v1/households/\(householdId.uuidString.lowercased())/invites")
            s.createdInviteRequests.append((householdId, request))
            return s.createHouseholdInviteHandler
        }
        if let handler {
            return try handler(householdId, request, accessToken)
        }
        return HouseholdInviteDTO(
            householdId: householdId,
            code: "K7M9P4X2",
            label: request.label,
            role: request.role,
            createdBy: SampleSeedData.ownerUserId,
            expiresAt: Date().addingTimeInterval(TimeInterval((request.ttlHours ?? 24) * 3600))
        )
    }

    func revokeHouseholdInvite(
        householdId: UUID,
        inviteId: UUID,
        accessToken: String
    ) async throws -> HouseholdDTO {
        let handler = state.withLock { s -> (@Sendable (UUID, UUID, String) throws -> HouseholdDTO)? in
            s.recordedCalls.append(
                "DELETE /v1/households/\(householdId.uuidString.lowercased())/invites/\(inviteId.uuidString.lowercased())"
            )
            return s.revokeHouseholdInviteHandler
        }
        if let handler {
            return try handler(householdId, inviteId, accessToken)
        }
        return HouseholdDTO(
            id: householdId,
            name: "Blythe's household",
            createdBy: SampleSeedData.ownerUserId,
            activeInvites: []
        )
    }

    func joinHousehold(_ request: JoinHouseholdRequest, accessToken: String) async throws -> JoinHouseholdResponse {
        let handler = state.withLock { s -> (@Sendable (JoinHouseholdRequest, String) throws -> JoinHouseholdResponse)? in
            s.recordedCalls.append("POST /v1/households/join")
            s.joinRequests.append(request)
            return s.joinHouseholdHandler
        }
        if let handler {
            return try handler(request, accessToken)
        }
        let joined = HouseholdDTO(name: "Joined", inviteCode: request.inviteCode, createdBy: SampleSeedData.ownerUserId)
        return JoinHouseholdResponse(status: .approved, household: joined)
    }

    func listMyJoinRequests(accessToken: String) async throws -> [HouseholdJoinRequestDTO] {
        let handler = state.withLock { s -> (@Sendable (String) throws -> [HouseholdJoinRequestDTO])? in
            s.recordedCalls.append("GET /v1/households/join-requests/mine")
            return s.listMyJoinRequestsHandler
        }
        if let handler {
            return try handler(accessToken)
        }
        return []
    }

    func approveJoinRequest(
        householdId: UUID,
        requestId: UUID,
        accessToken: String
    ) async throws -> HouseholdDTO {
        let handler = state.withLock { s -> (@Sendable (UUID, UUID, String) throws -> HouseholdDTO)? in
            s.recordedCalls.append(
                "POST /v1/households/\(householdId.uuidString.lowercased())/join-requests/\(requestId.uuidString.lowercased())/approve"
            )
            return s.approveJoinRequestHandler
        }
        if let handler {
            return try handler(householdId, requestId, accessToken)
        }
        return HouseholdDTO(id: householdId, name: "Blythe's household", createdBy: SampleSeedData.ownerUserId)
    }

    func declineJoinRequest(
        householdId: UUID,
        requestId: UUID,
        accessToken: String
    ) async throws -> HouseholdDTO {
        let handler = state.withLock { s -> (@Sendable (UUID, UUID, String) throws -> HouseholdDTO)? in
            s.recordedCalls.append(
                "POST /v1/households/\(householdId.uuidString.lowercased())/join-requests/\(requestId.uuidString.lowercased())/decline"
            )
            return s.declineJoinRequestHandler
        }
        if let handler {
            return try handler(householdId, requestId, accessToken)
        }
        return HouseholdDTO(id: householdId, name: "Blythe's household", createdBy: SampleSeedData.ownerUserId)
    }

    func removeHouseholdMember(
        householdId: UUID,
        userId: UUID,
        accessToken: String
    ) async throws -> HouseholdDTO {
        let handler = state.withLock { s -> (@Sendable (UUID, UUID, String) throws -> HouseholdDTO)? in
            s.recordedCalls.append(
                "DELETE /v1/households/\(householdId.uuidString.lowercased())/members/\(userId.uuidString.lowercased())"
            )
            return s.removeHouseholdMemberHandler
        }
        if let handler {
            return try handler(householdId, userId, accessToken)
        }
        return HouseholdDTO(id: householdId, name: "Blythe's household", createdBy: SampleSeedData.ownerUserId)
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
        let handler = state.withLock { s -> (@Sendable (String) -> AsyncThrowingStream<SyncStreamNotification, Error>)? in
            s.recordedCalls.append("GET /v1/sync/stream")
            return s.syncStreamHandler
        }
        if let handler {
            return handler(accessToken)
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

    @Test("Invite code formatting handles 8-char XXXX-XXXX, legacy 6-digit XXX XXX, and nil")
    func inviteCodeFormatting() {
        #expect(FormattingHelpers.formatInviteCode("k7m9p4x2") == "K7M9-P4X2")
        #expect(FormattingHelpers.formatInviteCode("K7M9-P4X2") == "K7M9-P4X2")
        #expect(FormattingHelpers.formatInviteCode(" k7m9 - p4x2 ") == "K7M9-P4X2")
        #expect(FormattingHelpers.formatInviteCode("482913") == "482 913")
        #expect(FormattingHelpers.formatInviteCode("482 913") == "482 913")
        #expect(FormattingHelpers.formatInviteCode("ab12") == "AB12")
        #expect(FormattingHelpers.formatInviteCode("") == "—")
        #expect(FormattingHelpers.formatInviteCode("   -  ") == "—")
        #expect(FormattingHelpers.formatInviteCode(nil) == "—")
    }

    @Test("Expiry countdown formats calm relative hours, minutes, and expired copy")
    func expiryCountdownFormatting() {
        let now = makeDate(hour: 12, minute: 0)
        #expect(FormattingHelpers.formatExpiryCountdown(now.addingTimeInterval(23 * 3600 + 1800), asOf: now) == "Expires in 23h")
        #expect(FormattingHelpers.formatExpiryCountdown(now.addingTimeInterval(45 * 60), asOf: now) == "Expires in 45m")
        #expect(FormattingHelpers.formatExpiryCountdown(now.addingTimeInterval(20), asOf: now) == "Expires in 1m")
        #expect(FormattingHelpers.formatExpiryCountdown(now, asOf: now) == "Expired")
        #expect(FormattingHelpers.formatExpiryCountdown(now.addingTimeInterval(-300), asOf: now) == "Expired")
    }

    @Test("FormattingHelpers classifies untagged meals by local time and exposes canonical formatMealSlot")
    func timeAwareMealTitleAndScanDraftFallback() throws {
        let tzId = SampleSeedData.defaultTimeZoneIdentifier
        let tz = try #require(TimeZone(identifier: tzId))

        #expect(FormattingHelpers.formatMealSlot(.breakfast) == "Breakfast")
        #expect(FormattingHelpers.formatMealSlot(.lunch) == "Lunch")
        #expect(FormattingHelpers.formatMealSlot(.snack) == "Snack")
        #expect(FormattingHelpers.formatMealSlot(.dinner) == "Dinner")

        func untaggedMealEvent(hour: Int, minute: Int) -> EventDTO {
            let userId = UUID()
            return EventDTO(
                id: UUID(),
                profileId: SampleSeedData.profileId,
                eventType: .meal,
                startedAt: makeDate(hour: hour, minute: minute, timeZoneIdentifier: tzId),
                timezone: tzId,
                notes: "Avocado, sweet potato",
                metadata: .meal(MealMetadata(mealSlot: nil, portionEaten: .most)),
                createdBy: userId,
                updatedBy: userId
            )
        }

        #expect(FormattingHelpers.eventTitle(untaggedMealEvent(hour: 8, minute: 30)) == "Breakfast")
        #expect(FormattingHelpers.eventTitle(untaggedMealEvent(hour: 12, minute: 30)) == "Lunch")
        #expect(FormattingHelpers.eventTitle(untaggedMealEvent(hour: 15, minute: 0)) == "Snack")
        #expect(FormattingHelpers.eventTitle(untaggedMealEvent(hour: 17, minute: 0)) == "Dinner")

        // Verify ScanReviewDraftItem.from populates mealSlot when server draft has mealSlot == nil
        let extractedDinner = ExtractedEventDraft(
            eventType: .meal,
            startedAt: makeDate(hour: 17, minute: 0, timeZoneIdentifier: tzId),
            notes: "Pasta, peas",
            metadata: .meal(MealMetadata(mealSlot: nil, portionEaten: .some)),
            confidence: .high
        )
        let drafts = ScanReviewDraftItem.from(
            extractedDraft: extractedDinner,
            rowKey: "row-dinner",
            timeZone: tz,
            preferredUnit: .oz
        )
        let dinnerDraft = try #require(drafts.first)
        #expect(dinnerDraft.title == "Dinner")
        if case .meal(let meta) = dinnerDraft.metadata {
            #expect(meta.mealSlot == .dinner)
        } else {
            Issue.record("Expected meal metadata on dinner draft")
        }
    }

    @Test("Poop color and consistency formatters cover all canonical cases")
    func poopTraitFormatters() {
        #expect(FormattingHelpers.formatPoopColor(.yellow) == "Yellow")
        #expect(FormattingHelpers.formatPoopColor(.brown) == "Brown")
        #expect(FormattingHelpers.formatPoopColor(.green) == "Green")
        #expect(FormattingHelpers.formatPoopColor(.orange) == "Orange")
        #expect(FormattingHelpers.formatPoopColor(.black) == "Black")
        #expect(FormattingHelpers.formatPoopColor(.red) == "Red")
        #expect(FormattingHelpers.formatPoopColor(.pale) == "Pale")

        #expect(FormattingHelpers.formatPoopConsistency(.watery) == "Watery")
        #expect(FormattingHelpers.formatPoopConsistency(.runny) == "Runny")
        #expect(FormattingHelpers.formatPoopConsistency(.seedy) == "Seedy")
        #expect(FormattingHelpers.formatPoopConsistency(.soft) == "Soft")
        #expect(FormattingHelpers.formatPoopConsistency(.firm) == "Firm")
        #expect(FormattingHelpers.formatPoopConsistency(.hard) == "Hard")
        #expect(FormattingHelpers.formatPoopConsistency(.mucousy) == "Mucousy")
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
            #expect(meta.lastSide == .right)
            #expect(meta.durationMinutes == 5)
            #expect(meta.leftDurationSeconds == 120)
            #expect(meta.rightDurationSeconds == 180)
        } else {
            Issue.record("Expected breast feeding metadata")
        }
        #expect(store.eventDetail(for: saved!) == "5m · Left 2m, Right 3m · Ended right")
        #expect(store.lastFeedGlance.isNursing == true)
        #expect(store.lastNursingSideInfo?.side == .right)
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

    @Test("RhythmDaySummary.totalNursingMinutes sums completed + live activeNursing sessions and clips across midnight")
    func rhythmNursingTotalsLiveAndMidnightClipping() {
        let store = BlythesLifeStore.makeDemo()

        // 1. Completed nursing event on today (12m)
        store.logManualNursing(startedAt: makeDate(day: 25, hour: 11, minute: 30), minutes: 12, side: .left)

        // 2. Completed nursing event with endedAt == nil (only durationMinutes = 8m)
        let nilEndEvent = EventDTO(
            id: UUID(),
            profileId: store.profile.id,
            eventType: .feeding,
            startedAt: makeDate(day: 25, hour: 8, minute: 15),
            endedAt: nil,
            timezone: store.profile.defaultTimezone,
            metadata: .feeding(FeedingMetadata(method: .breast, substance: .breastMilk, side: .right, durationMinutes: 8)),
            createdBy: store.currentUserId,
            updatedBy: store.currentUserId
        )
        store.events.append(nilEndEvent)

        // 3. Midnight-crossing nursing event: Nov 24 11:50 PM -> Nov 25 12:10 AM (10m yesterday + 10m today)
        store.logManualNursing(startedAt: makeDate(day: 24, hour: 23, minute: 50), minutes: 20, side: .both)

        // 4. Live active nursing timer started at 12:54 PM, running for 10m (6m left + 4m right)
        let t0 = store.now
        store.tapNursingSide(.left)
        store.tick(now: t0.addingTimeInterval(6 * 60))
        store.tapNursingSide(.right)
        store.tick(now: t0.addingTimeInterval(10 * 60))

        let days = store.rhythmWeekDays
        let yesterday = days[5]
        let today = days[6]

        // Yesterday got the 10m portion before midnight (11:50 PM - 12:00 AM)
        #expect(yesterday.nursingCount == 1)
        #expect(abs(yesterday.totalNursingMinutes - 10.0) < 0.01)
        #expect(yesterday.nursingSpans.first?.isLive == false)

        // Today got: 10m (after midnight) + 8m (nil endedAt) + 12m (manual) + 10m (live activeNursing) = 40m
        #expect(today.nursingCount == 4)
        #expect(abs(today.totalNursingMinutes - 40.0) < 0.01)

        let liveNursingSpans = today.nursingSpans.filter(\.isLive)
        #expect(liveNursingSpans.count == 1)
        #expect(liveNursingSpans[0].id == "live-nursing")
        #expect(abs(liveNursingSpans[0].durationMinutes - 10.0) < 0.01)
    }

    @Test("setPostureOverride applies override in DEBUG and stays automatic in Release builds")
    func postureOverrideBuildGuard() {
        let store = BlythesLifeStore.makeDemo()
        store.setPostureOverride(.duoTabletop)
        #if DEBUG
        #expect(store.postureOverride == .duoTabletop)
        #else
        #expect(store.postureOverride == .automatic)
        #endif
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

    @Test("Evening sleep at 7:30 PM classifies as night sleep with 1 nap or 0 naps and shows calm night sleep state")
    func eveningNightSleepClassificationAndCardState() throws {
        // Case 1: Only 1 daytime nap logged (demo seed), clock at 7:30 PM
        let oneNapStore = BlythesLifeStore.makeDemo()
        let evening = makeDate(day: 25, hour: 19, minute: 30)
        oneNapStore.tick(now: evening)

        #expect(oneNapStore.completedNapsToday.count == 1)
        #expect(oneNapStore.shouldClassifySleepAsNight(asOf: evening) == true)
        #expect(oneNapStore.napCardState.mode == .awake)
        #expect(oneNapStore.napCardState.primaryActionLabel == "Start night sleep")

        _ = oneNapStore.toggleNap()
        #expect(oneNapStore.isActiveSleepNight == true)
        #expect(oneNapStore.toast?.message == "Night sleep started on every device")

        // Advance 2 hours (120m — beyond 90m daytime nap cap): still calm night sleep, no overdue nap cap alert
        oneNapStore.tick(now: evening.addingTimeInterval(120 * 60))
        let nightCard = oneNapStore.napCardState
        #expect(nightCard.mode == .asleep)
        #expect(nightCard.label == "Night sleep · since 7:30 PM")
        #expect(nightCard.elapsedText == "2h 0m")
        #expect(abs(nightCard.progress - (120.0 / 660.0)) < 0.001)
        #expect(nightCard.isOver == false)
        #expect(nightCard.captionPrefix == "Night sleep")
        #expect(nightCard.highlightedClockTime == nil)
        #expect(nightCard.captionSuffix == nil)
        #expect(nightCard.fullCaption == "Night sleep")
        #expect(nightCard.primaryActionLabel == "Wake up")
        #expect(nightCard.secondaryActionLabel == "Change start time")

        // Advance past 11h: progress caps cleanly at 1.0 and stays non-overdue
        oneNapStore.tick(now: evening.addingTimeInterval(700 * 60))
        #expect(oneNapStore.napCardState.progress == 1.0)
        #expect(oneNapStore.napCardState.isOver == false)

        let finishedNight = try #require(oneNapStore.toggleNap())
        if case .sleep(let meta) = finishedNight.metadata {
            #expect(meta.sleepType == .night)
        } else {
            Issue.record("Expected night sleep metadata")
        }
        #expect(oneNapStore.toast?.message == "Night sleep saved")

        // Case 2: 0 sleeps logged today at 7:30 PM
        let zeroNapStore = BlythesLifeStore.makeDemo()
        zeroNapStore.events = []
        zeroNapStore.tick(now: evening)

        #expect(zeroNapStore.completedNapsToday.isEmpty)
        #expect(zeroNapStore.shouldClassifySleepAsNight(asOf: evening) == true)
        #expect(zeroNapStore.napCardState.captionPrefix == "Bedtime window")
        #expect(zeroNapStore.napCardState.primaryActionLabel == "Start night sleep")

        _ = zeroNapStore.toggleNap()
        #expect(zeroNapStore.isActiveSleepNight == true)
        #expect(zeroNapStore.napCardState.captionPrefix == "Night sleep")
        #expect(zeroNapStore.napCardState.isOver == false)
        #expect(zeroNapStore.toast?.message == "Night sleep started on every device")
    }

    @Test("feedSweetSpot tracks progress, next feed clock, overdue state, and suppresses overnight")
    func feedSweetSpotPredictionsAndNightSuppression() throws {
        let store = BlythesLifeStore.makeDemo()
        store.events = []
        store.profile.scheduleConfig.feedingIntervalMinutes = 180 // 3h

        let tenAM = makeDate(day: 25, hour: 10, minute: 0)
        store.tick(now: tenAM)
        store.logBottle(startedAt: tenAM, amount: 4.0, unit: .oz, substance: .formula)

        // 1h 30m later (11:30 AM): 50% progress, next feed 1:00 PM in 1h 30m
        let elevenThirty = makeDate(day: 25, hour: 11, minute: 30)
        store.tick(now: elevenThirty)

        let midInterval = store.feedSweetSpot
        #expect(midInterval.title == "Last feed")
        #expect(midInterval.primaryValue == "1h 30m")
        #expect(midInterval.subtitle == "4 oz formula")
        #expect(midInterval.isNursing == false)
        #expect(abs((try #require(midInterval.progress)) - 0.5) < 0.001)
        #expect(midInterval.isOver == false)
        #expect(midInterval.sweetSpotPrefix == "Next ")
        #expect(midInterval.highlightedClockTime == "1:00 PM")
        #expect(midInterval.sweetSpotSuffix == " · in 1h 30m")
        #expect(midInterval.fullSweetSpotCaption == "Next 1:00 PM · in 1h 30m")

        // 20m past target (1:20 PM): overdue state
        let oneTwenty = makeDate(day: 25, hour: 13, minute: 20)
        store.tick(now: oneTwenty)

        let overdue = store.feedSweetSpot
        #expect(overdue.isOver == true)
        #expect(abs((try #require(overdue.progress)) - (200.0 / 180.0)) < 0.001)
        #expect(overdue.highlightedClockTime == "1:00 PM")
        #expect(overdue.sweetSpotSuffix == " · 20m ago")
        #expect(overdue.fullSweetSpotCaption == "Next 1:00 PM · 20m ago")

        // Active night sleep at 7:30 PM suppresses feed alerts calmly
        let sevenThirty = makeDate(day: 25, hour: 19, minute: 30)
        store.tick(now: sevenThirty)
        _ = store.toggleNap()
        #expect(store.isActiveSleepNight == true)

        let overnight = store.feedSweetSpot
        #expect(overnight.progress == nil)
        #expect(overnight.isOver == false)
        #expect(overnight.sweetSpotPrefix == "Night sleep")
        #expect(overnight.highlightedClockTime == nil)
        #expect(overnight.fullSweetSpotCaption == "Night sleep")
    }

    @Test("mealSweetSpot predicts Dinner when Lunch is skipped, marks Dinner done without falling back to Lunch, and respects feed spacing")
    func mealSweetSpotProgressionAndFeedSpacing() throws {
        let store = BlythesLifeStore.makeDemo()
        store.events = []
        // Default targets: 8:30 AM Breakfast, 12:30 PM Lunch, 5:30 PM Dinner; 45m min spacing after feed

        // 1. At 4:00 PM with Lunch skipped -> predicts Dinner at 5:30 PM (not Lunch!)
        let fourPM = makeDate(day: 25, hour: 16, minute: 0)
        store.tick(now: fourPM)

        let beforeDinner = store.mealSweetSpot
        #expect(beforeDinner.title == "Next meal")
        #expect(beforeDinner.primaryValue == "Dinner")
        #expect(beforeDinner.subtitle == "None logged today")
        #expect(beforeDinner.suggestedMealSlot == .dinner)
        #expect(beforeDinner.isOver == false)
        #expect(beforeDinner.sweetSpotPrefix == "Around ")
        #expect(beforeDinner.highlightedClockTime == "5:30 PM")
        #expect(beforeDinner.fullSweetSpotCaption == "Around 5:30 PM · in 1h 30m")
        #expect(abs((try #require(beforeDinner.progress)) - 0.5) < 0.001)

        // 2. Feed-to-meal spacing: bottle at 5:05 PM shifts 5:30 PM Dinner to 5:50 PM (5:05 + 45m)
        let fiveOhFive = makeDate(day: 25, hour: 17, minute: 5)
        store.tick(now: fiveOhFive)
        store.logBottle(startedAt: fiveOhFive, amount: 3.5, unit: .oz, substance: .breastMilk)
        store.tick(now: makeDate(day: 25, hour: 17, minute: 10))

        let spacedDinner = store.mealSweetSpot
        #expect(spacedDinner.title == "Next meal")
        #expect(spacedDinner.primaryValue == "Dinner")
        #expect(spacedDinner.suggestedMealSlot == .dinner)
        #expect(spacedDinner.sweetSpotPrefix == "After feed · ")
        #expect(spacedDinner.highlightedClockTime == "5:50 PM")
        #expect(spacedDinner.fullSweetSpotCaption == "After feed · 5:50 PM · in 40m")

        // 3. Logging a single untagged meal at 5:00 PM marks Dinner done — does NOT fall back to Lunch!
        let fivePM = makeDate(day: 25, hour: 17, minute: 0)
        let untaggedDinner = EventDTO(
            id: UUID(),
            profileId: store.profile.id,
            eventType: .meal,
            startedAt: fivePM,
            timezone: store.profile.defaultTimezone,
            notes: "Salmon, avocado",
            metadata: .meal(MealMetadata(mealSlot: nil, portionEaten: .most)),
            createdBy: store.currentUserId,
            updatedBy: store.currentUserId
        )
        store.events.append(untaggedDinner)
        store.tick(now: makeDate(day: 25, hour: 17, minute: 30))

        let afterDinner = store.mealSweetSpot
        #expect(afterDinner.title == "Last meal")
        #expect(afterDinner.primaryValue == "30m")
        #expect(afterDinner.subtitle == "Dinner · Salmon, avocado · Most eaten")
        #expect(afterDinner.progress == nil)
        #expect(afterDinner.isOver == false)
        #expect(afterDinner.sweetSpotPrefix == "Done for today")
        #expect(afterDinner.highlightedClockTime == nil)
        #expect(afterDinner.suggestedMealSlot == nil)
    }

    @Test("classifySleep covers 3 zones, twilight context, 3.5h duration guard, and overnight midnight crossing")
    func classifySleepZonesDurationAndMidnightCrossing() {
        let store = BlythesLifeStore.makeDemo()
        store.events = []
        store.profile.scheduleConfig = ScheduleConfig(
            wakeWindowsMinutes: [150, 195],
            napCapMinutes: 90,
            backupCatnapCutoffMinutesFromMidnight: 1020, // 5:00 PM
            targetBedtimeMinutesFromMidnight: 1170, // 7:30 PM -> twilight 5:15 PM, night 6:45 PM
            bedtimeWakeWindowMinutes: 225 // 3h 45m
        )

        let onePM = makeDate(day: 25, hour: 13, minute: 0)
        store.tick(now: onePM)

        // 1. Daytime zone (< 5:15 PM) -> .nap
        #expect(store.classifySleep(start: onePM) == .nap)
        #expect(store.shouldClassifySleepAsNight(asOf: onePM) == false)

        // 2. Clearly-night zone (>= 6:45 PM or < 6:00 AM) -> .night
        let sixFortyFivePM = makeDate(day: 25, hour: 18, minute: 45)
        let twoThirtyAM = makeDate(day: 25, hour: 2, minute: 30)
        #expect(store.classifySleep(start: sixFortyFivePM) == .night)
        #expect(store.shouldClassifySleepAsNight(asOf: sixFortyFivePM) == true)
        #expect(store.classifySleep(start: twoThirtyAM) == .night)
        #expect(store.shouldClassifySleepAsNight(asOf: twoThirtyAM) == true)

        // 3. Twilight zone (5:15 PM ..< 6:45 PM): past backup cutoff -> .night
        let fiveTwentyPM = makeDate(day: 25, hour: 17, minute: 20)
        store.tick(now: fiveTwentyPM)
        #expect(store.classifySleep(start: fiveTwentyPM) == .night)

        // Twilight before backup cutoff: short wake + incomplete naps -> .nap; long wake or all naps done -> .night
        store.profile.scheduleConfig.backupCatnapCutoffMinutesFromMidnight = 1080 // 6:00 PM
        _ = store.logPastSleep(
            isNap: true,
            start: makeDate(day: 25, hour: 14, minute: 30),
            end: makeDate(day: 25, hour: 15, minute: 30)
        )
        // Awake 1h 50m (< 225 - 30 = 195m) and only 1/2 naps -> .nap
        #expect(store.classifySleep(start: fiveTwentyPM) == .nap)

        // With 2 completed naps today -> .night in twilight
        _ = store.logPastSleep(
            isNap: true,
            start: makeDate(day: 25, hour: 9, minute: 0),
            end: makeDate(day: 25, hour: 10, minute: 30)
        )
        #expect(store.classifySleep(start: fiveTwentyPM) == .night)

        // With only 1 nap ending at 2:00 PM (awake 3h 20m = 200m >= 195m threshold) -> .night in twilight
        store.events = []
        _ = store.logPastSleep(
            isNap: true,
            start: makeDate(day: 25, hour: 12, minute: 30),
            end: makeDate(day: 25, hour: 14, minute: 0)
        )
        #expect(store.classifySleep(start: fiveTwentyPM) == .night)

        // 4. 3.5h (210m) duration guard overrides daytime zone
        #expect(store.classifySleep(start: onePM, end: makeDate(day: 25, hour: 16, minute: 29)) == .nap)
        #expect(store.classifySleep(start: onePM, end: makeDate(day: 25, hour: 16, minute: 30)) == .night)

        // 5. Overnight midnight crossing classifies as .night even when < 3.5h
        let elevenFortyFivePM = makeDate(day: 25, hour: 23, minute: 45)
        let twelveFifteenAMNextDay = makeDate(day: 26, hour: 0, minute: 15)
        #expect(store.classifySleep(start: elevenFortyFivePM, end: twelveFifteenAMNextDay) == .night)
    }

    @Test("switchActiveSleepType flips active nap to night sleep, updates card and outbox, and Undo restores nap")
    func switchActiveSleepTypeAndUndo() throws {
        let store = BlythesLifeStore.makeDemo()
        store.events = []
        store.profile.scheduleConfig = ScheduleConfig()

        let fourFortyFivePM = makeDate(day: 25, hour: 16, minute: 45)
        store.tick(now: fourFortyFivePM)
        _ = store.toggleNap()

        #expect(store.isActiveNap == true)
        #expect(store.isActiveSleepNight == false)
        #expect(store.napCardState.captionPrefix == "Nap cap ")

        // Attach a crib location on the open sleep event to verify preservation across type switching.
        let openIdx = try #require(store.events.firstIndex(where: { $0.eventType == .sleep && $0.endedAt == nil }))
        let openEventId = store.events[openIdx].id
        store.events[openIdx].metadata = .sleep(SleepMetadata(sleepType: .nap, location: .crib))

        // Advance 2h 35m -> 7:20 PM: late nap overdue & eligible for switch-to-night suggestion.
        let sevenTwentyPM = fourFortyFivePM.addingTimeInterval(155 * 60)
        store.tick(now: sevenTwentyPM)
        #expect(store.shouldSuggestSwitchActiveSleepToNight == true)
        #expect(store.napCardState.isOver == true)

        // Switch active nap -> night sleep
        store.switchActiveSleepType(.night)

        #expect(store.isActiveSleepNight == true)
        #expect(store.isActiveNap == false)
        #expect(store.shouldSuggestSwitchActiveSleepToNight == false)
        #expect(store.napCardState.mode == .asleep)
        #expect(store.napCardState.label == "Night sleep · since 4:45 PM")
        #expect(store.napCardState.captionPrefix == "Night sleep")
        #expect(store.napCardState.isOver == false)
        #expect(store.toast?.message == "Switched to night sleep")
        #expect(store.toast?.canUndo == true)

        let outboxNightItem = try #require(store.outbox.first(where: { $0.entityKind == .event && $0.entityId == openEventId }))
        let decodedNight = try #require(try outboxNightItem.decodedEvent())
        if case .sleep(let meta) = decodedNight.metadata {
            #expect(meta.sleepType == .night)
            #expect(meta.location == .crib)
        } else {
            Issue.record("Expected sleep metadata in outbox after switching to night")
        }

        // Undo restores `.nap` metadata, card state, and re-enqueues outbox
        store.undoLastToast()
        #expect(store.isActiveSleepNight == false)
        #expect(store.isActiveNap == true)
        #expect(store.shouldSuggestSwitchActiveSleepToNight == true)
        #expect(store.napCardState.captionPrefix == "Nap cap ")

        let outboxRevertedItem = try #require(store.outbox.first(where: { $0.entityKind == .event && $0.entityId == openEventId }))
        let decodedReverted = try #require(try outboxRevertedItem.decodedEvent())
        if case .sleep(let meta) = decodedReverted.metadata {
            #expect(meta.sleepType == .nap)
            #expect(meta.location == .crib)
        } else {
            Issue.record("Expected restored nap metadata in outbox after Undo")
        }

        // Switching to night then back to nap directly emits the calm nap toast
        store.switchActiveSleepType(.night)
        store.switchActiveSleepType(.nap)
        #expect(store.isActiveNap == true)
        #expect(store.toast?.message == "Switched to nap")
    }

    @Test("shouldSuggestSwitchActiveSleepToNight triggers for late 4:45 PM nap running 2h 35m and ignores earlier/shorter naps")
    func shouldSuggestSwitchActiveSleepToNightThresholds() {
        // Late 4:45 PM nap
        let lateStore = BlythesLifeStore.makeDemo()
        lateStore.events = []
        lateStore.profile.scheduleConfig = ScheduleConfig() // napCapMinutes = 90 -> threshold 150m (2h 30m)

        let fourFortyFivePM = makeDate(day: 25, hour: 16, minute: 45)
        lateStore.tick(now: fourFortyFivePM)
        _ = lateStore.toggleNap()
        #expect(lateStore.isActiveNap == true)

        // At 2h 25m (145m < 150m): not yet suggested
        lateStore.tick(now: fourFortyFivePM.addingTimeInterval(145 * 60))
        #expect(lateStore.shouldSuggestSwitchActiveSleepToNight == false)

        // At 2h 35m (155m >= 150m): suggested
        lateStore.tick(now: fourFortyFivePM.addingTimeInterval(155 * 60))
        #expect(lateStore.shouldSuggestSwitchActiveSleepToNight == true)

        // Earlier 4:15 PM nap (< 4:30 PM cutoff) running 2h 35m: not suggested
        let earlyStore = BlythesLifeStore.makeDemo()
        earlyStore.events = []
        earlyStore.profile.scheduleConfig = ScheduleConfig()

        let fourFifteenPM = makeDate(day: 25, hour: 16, minute: 15)
        earlyStore.tick(now: fourFifteenPM)
        _ = earlyStore.toggleNap()
        earlyStore.tick(now: fourFifteenPM.addingTimeInterval(155 * 60))
        #expect(earlyStore.shouldSuggestSwitchActiveSleepToNight == false)
    }

    @Test("morningWakeToday and classifyMealSlot handle late-wake Breakfast, duplicate lunch, exclusion, and 5:00 PM Dinner")
    func classifyMealSlotContextualRules() {
        let store = BlythesLifeStore.makeDemo()
        store.events = []
        let tenFortyFiveAM = makeDate(day: 25, hour: 10, minute: 45)
        store.tick(now: tenFortyFiveAM)

        // No night sleep ended today -> morningWakeToday is nil (even if a daytime nap exists)
        #expect(store.morningWakeToday == nil)
        _ = store.logPastSleep(
            isNap: true,
            start: makeDate(day: 25, hour: 9, minute: 0),
            end: makeDate(day: 25, hour: 10, minute: 0)
        )
        #expect(store.morningWakeToday == nil)
        #expect(store.classifyMealSlot(for: tenFortyFiveAM) == .lunch)

        // Overnight night sleep ending at 8:30 AM today enables late-wake Breakfast anchor (8:30 AM + 2h 15m = 10:45 AM)
        let eightThirtyAM = makeDate(day: 25, hour: 8, minute: 30)
        _ = store.logPastSleep(
            isNap: false,
            start: makeDate(day: 24, hour: 20, minute: 0),
            end: eightThirtyAM
        )
        #expect(store.morningWakeToday == eightThirtyAM)
        #expect(store.classifyMealSlot(for: tenFortyFiveAM) == .breakfast)

        // Duplicate lunch guard: 12:00 PM lunch -> 2:00 PM classifies as .snack
        let noon = makeDate(day: 25, hour: 12, minute: 0)
        let twoPM = makeDate(day: 25, hour: 14, minute: 0)
        let lunchEvent = store.logMeal(startedAt: noon, slot: .lunch, ate: "Avocado toast")
        #expect(store.classifyMealSlot(for: twoPM) == .snack)
        // Excluding the lunch event itself keeps 12:00 PM as .lunch (e.g. when editing)
        #expect(store.classifyMealSlot(for: noon, excludingEventId: lunchEvent.id) == .lunch)

        // Single 5:00 PM meal on an empty day classifies as .dinner
        store.events = []
        let fivePM = makeDate(day: 25, hour: 17, minute: 0)
        store.tick(now: fivePM)
        #expect(store.classifyMealSlot(for: fivePM) == .dinner)
    }

    @Test("napCardState uses profile bedtimeWakeWindowMinutes and clamps late-catnap bedtime to targetBedtime")
    func napCardStateBedtimeWakeWindowAndClamp() {
        let store = BlythesLifeStore.makeDemo()
        store.events = []
        store.profile.scheduleConfig = ScheduleConfig(
            wakeWindowsMinutes: [150, 195],
            napCapMinutes: 90,
            backupCatnapCutoffMinutesFromMidnight: 1020, // 5:00 PM
            targetBedtimeMinutesFromMidnight: 1170, // 7:30 PM
            bedtimeWakeWindowMinutes: 225 // 3h 45m
        )

        // Complete both scheduled naps (Nap 2 ends 3:15 PM -> raw bedtime = 3:15 + 3h 45m = 7:00 PM)
        _ = store.logPastSleep(
            isNap: true,
            start: makeDate(day: 25, hour: 9, minute: 0),
            end: makeDate(day: 25, hour: 10, minute: 30)
        )
        _ = store.logPastSleep(
            isNap: true,
            start: makeDate(day: 25, hour: 13, minute: 45),
            end: makeDate(day: 25, hour: 15, minute: 15)
        )

        store.tick(now: makeDate(day: 25, hour: 17, minute: 15))
        let normalBedtimeCard = store.napCardState
        #expect(normalBedtimeCard.mode == .awake)
        #expect(normalBedtimeCard.highlightedClockTime == "7:00 PM")
        #expect(normalBedtimeCard.fullCaption == "Bedtime sweet spot 7:00 PM · in 1h 45m")
        #expect(abs(normalBedtimeCard.progress - (120.0 / 225.0)) < 0.001)

        // Late catnap ending at 5:30 PM -> raw bedtime 9:15 PM (> 7:30 PM + 45m).
        // Once now >= 6:00 PM (targetBedtime - 90m), clamp to 7:30 PM target bedtime.
        _ = store.logPastSleep(
            isNap: true,
            start: makeDate(day: 25, hour: 17, minute: 5),
            end: makeDate(day: 25, hour: 17, minute: 30)
        )
        store.tick(now: makeDate(day: 25, hour: 18, minute: 15))
        let clampedBedtimeCard = store.napCardState
        #expect(clampedBedtimeCard.mode == .awake)
        #expect(clampedBedtimeCard.highlightedClockTime == "7:30 PM")
        #expect(clampedBedtimeCard.fullCaption == "Bedtime sweet spot 7:30 PM · in 1h 15m")
        #expect(abs(clampedBedtimeCard.progress - (45.0 / 120.0)) < 0.001)
    }

    @Test("feedSweetSpot handles Bedtime feed cap with smooth progress and honest Light feed cue without fake timer")
    func feedSweetSpotBedtimeCapAndLightFeedCue() throws {
        let store = BlythesLifeStore.makeDemo()
        store.events = []
        store.profile.scheduleConfig = ScheduleConfig(
            targetBedtimeMinutesFromMidnight: 1170, // 7:30 PM -> bedtime feed cap 7:00 PM
            feedingIntervalMinutes: 180 // 3h
        )

        // 1. Bedtime feed cap: 5:00 PM full bottle -> raw 8:00 PM capped to 7:00 PM bedtime feed
        let fivePM = makeDate(day: 25, hour: 17, minute: 0)
        store.tick(now: fivePM)
        store.logBottle(startedAt: fivePM, amount: 4.0, unit: .oz, substance: .formula)

        // At 6:00 PM: halfway across the 2h span (5:00 PM -> 7:00 PM)
        store.tick(now: makeDate(day: 25, hour: 18, minute: 0))
        let bedtimeFeedCard = store.feedSweetSpot
        #expect(bedtimeFeedCard.sweetSpotPrefix == "Bedtime feed ")
        #expect(bedtimeFeedCard.highlightedClockTime == "7:00 PM")
        #expect(bedtimeFeedCard.sweetSpotSuffix == " · in 1h 0m")
        #expect(bedtimeFeedCard.fullSweetSpotCaption == "Bedtime feed 7:00 PM · in 1h 0m")
        #expect(bedtimeFeedCard.isOver == false)
        #expect(abs((try #require(bedtimeFeedCard.progress)) - 0.5) < 0.001)

        // At 7:10 PM: 10m past bedtime feed cap
        store.tick(now: makeDate(day: 25, hour: 19, minute: 10))
        let overdueBedtimeFeed = store.feedSweetSpot
        #expect(overdueBedtimeFeed.isOver == true)
        #expect(overdueBedtimeFeed.sweetSpotPrefix == "Bedtime feed ")
        #expect(overdueBedtimeFeed.highlightedClockTime == "7:00 PM")
        #expect(overdueBedtimeFeed.sweetSpotSuffix == " · 10m ago")
        #expect(overdueBedtimeFeed.fullSweetSpotCaption == "Bedtime feed 7:00 PM · 10m ago")
        #expect(abs((try #require(overdueBedtimeFeed.progress)) - (130.0 / 120.0)) < 0.001)

        // 2. Light feed (< 45 ml bottle without nearby solid meal) -> honest calm cue with no fake timer
        store.events = []
        let tenAM = makeDate(day: 25, hour: 10, minute: 0)
        store.tick(now: tenAM)
        store.logBottle(startedAt: tenAM, amount: 1.0, unit: .oz, substance: .breastMilk)

        store.tick(now: makeDate(day: 25, hour: 10, minute: 20))
        let lightFeedCard = store.feedSweetSpot
        #expect(lightFeedCard.progress == nil)
        #expect(lightFeedCard.isOver == false)
        #expect(lightFeedCard.sweetSpotPrefix == "Light feed · may want more soon")
        #expect(lightFeedCard.highlightedClockTime == nil)
        #expect(lightFeedCard.sweetSpotSuffix == nil)
        #expect(lightFeedCard.fullSweetSpotCaption == "Light feed · may want more soon")

        // A solid meal within ±45m turns the small bottle into a normal top-off with standard next feed timer
        store.logMeal(startedAt: makeDate(day: 25, hour: 10, minute: 15), slot: .breakfast, ate: "Oatmeal")
        let normalAfterMeal = store.feedSweetSpot
        #expect(normalAfterMeal.sweetSpotPrefix == "Next ")
        #expect(normalAfterMeal.highlightedClockTime == "1:00 PM")
        #expect(normalAfterMeal.progress != nil)
    }

    @Test("mealSweetSpot shows Waiting until after nap when active nap overlaps lunch window")
    func mealSweetSpotWaitingUntilAfterNap() {
        let store = BlythesLifeStore.makeDemo()
        store.events = []
        store.profile.scheduleConfig = ScheduleConfig() // 8:30 AM Breakfast, 12:30 PM Lunch, 5:30 PM Dinner

        let eightThirtyAM = makeDate(day: 25, hour: 8, minute: 30)
        store.tick(now: eightThirtyAM)
        store.logMeal(startedAt: eightThirtyAM, slot: .breakfast, ate: "Banana")

        // Start a daytime nap at 11:30 AM
        let elevenThirtyAM = makeDate(day: 25, hour: 11, minute: 30)
        store.tick(now: elevenThirtyAM)
        _ = store.toggleNap()
        #expect(store.isActiveNap == true)

        // At 11:45 AM (45m before lunch, outside 20m window): standard countdown
        store.tick(now: makeDate(day: 25, hour: 11, minute: 45))
        let beforeWindow = store.mealSweetSpot
        #expect(beforeWindow.sweetSpotPrefix == "Around ")
        #expect(beforeWindow.highlightedClockTime == "12:30 PM")
        #expect(beforeWindow.progress != nil)

        // At 12:15 PM (within 20m of 12:30 PM lunch while nap is active): calm waiting state
        store.tick(now: makeDate(day: 25, hour: 12, minute: 15))
        let waitingLunch = store.mealSweetSpot
        #expect(waitingLunch.title == "Next meal")
        #expect(waitingLunch.primaryValue == "Lunch")
        #expect(waitingLunch.subtitle == "Last: Breakfast · 8:30 AM")
        #expect(waitingLunch.progress == nil)
        #expect(waitingLunch.isOver == false)
        #expect(waitingLunch.sweetSpotPrefix == "Waiting until after nap")
        #expect(waitingLunch.highlightedClockTime == nil)
        #expect(waitingLunch.sweetSpotSuffix == nil)
        #expect(waitingLunch.fullSweetSpotCaption == "Waiting until after nap")
        #expect(waitingLunch.suggestedMealSlot == .lunch)

        // Wake up at 12:40 PM: resumes normal lunch countdown
        store.tick(now: makeDate(day: 25, hour: 12, minute: 40))
        _ = store.toggleNap()
        #expect(store.isActiveNap == false)
        let afterNapLunch = store.mealSweetSpot
        #expect(afterNapLunch.sweetSpotPrefix == "Around ")
        #expect(afterNapLunch.highlightedClockTime == "12:30 PM")
        #expect(afterNapLunch.sweetSpotSuffix == " · 10m ago")
        #expect(afterNapLunch.isOver == true)
        #expect(afterNapLunch.progress != nil)
    }

    @Test("Nursing last-side tracking persists across pause, finish, overnight day boundary, and manual entry")
    func nursingLastSideTrackingAcrossDaysAndManualEntry() throws {
        let store = BlythesLifeStore.makeDemo()
        #expect(store.lastNursingSideInfo == nil)

        // 1. Live timer: Left -> Right -> Pause -> Finish records lastSide == .right
        let t0 = makeDate(day: 25, hour: 21, minute: 0)
        store.tick(now: t0)
        store.tapNursingSide(.left)
        #expect(store.activeNursing?.lastActiveSide == .left)

        store.tick(now: t0.addingTimeInterval(4 * 60))
        store.tapNursingSide(.right)
        #expect(store.activeNursing?.lastActiveSide == .right)

        store.tick(now: t0.addingTimeInterval(10 * 60))
        store.tapNursingSide(.right) // Pause
        #expect(store.activeNursing?.activeSide == nil)
        #expect(store.activeNursing?.lastActiveSide == .right)

        let finished = try #require(store.finishNursing())
        if case .feeding(let meta) = finished.metadata {
            #expect(meta.side == .both)
            #expect(meta.lastSide == .right)
        } else {
            Issue.record("Expected breast feeding metadata")
        }
        #expect(store.eventDetail(for: finished) == "10m · Left 4m, Right 6m · Ended right")

        // Advance to next morning (day 26, 6:30 AM): overnight feed still remembers yesterday's last side!
        let nextMorning = makeDate(day: 26, hour: 6, minute: 30)
        store.tick(now: nextMorning)
        let overnightInfo = try #require(store.lastNursingSideInfo)
        #expect(overnightInfo.side == .right)
        #expect(overnightInfo.at == t0.addingTimeInterval(10 * 60))

        // 2. Manual nursing with side: .both, lastSide: .left
        let manualBothStart = makeDate(day: 26, hour: 7, minute: 0)
        let manualBoth = store.logManualNursing(
            startedAt: manualBothStart,
            minutes: 15,
            side: .both,
            lastSide: .left
        )
        if case .feeding(let meta) = manualBoth.metadata {
            #expect(meta.side == .both)
            #expect(meta.lastSide == .left)
        } else {
            Issue.record("Expected breast feeding metadata")
        }
        #expect(store.eventDetail(for: manualBoth) == "15m · Both sides · Ended left")
        let afterManualBoth = try #require(store.lastNursingSideInfo)
        #expect(afterManualBoth.side == .left)
        #expect(afterManualBoth.at == manualBothStart.addingTimeInterval(15 * 60))

        // 3. Manual nursing with side: .left automatically records lastSide: .left without redundant "Ended left"
        let manualLeftStart = makeDate(day: 26, hour: 10, minute: 0)
        let manualLeft = store.logManualNursing(
            startedAt: manualLeftStart,
            minutes: 12,
            side: .left
        )
        if case .feeding(let meta) = manualLeft.metadata {
            #expect(meta.side == .left)
            #expect(meta.lastSide == .left)
        } else {
            Issue.record("Expected breast feeding metadata")
        }
        #expect(store.eventDetail(for: manualLeft) == "12m · Left side")

        // 4. Manual nursing with side: .both and lastSide: nil returns nil (does not fall back to stale prior feed)
        let manualUnknown = store.logManualNursing(
            startedAt: makeDate(day: 26, hour: 13, minute: 0),
            minutes: 14,
            side: .both,
            lastSide: nil
        )
        #expect(store.eventDetail(for: manualUnknown) == "14m · Both sides")
        #expect(store.lastNursingSideInfo == nil)

        // Pediatrician CSV reflects ended side on both-sides nursing rows
        let csv = store.exportPediatricianCSVString()
        #expect(csv.contains("\"10m · Left 4m, Right 6m · Ended right\""))
        #expect(csv.contains("15m · Both sides · Ended left,15m"))
    }

    @Test("Diaper logging stores optional poop color & consistency, strips them when poop is nil, and exports CSV cleanly")
    func diaperPoopColorAndConsistency() throws {
        let store = BlythesLifeStore.makeDemo()

        // 1. Pee + Poop with color & consistency
        let richPoop = store.logDiaper(
            startedAt: store.now,
            pee: .large,
            poop: .medium,
            rash: false,
            notes: "After breakfast",
            poopColor: .yellow,
            poopConsistency: .seedy
        )
        if case .diaper(let meta) = richPoop.metadata {
            #expect(meta.peeSize == .large)
            #expect(meta.poopSize == .medium)
            #expect(meta.poopColor == .yellow)
            #expect(meta.poopConsistency == .seedy)
            #expect(meta.rash == false)
        } else {
            Issue.record("Expected diaper metadata")
        }
        #expect(store.eventDetail(for: richPoop) == "Pee L · Poop M (Yellow, Seedy)")
        #expect(store.toast?.message == "Diaper logged · Pee L · Poop M (Yellow, Seedy)")

        // 2. Poop with color only + rash
        let colorOnly = store.logDiaper(
            startedAt: store.now.addingTimeInterval(60),
            pee: nil,
            poop: .small,
            rash: true,
            poopColor: .green
        )
        #expect(store.eventDetail(for: colorOnly) == "Poop S (Green) · Rash")

        // 3. Pee-only diaper strips dangling poopColor & poopConsistency
        let peeOnly = store.logDiaper(
            startedAt: store.now.addingTimeInterval(120),
            pee: .medium,
            poop: nil,
            rash: false,
            poopColor: .brown,
            poopConsistency: .soft
        )
        if case .diaper(let meta) = peeOnly.metadata {
            #expect(meta.peeSize == .medium)
            #expect(meta.poopSize == nil)
            #expect(meta.poopColor == nil)
            #expect(meta.poopConsistency == nil)
        } else {
            Issue.record("Expected diaper metadata")
        }
        #expect(store.eventDetail(for: peeOnly) == "Pee M")

        // 4. Pediatrician CSV quotes Details containing comma cleanly
        let csv = store.exportPediatricianCSVString()
        #expect(csv.contains("\"Pee L · Poop M (Yellow, Seedy)\""))
        #expect(csv.contains("Poop S (Green) · Rash"))
    }

    @Test("Pump timer dual-side lifecycle: simultaneous, pause/resume, Undo, discard, and manual durationMinutes")
    func pumpTimerAndManualDurationLifecycle() throws {
        let storage = InMemoryLocalStateStorage(initialState: SampleSeedData.makeDemoState())
        let store = BlythesLifeStore(
            storage: storage,
            apiClient: nil,
            tokenStore: InMemoryAuthTokenStorage(),
            initialNow: SampleSeedData.defaultReferenceDate
        )
        let t0 = store.now

        // Start timer via compatibility wrapper (both sides simultaneously)
        store.startOrTogglePumpTimer(side: .both)
        let started = try #require(store.activePump)
        #expect(started.isRunning == true)
        #expect(started.isBothRunning == true)
        #expect(started.derivedSide(asOf: t0) == .both)
        #expect(started.elapsedSeconds(asOf: t0) == (0, 0, 0))

        // Advance 5m, pause both
        store.tick(now: t0.addingTimeInterval(5 * 60))
        let at5m = try #require(store.activePump?.elapsedSeconds(asOf: store.now))
        #expect(at5m == (300, 300, 300))
        store.togglePumpBoth()
        #expect(store.activePump?.isRunning == false)
        #expect(store.activePump?.leftAccumulatedSeconds == 300)
        #expect(store.activePump?.rightAccumulatedSeconds == 300)
        #expect(store.activePump?.sessionAccumulatedSeconds == 300)

        // Verify persistence across reload
        let persisted = try #require(try storage.load())
        #expect(persisted.activePumpSession?.sessionAccumulatedSeconds == 300)
        #expect(persisted.activePumpSession?.leftAccumulatedSeconds == 300)
        #expect(persisted.activePumpSession?.rightAccumulatedSeconds == 300)

        // Advance 10m while paused -> elapsed must NOT increase
        store.tick(now: t0.addingTimeInterval(15 * 60))
        let whilePaused = try #require(store.activePump?.elapsedSeconds(asOf: store.now))
        #expect(whilePaused == (300, 300, 300))

        // Resume both and pump another 10m -> active time = 15m (NOT 30m!), wall clock span = 25m
        store.togglePumpBoth()
        #expect(store.activePump?.isRunning == true)
        #expect(store.activePump?.isBothRunning == true)
        store.tick(now: t0.addingTimeInterval(25 * 60))
        let at25m = try #require(store.activePump?.elapsedSeconds(asOf: store.now))
        #expect(at25m == (900, 900, 900))

        // Discard + Undo restores paused dual-side session with accumulated 900s
        store.discardPumpTimer()
        #expect(store.activePump == nil)
        #expect(store.toast?.message == "Pump timer discarded")
        store.undoLastToast()
        let restoredAfterDiscard = try #require(store.activePump)
        #expect(restoredAfterDiscard.isRunning == false)
        #expect(restoredAfterDiscard.leftAccumulatedSeconds == 900)
        #expect(restoredAfterDiscard.rightAccumulatedSeconds == 900)
        #expect(restoredAfterDiscard.sessionAccumulatedSeconds == 900)
        #expect(restoredAfterDiscard.leftSegmentStartedAt == nil)
        #expect(restoredAfterDiscard.rightSegmentStartedAt == nil)
        #expect(restoredAfterDiscard.sessionSegmentStartedAt == nil)

        // Finish WITH combined volume -> logs event + toast + Undo restores paused session
        let beforeCount = store.activeEvents.count
        let savedWithVolume = try #require(store.finishPumpTimer(amount: 4, unit: .oz, notes: "Morning pump"))
        #expect(store.activePump == nil)
        #expect(store.activeEvents.count == beforeCount + 1)
        #expect(store.toast?.message == "Pump logged · 4 oz · 15m")
        #expect(savedWithVolume.endedAt == t0.addingTimeInterval(25 * 60))
        if case .pump(let meta) = savedWithVolume.metadata {
            #expect(meta.side == .both)
            #expect(meta.durationMinutes == 15)
            #expect(meta.leftDurationSeconds == 900)
            #expect(meta.rightDurationSeconds == 900)
            #expect(meta.leftAmountMl == nil)
            #expect(meta.rightAmountMl == nil)
            #expect(abs((meta.amountOz ?? 0) - 4.0) < 0.01)
        } else {
            Issue.record("Expected pump metadata")
        }
        #expect(store.eventDetail(for: savedWithVolume) == "4 oz · 15m · Both sides")

        // CSV Duration column uses active 15m rather than 25m wall-clock span!
        let csvWithPausedPump = store.exportPediatricianCSVString()
        #expect(csvWithPausedPump.contains("4 oz · 15m · Both sides,15m,Morning pump"))

        // Undo finish restores paused activePump and removes event
        store.undoLastToast()
        #expect(store.activeEvents.count == beforeCount)
        #expect(store.activePump?.isRunning == false)
        #expect(store.activePump?.leftAccumulatedSeconds == 900)
        #expect(store.activePump?.rightAccumulatedSeconds == 900)
        #expect(store.activePump?.sessionAccumulatedSeconds == 900)

        // Finish WITHOUT volume (duration-only)
        let savedDurationOnly = try #require(store.finishPumpTimer())
        #expect(store.activePump == nil)
        #expect(store.toast?.message == "Pump logged · 15m")
        if case .pump(let meta) = savedDurationOnly.metadata {
            #expect(meta.amountMl == nil)
            #expect(meta.durationMinutes == 15)
            #expect(meta.side == .both)
            #expect(meta.leftDurationSeconds == 900)
            #expect(meta.rightDurationSeconds == 900)
        } else {
            Issue.record("Expected pump metadata")
        }
        #expect(store.eventDetail(for: savedDurationOnly) == "15m · Both sides")

        // Manual logPump with amount + durationMinutes sets endedAt & formats cleanly
        let manualStart = t0.addingTimeInterval(60 * 60)
        let manualWithBoth = store.logPump(
            startedAt: manualStart,
            amount: 4,
            unit: .oz,
            side: .both,
            durationMinutes: 15
        )
        #expect(manualWithBoth.endedAt == manualStart.addingTimeInterval(15 * 60))
        #expect(store.toast?.message == "Pump logged · 4 oz · 15m")
        #expect(store.eventDetail(for: manualWithBoth) == "4 oz · 15m · Both sides")

        // Manual logPump with amount == 0 and durationMinutes > 0 stores amountMl == nil
        let manualDurationOnly = store.logPump(
            startedAt: manualStart.addingTimeInterval(30 * 60),
            amount: 0,
            unit: .oz,
            side: .right,
            durationMinutes: 12
        )
        #expect(manualDurationOnly.endedAt == manualStart.addingTimeInterval(42 * 60))
        #expect(store.toast?.message == "Pump logged · 12m")
        if case .pump(let meta) = manualDurationOnly.metadata {
            #expect(meta.amountMl == nil)
            #expect(meta.durationMinutes == 12)
            #expect(meta.side == .right)
        } else {
            Issue.record("Expected pump metadata")
        }
        #expect(store.eventDetail(for: manualDurationOnly) == "12m · Right side")
    }

    @Test("Independent dual-side pump timer union-of-active-intervals math across all real-world pumping patterns")
    func dualSidePumpTimerUnionIntervalsMath() throws {
        // 1. Simultaneous double pump for 15m -> L=900, R=900, Session=900 (NOT 1800)
        do {
            let store = BlythesLifeStore.makeDemo()
            let t0 = store.now
            store.togglePumpBoth()
            store.tick(now: t0.addingTimeInterval(15 * 60))
            let elapsed = try #require(store.activePump?.elapsedSeconds(asOf: store.now))
            #expect(elapsed == (900, 900, 900))
            let saved = try #require(store.finishPumpTimer(leftAmount: 2.5, rightAmount: 1.5, unit: .oz))
            if case .pump(let meta) = saved.metadata {
                #expect(meta.side == .both)
                #expect(meta.durationMinutes == 15)
                #expect(meta.leftDurationSeconds == 900)
                #expect(meta.rightDurationSeconds == 900)
                #expect(abs((meta.amountOz ?? 0) - 4.0) < 0.01)
                #expect(abs((meta.leftAmountOz ?? 0) - 2.5) < 0.01)
                #expect(abs((meta.rightAmountOz ?? 0) - 1.5) < 0.01)
            } else {
                Issue.record("Expected pump metadata")
            }
            #expect(store.eventDetail(for: saved) == "4 oz · 15m · L 2.5 oz, R 1.5 oz")
        }

        // 2. Staggered finish: togglePumpBoth, pause Left at 12m, finish at 18m -> L=720, R=1080, Session=1080
        do {
            let store = BlythesLifeStore.makeDemo()
            let t0 = store.now
            store.togglePumpBoth()
            store.tick(now: t0.addingTimeInterval(12 * 60))
            store.tapPumpSide(.left)
            #expect(store.activePump?.isLeftRunning == false)
            #expect(store.activePump?.isRightRunning == true)
            #expect(store.activePump?.isRunning == true)
            #expect(store.activePump?.sessionSegmentStartedAt == t0)

            store.tick(now: t0.addingTimeInterval(18 * 60))
            let elapsed = try #require(store.activePump?.elapsedSeconds(asOf: store.now))
            #expect(elapsed == (720, 1080, 1080))
            #expect(store.activePump?.derivedSide(asOf: store.now) == .both)

            let saved = try #require(store.finishPumpTimer(leftAmount: 2.5, rightAmount: 1.5, unit: .oz))
            if case .pump(let meta) = saved.metadata {
                #expect(meta.side == .both)
                #expect(meta.durationMinutes == 18)
                #expect(meta.leftDurationSeconds == 720)
                #expect(meta.rightDurationSeconds == 1080)
                #expect(abs((meta.amountOz ?? 0) - 4.0) < 0.01)
            } else {
                Issue.record("Expected pump metadata")
            }
            #expect(store.eventDetail(for: saved) == "4 oz · 18m · L 2.5 oz (12m), R 1.5 oz (18m)")
            #expect(store.toast?.message == "Pump logged · 4 oz · 18m")

            // Undo restores exact paused staggered dual-side state
            store.undoLastToast()
            let restored = try #require(store.activePump)
            #expect(restored.isRunning == false)
            #expect(restored.leftAccumulatedSeconds == 720)
            #expect(restored.rightAccumulatedSeconds == 1080)
            #expect(restored.sessionAccumulatedSeconds == 1080)
        }

        // 3. Sequential single-side: Left 10m, pause Left, wait 2m, Right 10m, finish -> L=600, R=600, Session=1200 (20m)
        do {
            let store = BlythesLifeStore.makeDemo()
            let t0 = store.now
            store.tapPumpSide(.left)
            #expect(store.activePump?.isLeftRunning == true)
            #expect(store.activePump?.isRightRunning == false)
            store.tick(now: t0.addingTimeInterval(10 * 60))
            store.tapPumpSide(.left) // pause Left
            #expect(store.activePump?.isRunning == false)
            #expect(store.activePump?.sessionAccumulatedSeconds == 600)

            // Wait 2m while both paused
            store.tick(now: t0.addingTimeInterval(12 * 60))
            let afterRest = try #require(store.activePump?.elapsedSeconds(asOf: store.now))
            #expect(afterRest == (600, 0, 600))

            // Pump Right 10m
            store.tapPumpSide(.right)
            #expect(store.activePump?.isLeftRunning == false)
            #expect(store.activePump?.isRightRunning == true)
            store.tick(now: t0.addingTimeInterval(22 * 60))
            let afterRight = try #require(store.activePump?.elapsedSeconds(asOf: store.now))
            #expect(afterRight == (600, 600, 1200))

            let saved = try #require(store.finishPumpTimer())
            if case .pump(let meta) = saved.metadata {
                #expect(meta.side == .both)
                #expect(meta.durationMinutes == 20)
                #expect(meta.leftDurationSeconds == 600)
                #expect(meta.rightDurationSeconds == 600)
                #expect(meta.amountMl == nil)
            } else {
                Issue.record("Expected pump metadata")
            }
            #expect(store.eventDetail(for: saved) == "20m · Both sides")
        }

        // 4. Power pumping: Both 20m, pause 10m rest, resume Both 10m -> L=1800, R=1800, Session=1800 (30m)
        do {
            let store = BlythesLifeStore.makeDemo()
            let t0 = store.now
            store.togglePumpBoth()
            store.tick(now: t0.addingTimeInterval(20 * 60))
            store.togglePumpBoth() // pause rest
            #expect(store.activePump?.isRunning == false)
            store.tick(now: t0.addingTimeInterval(30 * 60))
            store.togglePumpBoth() // resume both
            #expect(store.activePump?.isBothRunning == true)
            store.tick(now: t0.addingTimeInterval(40 * 60))
            let powerElapsed = try #require(store.activePump?.elapsedSeconds(asOf: store.now))
            #expect(powerElapsed == (1800, 1800, 1800))

            let saved = try #require(store.finishPumpTimer(amount: 5, unit: .oz))
            if case .pump(let meta) = saved.metadata {
                #expect(meta.side == .both)
                #expect(meta.durationMinutes == 30)
                #expect(meta.leftDurationSeconds == 1800)
                #expect(meta.rightDurationSeconds == 1800)
            } else {
                Issue.record("Expected pump metadata")
            }
        }

        // 5. Single-side timer: Right 12m, finish with rightAmount: 2.5 -> side == .right, rightDurationSeconds == 720, leftDurationSeconds == nil
        do {
            let store = BlythesLifeStore.makeDemo()
            let t0 = store.now
            store.tapPumpSide(.right)
            #expect(store.activePump?.derivedSide(asOf: t0) == .right)
            store.tick(now: t0.addingTimeInterval(12 * 60))
            let singleRightElapsed = try #require(store.activePump?.elapsedSeconds(asOf: store.now))
            #expect(singleRightElapsed == (0, 720, 720))

            let saved = try #require(store.finishPumpTimer(rightAmount: 2.5, unit: .oz))
            if case .pump(let meta) = saved.metadata {
                #expect(meta.side == .right)
                #expect(meta.durationMinutes == 12)
                #expect(meta.leftDurationSeconds == nil)
                #expect(meta.rightDurationSeconds == 720)
                #expect(meta.leftAmountMl == nil)
                #expect(abs((meta.rightAmountOz ?? 0) - 2.5) < 0.01)
                #expect(abs((meta.amountOz ?? 0) - 2.5) < 0.01)
                #expect(meta.amountMl == meta.rightAmountMl)
            } else {
                Issue.record("Expected pump metadata")
            }
            #expect(store.eventDetail(for: saved) == "2.5 oz · 12m · Right side")
            #expect(store.toast?.message == "Pump logged · 2.5 oz · 12m")
        }

        // 6. Overlapping staggered: Left at t=0, Right at t=5m, pause Left at t=15m, pause Right at t=20m -> L=15m, R=15m, Session=20m
        do {
            let store = BlythesLifeStore.makeDemo()
            let t0 = store.now
            store.tapPumpSide(.left)
            store.tick(now: t0.addingTimeInterval(5 * 60))
            store.tapPumpSide(.right)
            #expect(store.activePump?.isBothRunning == true)
            #expect(store.activePump?.sessionSegmentStartedAt == t0)

            store.tick(now: t0.addingTimeInterval(15 * 60))
            store.tapPumpSide(.left) // pause Left; Right still running so sessionSegmentStartedAt stays t0
            #expect(store.activePump?.isLeftRunning == false)
            #expect(store.activePump?.isRightRunning == true)
            #expect(store.activePump?.sessionSegmentStartedAt == t0)

            store.tick(now: t0.addingTimeInterval(20 * 60))
            store.tapPumpSide(.right) // pause Right -> session flushes to 1200s
            #expect(store.activePump?.isRunning == false)
            let elapsed = try #require(store.activePump?.elapsedSeconds(asOf: store.now))
            #expect(elapsed == (900, 900, 1200))

            let saved = try #require(store.finishPumpTimer())
            if case .pump(let meta) = saved.metadata {
                #expect(meta.side == .both)
                #expect(meta.durationMinutes == 20)
                #expect(meta.leftDurationSeconds == 900)
                #expect(meta.rightDurationSeconds == 900)
            } else {
                Issue.record("Expected pump metadata")
            }
        }

        // 7. togglePumpBoth() pauses when only ONE side is running, then resumes BOTH
        do {
            let store = BlythesLifeStore.makeDemo()
            let t0 = store.now
            store.tapPumpSide(.left)
            store.tick(now: t0.addingTimeInterval(5 * 60))
            store.togglePumpBoth() // pauses Left (only running side)
            #expect(store.activePump?.isRunning == false)
            let pausedElapsed = try #require(store.activePump?.elapsedSeconds(asOf: store.now))
            #expect(pausedElapsed == (300, 0, 300))

            store.tick(now: t0.addingTimeInterval(10 * 60))
            store.togglePumpBoth() // resumes BOTH sides
            #expect(store.activePump?.isBothRunning == true)
            store.tick(now: t0.addingTimeInterval(20 * 60))
            let resumedElapsed = try #require(store.activePump?.elapsedSeconds(asOf: store.now))
            #expect(resumedElapsed == (900, 600, 900))
        }
    }

    @Test("Manual logPump supports per-side volumes, split durations with max(L,R), single-side, combined, and time-only")
    func manualPumpPermutationsAndFormatting() throws {
        let store = BlythesLifeStore.makeDemo()
        let base = store.now

        // 1. Per-side volumes + shared simultaneous duration
        let splitVolSharedDur = store.logPump(
            startedAt: base,
            unit: .oz,
            durationMinutes: 15,
            leftAmount: 2.5,
            rightAmount: 1.5
        )
        #expect(splitVolSharedDur.endedAt == base.addingTimeInterval(15 * 60))
        if case .pump(let meta) = splitVolSharedDur.metadata {
            #expect(meta.side == .both)
            #expect(meta.durationMinutes == 15)
            #expect(abs((meta.amountOz ?? 0) - 4.0) < 0.01)
            #expect(abs((meta.leftAmountOz ?? 0) - 2.5) < 0.01)
            #expect(abs((meta.rightAmountOz ?? 0) - 1.5) < 0.01)
            #expect(meta.leftDurationSeconds == nil)
            #expect(meta.rightDurationSeconds == nil)
        } else {
            Issue.record("Expected pump metadata")
        }
        #expect(store.toast?.message == "Pump logged · 4 oz · 15m")
        #expect(store.eventDetail(for: splitVolSharedDur) == "4 oz · 15m · L 2.5 oz, R 1.5 oz")

        // 2. Per-side volumes + split durations -> durationMinutes = max(12, 18) = 18
        let splitBoth = store.logPump(
            startedAt: base.addingTimeInterval(60),
            unit: .oz,
            leftAmount: 2.5,
            rightAmount: 1.5,
            leftDurationMinutes: 12,
            rightDurationMinutes: 18
        )
        #expect(splitBoth.endedAt == base.addingTimeInterval(60 + 18 * 60))
        if case .pump(let meta) = splitBoth.metadata {
            #expect(meta.side == .both)
            #expect(meta.durationMinutes == 18)
            #expect(meta.leftDurationSeconds == 720)
            #expect(meta.rightDurationSeconds == 1080)
            #expect(abs((meta.amountOz ?? 0) - 4.0) < 0.01)
            #expect(abs((meta.leftAmountOz ?? 0) - 2.5) < 0.01)
            #expect(abs((meta.rightAmountOz ?? 0) - 1.5) < 0.01)
        } else {
            Issue.record("Expected pump metadata")
        }
        #expect(store.toast?.message == "Pump logged · 4 oz · 18m")
        #expect(store.eventDetail(for: splitBoth) == "4 oz · 18m · L 2.5 oz (12m), R 1.5 oz (18m)")

        // 3. Single-side volume + duration -> derived side == .left
        let singleSideVolDur = store.logPump(
            startedAt: base.addingTimeInterval(120),
            unit: .oz,
            leftAmount: 2.5,
            leftDurationMinutes: 15
        )
        if case .pump(let meta) = singleSideVolDur.metadata {
            #expect(meta.side == .left)
            #expect(meta.durationMinutes == 15)
            #expect(meta.leftDurationSeconds == 900)
            #expect(meta.rightDurationSeconds == nil)
            #expect(abs((meta.amountOz ?? 0) - 2.5) < 0.01)
            #expect(abs((meta.leftAmountOz ?? 0) - 2.5) < 0.01)
            #expect(meta.rightAmountMl == nil)
        } else {
            Issue.record("Expected pump metadata")
        }
        #expect(store.eventDetail(for: singleSideVolDur) == "2.5 oz · 15m · Left side")

        // 4. Combined volume + duration -> side == .both, nil per-side amounts
        let combined = store.logPump(
            startedAt: base.addingTimeInterval(180),
            amount: 4,
            unit: .oz,
            durationMinutes: 15
        )
        if case .pump(let meta) = combined.metadata {
            #expect(meta.side == .both)
            #expect(meta.durationMinutes == 15)
            #expect(meta.leftAmountMl == nil)
            #expect(meta.rightAmountMl == nil)
            #expect(abs((meta.amountOz ?? 0) - 4.0) < 0.01)
        } else {
            Issue.record("Expected pump metadata")
        }
        #expect(store.eventDetail(for: combined) == "4 oz · 15m · Both sides")

        // 5. Time-only single-side -> side == .left, amountMl == nil
        let timeOnlyLeft = store.logPump(
            startedAt: base.addingTimeInterval(240),
            unit: .oz,
            leftDurationMinutes: 15
        )
        if case .pump(let meta) = timeOnlyLeft.metadata {
            #expect(meta.side == .left)
            #expect(meta.amountMl == nil)
            #expect(meta.durationMinutes == 15)
            #expect(meta.leftDurationSeconds == 900)
            #expect(meta.rightDurationSeconds == nil)
        } else {
            Issue.record("Expected pump metadata")
        }
        #expect(store.eventDetail(for: timeOnlyLeft) == "15m · Left side")

        // 6. Distinct durations only (combined amount) -> "4 oz · 18m · L 12m, R 18m"
        let combinedStaggeredDur = store.logPump(
            startedAt: base.addingTimeInterval(300),
            amount: 4,
            unit: .oz,
            leftDurationMinutes: 12,
            rightDurationMinutes: 18
        )
        #expect(store.eventDetail(for: combinedStaggeredDur) == "4 oz · 18m · L 12m, R 18m")

        // 7. Distinct durations only (no volume) + CSV fallback when durationMinutes & endedAt are nil
        let barePerSideDurEvent = EventDTO(
            id: UUID(),
            profileId: store.profile.id,
            eventType: .pump,
            startedAt: base.addingTimeInterval(360),
            endedAt: nil,
            timezone: store.profile.defaultTimezone,
            metadata: .pump(
                PumpMetadata(
                    amountMl: nil,
                    displayUnit: .oz,
                    side: .both,
                    durationMinutes: nil,
                    leftDurationSeconds: 720,
                    rightDurationSeconds: 1080
                )
            ),
            createdBy: store.currentUserId,
            updatedBy: store.currentUserId
        )
        #expect(FormattingHelpers.eventDetail(barePerSideDurEvent, preferredUnit: .oz) == "18m · L 12m, R 18m")

        // 8. mL preferred unit formats per-side amounts cleanly
        let mlSplit = store.logPump(
            startedAt: base.addingTimeInterval(420),
            unit: .ml,
            durationMinutes: 15,
            leftAmount: 75,
            rightAmount: 45
        )
        #expect(FormattingHelpers.eventDetail(mlSplit, preferredUnit: .ml) == "120 mL · 15m · L 75 mL, R 45 mL")
        #expect(store.toast?.message == "Pump logged · 120 mL · 15m")

        // Verify Pediatrician CSV quotes comma-containing pump details & falls back to max(leftSec, rightSec)
        let csv = DataPortabilityService.exportPediatricianCSV(
            events: [splitVolSharedDur, splitBoth, combinedStaggeredDur, barePerSideDurEvent],
            timezone: store.profile.defaultTimezone,
            preferredUnit: .oz
        )
        #expect(csv.contains("\"4 oz · 15m · L 2.5 oz, R 1.5 oz\",15m"))
        #expect(csv.contains("\"4 oz · 18m · L 2.5 oz (12m), R 1.5 oz (18m)\",18m"))
        #expect(csv.contains("\"4 oz · 18m · L 12m, R 18m\",18m"))
        #expect(csv.contains("\"18m · L 12m, R 18m\",18m"))
    }

    @Test("Manual nursing per-side logging supports Left only, Right only, Both with/without lastSide, and legacy overload")
    func manualNursingPerSidePermutations() throws {
        let store = BlythesLifeStore.makeDemo()
        let base = store.now

        // 1. Left only (L 12m, R 0)
        let leftOnly = store.logManualNursing(
            startedAt: base,
            leftMinutes: 12,
            rightMinutes: 0
        )
        #expect(leftOnly.endedAt == base.addingTimeInterval(12 * 60))
        #expect(store.toast?.message == "Nursing logged · 12m")
        if case .feeding(let meta) = leftOnly.metadata {
            #expect(meta.method == .breast)
            #expect(meta.side == .left)
            #expect(meta.lastSide == .left)
            #expect(meta.durationMinutes == 12)
            #expect(meta.leftDurationSeconds == 720)
            #expect(meta.rightDurationSeconds == nil)
        } else {
            Issue.record("Expected breast feeding metadata")
        }
        #expect(store.eventDetail(for: leftOnly) == "12m · Left side")

        // 2. Right only (L 0, R 10m)
        let rightOnly = store.logManualNursing(
            startedAt: base.addingTimeInterval(60),
            leftMinutes: 0,
            rightMinutes: 10
        )
        #expect(rightOnly.endedAt == base.addingTimeInterval(60 + 10 * 60))
        #expect(store.toast?.message == "Nursing logged · 10m")
        if case .feeding(let meta) = rightOnly.metadata {
            #expect(meta.side == .right)
            #expect(meta.lastSide == .right)
            #expect(meta.durationMinutes == 10)
            #expect(meta.leftDurationSeconds == nil)
            #expect(meta.rightDurationSeconds == 600)
        } else {
            Issue.record("Expected breast feeding metadata")
        }
        #expect(store.eventDetail(for: rightOnly) == "10m · Right side")

        // 3. Both sides (L 10m, R 8m, lastSide: .right)
        let bothWithLast = store.logManualNursing(
            startedAt: base.addingTimeInterval(120),
            leftMinutes: 10,
            rightMinutes: 8,
            lastSide: .right,
            notes: "Calm evening feed"
        )
        #expect(bothWithLast.endedAt == base.addingTimeInterval(120 + 18 * 60))
        #expect(store.toast?.message == "Nursing logged · 18m")
        if case .feeding(let meta) = bothWithLast.metadata {
            #expect(meta.side == .both)
            #expect(meta.lastSide == .right)
            #expect(meta.durationMinutes == 18)
            #expect(meta.leftDurationSeconds == 600)
            #expect(meta.rightDurationSeconds == 480)
        } else {
            Issue.record("Expected breast feeding metadata")
        }
        #expect(store.eventDetail(for: bothWithLast) == "18m · Left 10m, Right 8m · Ended right")
        #expect(store.lastNursingSideInfo?.side == .right)

        // 4. Both sides without lastSide (or invalid .both lastSide) resolves lastSide to nil
        let bothWithoutLast = store.logManualNursing(
            startedAt: base.addingTimeInterval(240),
            leftMinutes: 9,
            rightMinutes: 7,
            lastSide: .both
        )
        if case .feeding(let meta) = bothWithoutLast.metadata {
            #expect(meta.side == .both)
            #expect(meta.lastSide == nil)
            #expect(meta.durationMinutes == 16)
            #expect(meta.leftDurationSeconds == 540)
            #expect(meta.rightDurationSeconds == 420)
        } else {
            Issue.record("Expected breast feeding metadata")
        }
        #expect(store.eventDetail(for: bothWithoutLast) == "16m · Left 9m, Right 7m")

        // 5. Legacy single-duration overload populates leftDurationSeconds/rightDurationSeconds for single sides
        let legacyLeft = store.logManualNursing(
            startedAt: base.addingTimeInterval(300),
            minutes: 11,
            side: .left
        )
        if case .feeding(let meta) = legacyLeft.metadata {
            #expect(meta.leftDurationSeconds == 660)
            #expect(meta.rightDurationSeconds == nil)
        } else {
            Issue.record("Expected breast feeding metadata")
        }
        let legacyRight = store.logManualNursing(
            startedAt: base.addingTimeInterval(360),
            minutes: 9,
            side: .right
        )
        if case .feeding(let meta) = legacyRight.metadata {
            #expect(meta.leftDurationSeconds == nil)
            #expect(meta.rightDurationSeconds == 540)
        } else {
            Issue.record("Expected breast feeding metadata")
        }
    }

    @Test("activePump is cleared on sign-out, account deletion, expired session, demo preview transitions, and household switch")
    func activePumpClearedAcrossSessionAndHouseholdTransitions() async throws {
        // 1. Demo preview enter & exit
        let localStore = BlythesLifeStore.makeDemo()
        localStore.startOrTogglePumpTimer(side: .both)
        #expect(localStore.activePump != nil)
        localStore.enterDemoPreview()
        #expect(localStore.activePump == nil)

        localStore.startOrTogglePumpTimer(side: .left)
        #expect(localStore.activePump != nil)
        localStore.exitDemoPreview()
        #expect(localStore.activePump == nil)

        // 2. Sync signOutOnThisDevice
        localStore.startOrTogglePumpTimer(side: .right)
        #expect(localStore.activePump != nil)
        localStore.signOutOnThisDevice()
        #expect(localStore.activePump == nil)

        // 3. Async sign-out, delete account, expired session, and household switch
        let mockAPI = MockBackendAPI()
        let joinedHousehold = HouseholdDTO(
            id: UUID(),
            name: "Partner Household",
            inviteCode: "998877",
            createdBy: UUID(),
            role: .member
        )
        let joinedProfile = ProfileDTO(
            id: UUID(),
            householdId: joinedHousehold.id,
            displayName: "Blythe",
            defaultTimezone: SampleSeedData.defaultTimeZoneIdentifier,
            scheduleConfig: ScheduleConfig()
        )
        mockAPI.state.withLock {
            $0.joinHouseholdHandler = { _, _ in
                JoinHouseholdResponse(status: .approved, household: joinedHousehold)
            }
            $0.listProfilesHandler = { _ in [joinedProfile] }
        }

        let liveStore = BlythesLifeStore.makeDemo(
            apiClient: mockAPI,
            tokenStore: InMemoryAuthTokenStorage(
                initialTokens: StoredAuthTokens(
                    accessToken: "valid-token",
                    refreshToken: "valid-refresh",
                    expiresAt: Date().addingTimeInterval(3600),
                    deviceId: "device-1"
                )
            ),
            accessToken: "valid-token",
            refreshToken: "valid-refresh"
        )

        // Household switch clears activePump
        liveStore.startOrTogglePumpTimer(side: .both)
        #expect(liveStore.activePump != nil)
        try await liveStore.joinHouseholdAsync(inviteCode: "998877")
        #expect(liveStore.activePump == nil)

        // Async sign-out clears activePump
        liveStore.startOrTogglePumpTimer(side: .both)
        #expect(liveStore.activePump != nil)
        await liveStore.signOutOnThisDeviceAsync()
        #expect(liveStore.activePump == nil)

        // Account deletion clears activePump
        let deleteStore = BlythesLifeStore.makeDemo(
            apiClient: mockAPI,
            tokenStore: InMemoryAuthTokenStorage(
                initialTokens: StoredAuthTokens(
                    accessToken: "valid-token",
                    refreshToken: "valid-refresh",
                    expiresAt: Date().addingTimeInterval(3600),
                    deviceId: "device-2"
                )
            ),
            accessToken: "valid-token",
            refreshToken: "valid-refresh"
        )
        deleteStore.startOrTogglePumpTimer(side: .left)
        #expect(deleteStore.activePump != nil)
        try await deleteStore.deleteAccountAsync()
        #expect(deleteStore.activePump == nil)

        // Expired session clears activePump
        let expiredAPI = MockBackendAPI()
        expiredAPI.state.withLock {
            $0.syncPullHandler = { _, _, _ in throw BackendAPIError.unauthorized }
            $0.refreshHandler = { _ in throw BackendAPIError.unauthorized }
        }
        let expiredStore = BlythesLifeStore.makeDemo(
            apiClient: expiredAPI,
            tokenStore: InMemoryAuthTokenStorage(
                initialTokens: StoredAuthTokens(
                    accessToken: "expired-access",
                    refreshToken: "expired-refresh",
                    expiresAt: Date().addingTimeInterval(-60),
                    deviceId: "device-3"
                )
            ),
            accessToken: "expired-access",
            refreshToken: "expired-refresh"
        )
        expiredStore.startOrTogglePumpTimer(side: .both)
        #expect(expiredStore.activePump != nil)
        await expiredStore.pullFromServer()
        #expect(expiredStore.sessionStage == .signedOut)
        #expect(expiredStore.activePump == nil)
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
            state.joinHouseholdHandler = { req, _ in
                #expect(req.inviteCode == "882244")
                let joined = HouseholdDTO(
                    id: spouseHouseholdId,
                    name: "Blythe's household",
                    inviteCode: "882244",
                    createdBy: SampleSeedData.ownerUserId
                )
                return JoinHouseholdResponse(status: .approved, household: joined)
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
            state.joinHouseholdHandler = { req, _ in
                #expect(req.inviteCode == "482913")
                let joined = HouseholdDTO(
                    id: joinedHouseholdId,
                    name: "Blythe's household",
                    inviteCode: "482913",
                    createdBy: SampleSeedData.ownerUserId
                )
                return JoinHouseholdResponse(status: .approved, household: joined)
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

    @Test("Creating and revoking single-use invites updates household.activeInvites and formats XXXX-XXXX")
    func createAndRevokeHouseholdInvites() async throws {
        let mockAPI = MockBackendAPI()
        let tokenStore = InMemoryAuthTokenStorage(
            initialTokens: StoredAuthTokens(
                accessToken: "owner-jwt",
                refreshToken: "rt-owner",
                deviceId: "dev-owner"
            )
        )
        let store = BlythesLifeStore.makeDemo(apiClient: mockAPI, tokenStore: tokenStore)
        let householdId = store.household.id
        let newInviteId = UUID()
        let refNow = store.now

        mockAPI.state.withLock { state in
            state.createHouseholdInviteHandler = { hid, req, token in
                #expect(hid == householdId)
                #expect(token == "owner-jwt")
                #expect(req.label == "Grandma")
                #expect(req.role == .caregiver)
                #expect(req.ttlHours == 48)
                return HouseholdInviteDTO(
                    id: newInviteId,
                    householdId: hid,
                    code: "K7M9P4X2",
                    label: req.label,
                    role: req.role,
                    createdBy: SampleSeedData.ownerUserId,
                    createdAt: refNow,
                    expiresAt: refNow.addingTimeInterval(48 * 3600)
                )
            }
            state.revokeHouseholdInviteHandler = { hid, iid, token in
                #expect(hid == householdId)
                #expect(iid == newInviteId)
                #expect(token == "owner-jwt")
                return HouseholdDTO(
                    id: hid,
                    name: "Blythe's household",
                    inviteCode: "482913",
                    createdBy: SampleSeedData.ownerUserId,
                    role: .owner,
                    members: [
                        HouseholdMemberDTO(
                            householdId: hid,
                            userId: SampleSeedData.ownerUserId,
                            role: .owner,
                            displayName: "Brian"
                        )
                    ],
                    activeInvites: [],
                    pendingJoinRequests: []
                )
            }
        }

        let created = try await store.createHouseholdInviteAsync(
            label: "  Grandma  ",
            role: .caregiver,
            ttlHours: 48
        )
        #expect(created.id == newInviteId)
        #expect(FormattingHelpers.formatInviteCode(created.code) == "K7M9-P4X2")
        #expect(store.activeHouseholdInvites.contains(where: { $0.id == newInviteId }))
        #expect(store.toast?.message == "Invite created · K7M9-P4X2")

        // Verify expired/used/revoked invites are excluded from activeHouseholdInvites
        let expiredInvite = HouseholdInviteDTO(
            householdId: householdId,
            code: "AAAA1111",
            createdBy: SampleSeedData.ownerUserId,
            expiresAt: refNow.addingTimeInterval(-60)
        )
        let usedInvite = HouseholdInviteDTO(
            householdId: householdId,
            code: "BBBB2222",
            createdBy: SampleSeedData.ownerUserId,
            expiresAt: refNow.addingTimeInterval(3600),
            usedAt: refNow
        )
        let revokedInvite = HouseholdInviteDTO(
            householdId: householdId,
            code: "CCCC3333",
            createdBy: SampleSeedData.ownerUserId,
            expiresAt: refNow.addingTimeInterval(3600),
            revokedAt: refNow
        )
        store.household.activeInvites?.append(contentsOf: [expiredInvite, usedInvite, revokedInvite])
        #expect(!store.activeHouseholdInvites.contains(where: { $0.id == expiredInvite.id }))
        #expect(!store.activeHouseholdInvites.contains(where: { $0.id == usedInvite.id }))
        #expect(!store.activeHouseholdInvites.contains(where: { $0.id == revokedInvite.id }))

        try await store.revokeHouseholdInviteAsync(inviteId: newInviteId)
        #expect(store.activeHouseholdInvites.isEmpty)
        #expect(store.toast?.message == "Invite revoked")

        let calls = mockAPI.state.withLock { $0.recordedCalls }
        #expect(calls.contains("POST /v1/households/\(householdId.uuidString.lowercased())/invites"))
        #expect(
            calls.contains(
                "DELETE /v1/households/\(householdId.uuidString.lowercased())/invites/\(newInviteId.uuidString.lowercased())"
            )
        )
    }

    @Test("Pending join code transitions to awaitingApproval, then checkJoinApprovalStatusAsync handles approval and decline")
    func pendingJoinApprovalAndDeclineFlows() async throws {
        let mockAPI = MockBackendAPI()
        let tokenStore = InMemoryAuthTokenStorage(deviceId: "dev-caregiver")
        let storage = InMemoryLocalStateStorage()
        let caregiverId = UUID()
        let targetHouseholdId = UUID()
        let targetProfileId = UUID()
        let requestId = UUID()

        let pendingRequest = HouseholdJoinRequestDTO(
            id: requestId,
            householdId: targetHouseholdId,
            householdName: "Phan Family",
            inviteId: UUID(),
            userId: caregiverId,
            displayName: "Grandma",
            requestedRole: .caregiver,
            status: .pending,
            createdAt: makeDate(hour: 10, minute: 0)
        )
        let approvedHousehold = HouseholdDTO(
            id: targetHouseholdId,
            name: "Phan Family",
            createdBy: SampleSeedData.ownerUserId,
            role: .caregiver,
            members: [
                HouseholdMemberDTO(householdId: targetHouseholdId, userId: SampleSeedData.ownerUserId, role: .owner, displayName: "Brian"),
                HouseholdMemberDTO(householdId: targetHouseholdId, userId: caregiverId, role: .caregiver, displayName: "Grandma")
            ]
        )
        let targetProfile = ProfileDTO(
            id: targetProfileId,
            householdId: targetHouseholdId,
            displayName: "Blythe",
            defaultTimezone: "America/Los_Angeles"
        )
        let caregiverUser = UserDTO(id: caregiverId, displayName: "Grandma", primaryEmail: "grandma@example.com")

        mockAPI.state.withLock { state in
            state.signInHandler = { _ in
                AuthSessionResponse(
                    accessToken: "jwt-cg",
                    expiresIn: 900,
                    refreshToken: "rt-cg",
                    user: caregiverUser,
                    households: [],
                    pendingJoinRequests: []
                )
            }
            state.joinHouseholdHandler = { req, _ in
                #expect(req.inviteCode == "K7M9P4X2")
                #expect(req.displayName == "Grandma")
                return JoinHouseholdResponse(status: .pending, household: nil, joinRequest: pendingRequest)
            }
            state.meHandler = { _ in
                AuthMeResponse(user: caregiverUser, households: [])
            }
            state.listMyJoinRequestsHandler = { _ in
                [pendingRequest]
            }
        }

        let store = BlythesLifeStore(storage: storage, apiClient: mockAPI, tokenStore: tokenStore)
        try await store.completeAppleSignIn(identityToken: "jwt", rawNonce: "nonce")
        defer { store.stopRealtimeSync() }
        #expect(store.sessionStage == .needsHouseholdSetup)

        // 1. Submit 8-char hyphenated code -> enters .awaitingApproval
        try await store.joinHouseholdAsync(inviteCode: " k7m9-p4x2 ", displayName: "Grandma")
        #expect(store.sessionStage == .awaitingApproval)
        #expect(store.hasCompletedHouseholdSetup == false)
        #expect(store.pendingJoinRequest == pendingRequest)
        #expect(store.toast?.message == "Request sent · waiting for approval")

        // Verify relaunch restores .awaitingApproval from persisted state
        let relaunched = BlythesLifeStore(storage: storage, apiClient: mockAPI, tokenStore: tokenStore)
        #expect(relaunched.sessionStage == .awaitingApproval)
        #expect(relaunched.pendingJoinRequest == pendingRequest)

        // 2. Poll while still pending -> remains .awaitingApproval
        await store.checkJoinApprovalStatusAsync()
        #expect(store.sessionStage == .awaitingApproval)
        #expect(store.pendingJoinRequest?.id == requestId)

        // 3. Poll after owner declines -> returns to .needsHouseholdSetup with toast
        let declinedRequest = HouseholdJoinRequestDTO(
            id: requestId,
            householdId: targetHouseholdId,
            householdName: "Phan Family",
            userId: caregiverId,
            displayName: "Grandma",
            requestedRole: .caregiver,
            status: .declined,
            createdAt: makeDate(hour: 10, minute: 0),
            resolvedAt: makeDate(hour: 10, minute: 5)
        )
        mockAPI.state.withLock { state in
            state.listMyJoinRequestsHandler = { _ in [declinedRequest] }
        }
        await store.checkJoinApprovalStatusAsync()
        #expect(store.sessionStage == .needsHouseholdSetup)
        #expect(store.pendingJoinRequest == nil)
        #expect(store.toast?.message == "Join request was declined")

        // 4. Re-request and verify cancelPendingJoinRequestLocally returns to .needsHouseholdSetup
        try await store.joinHouseholdAsync(inviteCode: "K7M9-P4X2", displayName: "Grandma")
        #expect(store.sessionStage == .awaitingApproval)
        store.cancelPendingJoinRequestLocally()
        #expect(store.sessionStage == .needsHouseholdSetup)
        #expect(store.pendingJoinRequest == nil)

        // 5. Re-request and verify checkJoinApprovalStatusAsync transitions to .ready once approved
        try await store.joinHouseholdAsync(inviteCode: "K7M9-P4X2", displayName: "Grandma")
        #expect(store.sessionStage == .awaitingApproval)

        mockAPI.state.withLock { state in
            state.meHandler = { _ in
                AuthMeResponse(user: caregiverUser, households: [approvedHousehold])
            }
            state.listProfilesHandler = { _ in [targetProfile] }
            state.syncPullHandler = { _, _, _ in
                SyncPullResponse(events: [], profiles: [targetProfile], serverWatermark: Date(), hasMore: false)
            }
        }

        await store.checkJoinApprovalStatusAsync()
        #expect(store.sessionStage == .ready)
        #expect(store.hasCompletedHouseholdSetup == true)
        #expect(store.pendingJoinRequest == nil)
        #expect(store.household.id == targetHouseholdId)
        #expect(store.profile.id == targetProfileId)
        #expect(store.isCurrentUserHouseholdOwner == false)
        #expect(store.toast?.message == "Joined Phan Family")
    }

    @Test("completeAppleSignIn enters awaitingApproval when server returns pendingJoinRequests and no households")
    func completeAppleSignInRestoresAwaitingApproval() async throws {
        let mockAPI = MockBackendAPI()
        let tokenStore = InMemoryAuthTokenStorage(deviceId: "dev-pending-signin")
        let storage = InMemoryLocalStateStorage()
        let userId = UUID()
        let pending = HouseholdJoinRequestDTO(
            id: UUID(),
            householdId: UUID(),
            householdName: "Blythe's household",
            userId: userId,
            displayName: "Sarah",
            requestedRole: .member,
            status: .pending
        )

        mockAPI.state.withLock { state in
            state.signInHandler = { _ in
                AuthSessionResponse(
                    accessToken: "jwt-pending",
                    expiresIn: 900,
                    refreshToken: "rt-pending",
                    user: UserDTO(id: userId, displayName: "Sarah", primaryEmail: "sarah@example.com"),
                    households: [],
                    pendingJoinRequests: [pending]
                )
            }
        }

        let store = BlythesLifeStore(storage: storage, apiClient: mockAPI, tokenStore: tokenStore)
        try await store.completeAppleSignIn(identityToken: "jwt", rawNonce: "nonce")
        #expect(store.sessionStage == .awaitingApproval)
        #expect(store.hasCompletedHouseholdSetup == false)
        #expect(store.pendingJoinRequest == pending)
    }

    @Test("Owner approveJoinRequestAsync, declineJoinRequestAsync, removeHouseholdMemberAsync, and SSE refresh hit exact endpoints")
    func ownerApprovalDeclineMemberRemovalAndSSERefresh() async throws {
        let mockAPI = MockBackendAPI()
        let tokenStore = InMemoryAuthTokenStorage(
            initialTokens: StoredAuthTokens(
                accessToken: "owner-token",
                refreshToken: "rt-owner",
                deviceId: "dev-owner-mgmt"
            )
        )
        let store = BlythesLifeStore.makeDemo(apiClient: mockAPI, tokenStore: tokenStore)
        let householdId = store.household.id
        let approveReqId = UUID()
        let declineReqId = UUID()
        let newMemberId = UUID()
        let removedUserId = SampleSeedData.grandmaUserId

        let pendingApprove = HouseholdJoinRequestDTO(
            id: approveReqId,
            householdId: householdId,
            householdName: "Blythe's household",
            userId: newMemberId,
            displayName: "Aunt Maya",
            requestedRole: .caregiver,
            status: .pending
        )
        let pendingDecline = HouseholdJoinRequestDTO(
            id: declineReqId,
            householdId: householdId,
            householdName: "Blythe's household",
            userId: UUID(),
            displayName: "Unknown",
            requestedRole: .caregiver,
            status: .pending
        )

        store.household.pendingJoinRequests = [pendingApprove, pendingDecline]
        #expect(store.isCurrentUserHouseholdOwner == true)
        #expect(store.pendingHouseholdJoinRequests.count == 2)

        let afterApprove = HouseholdDTO(
            id: householdId,
            name: "Blythe's household",
            createdBy: SampleSeedData.ownerUserId,
            role: .owner,
            members: [
                HouseholdMemberDTO(householdId: householdId, userId: SampleSeedData.ownerUserId, role: .owner, displayName: "Brian"),
                HouseholdMemberDTO(householdId: householdId, userId: SampleSeedData.grandmaUserId, role: .caregiver, displayName: "Grandma"),
                HouseholdMemberDTO(householdId: householdId, userId: newMemberId, role: .caregiver, displayName: "Aunt Maya")
            ],
            activeInvites: [],
            pendingJoinRequests: [pendingDecline]
        )
        let afterDecline = HouseholdDTO(
            id: householdId,
            name: "Blythe's household",
            createdBy: SampleSeedData.ownerUserId,
            role: .owner,
            members: afterApprove.members,
            activeInvites: [],
            pendingJoinRequests: []
        )
        let afterRemove = HouseholdDTO(
            id: householdId,
            name: "Blythe's household",
            createdBy: SampleSeedData.ownerUserId,
            role: .owner,
            members: [
                HouseholdMemberDTO(householdId: householdId, userId: SampleSeedData.ownerUserId, role: .owner, displayName: "Brian"),
                HouseholdMemberDTO(householdId: householdId, userId: newMemberId, role: .caregiver, displayName: "Aunt Maya")
            ],
            activeInvites: [],
            pendingJoinRequests: []
        )
        let incomingReq = HouseholdJoinRequestDTO(
            id: UUID(),
            householdId: householdId,
            householdName: "Blythe's household",
            userId: UUID(),
            displayName: "Uncle Leo",
            requestedRole: .caregiver,
            status: .pending
        )
        let afterSSE = HouseholdDTO(
            id: householdId,
            name: "Blythe's household",
            createdBy: SampleSeedData.ownerUserId,
            role: .owner,
            members: afterRemove.members,
            activeInvites: [],
            pendingJoinRequests: [incomingReq]
        )

        mockAPI.state.withLock { state in
            state.approveJoinRequestHandler = { hid, rid, _ in
                #expect(hid == householdId)
                #expect(rid == approveReqId)
                return afterApprove
            }
            state.declineJoinRequestHandler = { hid, rid, _ in
                #expect(hid == householdId)
                #expect(rid == declineReqId)
                return afterDecline
            }
            state.removeHouseholdMemberHandler = { hid, uid, _ in
                #expect(hid == householdId)
                #expect(uid == removedUserId)
                return afterRemove
            }
            state.listHouseholdsHandler = { _ in [afterSSE] }
            state.syncStreamHandler = { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(
                        SyncStreamNotification(
                            householdId: householdId,
                            profileId: nil,
                            entityType: "household_join_requests",
                            entityId: incomingReq.id,
                            updatedAt: Date()
                        )
                    )
                    continuation.finish()
                }
            }
        }

        try await store.approveJoinRequestAsync(requestId: approveReqId)
        #expect(store.household.members?.contains(where: { $0.userId == newMemberId }) == true)
        #expect(store.pendingHouseholdJoinRequests.count == 1)
        #expect(store.toast?.message == "Aunt Maya joined the household")

        try await store.declineJoinRequestAsync(requestId: declineReqId)
        #expect(store.pendingHouseholdJoinRequests.isEmpty)
        #expect(store.toast?.message == "Request declined")

        try await store.removeHouseholdMemberAsync(userId: removedUserId)
        #expect(store.household.members?.contains(where: { $0.userId == removedUserId }) == false)
        #expect(store.toast?.message == "Member removed")

        // Verify SSE notification with entityType "household_join_requests" calls refreshHouseholdAsync()
        store.startRealtimeSync()
        defer { store.stopRealtimeSync() }
        for _ in 0 ..< 40 where store.pendingHouseholdJoinRequests.isEmpty {
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        #expect(store.pendingHouseholdJoinRequests.first?.id == incomingReq.id)

        let calls = mockAPI.state.withLock { $0.recordedCalls }
        #expect(
            calls.contains(
                "POST /v1/households/\(householdId.uuidString.lowercased())/join-requests/\(approveReqId.uuidString.lowercased())/approve"
            )
        )
        #expect(
            calls.contains(
                "POST /v1/households/\(householdId.uuidString.lowercased())/join-requests/\(declineReqId.uuidString.lowercased())/decline"
            )
        )
        #expect(
            calls.contains(
                "DELETE /v1/households/\(householdId.uuidString.lowercased())/members/\(removedUserId.uuidString.lowercased())"
            )
        )
        #expect(calls.contains("GET /v1/households"))
    }
}

// MARK: - URLSessionBackendAPIClient Exact Route Verification

@Suite("URLSessionBackendAPIClient Routes", .serialized)
struct URLSessionBackendAPIClientRouteTests {
    @Test("Every endpoint hits the exact live backend path and HTTP method")
    func verifiesExactLiveBackendRoutes() async throws {
        let householdId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let inviteId = UUID(uuidString: "22222222-3333-4444-5555-666666666666")!
        let joinRequestId = UUID(uuidString: "33333333-4444-5555-6666-777777777777")!
        let removedUserId = UUID(uuidString: "44444444-5555-6666-7777-888888888888")!
        let profileId = UUID(uuidString: "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")!
        let scanId = UUID(uuidString: "99999999-8888-7777-6666-555555555555")!
        let user = UserDTO(id: SampleSeedData.ownerUserId, displayName: "Brian", primaryEmail: "brian@icloud.com")
        let household = HouseholdDTO(id: householdId, name: "Blythe's household", inviteCode: "123456", createdBy: user.id)
        let invite = HouseholdInviteDTO(
            id: inviteId,
            householdId: householdId,
            code: "K7M9P4X2",
            label: "Grandma",
            role: .caregiver,
            createdBy: user.id,
            expiresAt: Date().addingTimeInterval(24 * 3600)
        )
        let joinRequest = HouseholdJoinRequestDTO(
            id: joinRequestId,
            householdId: householdId,
            householdName: "Blythe's household",
            inviteId: inviteId,
            userId: removedUserId,
            displayName: "Grandma",
            requestedRole: .caregiver,
            status: .pending
        )
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
            case ("POST", "/v1/households/\(householdId.uuidString.lowercased())/invites"):
                return (201, try! encoder.encode(invite), ["Content-Type": "application/json"])
            case ("POST", "/v1/households/join"):
                let payload = JoinHouseholdResponse(status: .pending, household: nil, joinRequest: joinRequest)
                return (202, try! encoder.encode(payload), ["Content-Type": "application/json"])
            case ("GET", "/v1/households/join-requests/mine"):
                return (200, try! encoder.encode([joinRequest]), ["Content-Type": "application/json"])
            case ("POST", "/v1/households"),
                 ("DELETE", "/v1/households/\(householdId.uuidString.lowercased())/invites/\(inviteId.uuidString.lowercased())"),
                 ("POST", "/v1/households/\(householdId.uuidString.lowercased())/join-requests/\(joinRequestId.uuidString.lowercased())/approve"),
                 ("POST", "/v1/households/\(householdId.uuidString.lowercased())/join-requests/\(joinRequestId.uuidString.lowercased())/decline"),
                 ("DELETE", "/v1/households/\(householdId.uuidString.lowercased())/members/\(removedUserId.uuidString.lowercased())"),
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
        let createdInvite = try await client.createHouseholdInvite(
            householdId: householdId,
            CreateHouseholdInviteRequest(label: "Grandma", role: .caregiver, ttlHours: 24),
            accessToken: token
        )
        #expect(createdInvite.id == inviteId)
        _ = try await client.revokeHouseholdInvite(householdId: householdId, inviteId: inviteId, accessToken: token)
        let joinResp = try await client.joinHousehold(
            JoinHouseholdRequest(inviteCode: "K7M9P4X2", displayName: "Grandma"),
            accessToken: token
        )
        #expect(joinResp.status == .pending)
        #expect(joinResp.joinRequest?.id == joinRequestId)
        let myJoinReqs = try await client.listMyJoinRequests(accessToken: token)
        #expect(myJoinReqs.count == 1)
        _ = try await client.approveJoinRequest(householdId: householdId, requestId: joinRequestId, accessToken: token)
        _ = try await client.declineJoinRequest(householdId: householdId, requestId: joinRequestId, accessToken: token)
        _ = try await client.removeHouseholdMember(householdId: householdId, userId: removedUserId, accessToken: token)
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
            "POST /v1/households/\(householdId.uuidString.lowercased())/invites",
            "DELETE /v1/households/\(householdId.uuidString.lowercased())/invites/\(inviteId.uuidString.lowercased())",
            "POST /v1/households/join",
            "GET /v1/households/join-requests/mine",
            "POST /v1/households/\(householdId.uuidString.lowercased())/join-requests/\(joinRequestId.uuidString.lowercased())/approve",
            "POST /v1/households/\(householdId.uuidString.lowercased())/join-requests/\(joinRequestId.uuidString.lowercased())/decline",
            "DELETE /v1/households/\(householdId.uuidString.lowercased())/members/\(removedUserId.uuidString.lowercased())",
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
        jsonObj.removeValue(forKey: "pendingJoinRequest")
        let legacyData = try JSONSerialization.data(withJSONObject: jsonObj)

        let decoded = try BlythesLifeJSONCoding.makeDecoder().decode(PersistedAppState.self, from: legacyData)
        #expect(decoded.hasCompletedHouseholdSetup == true)
        #expect(decoded.isDemoPreview == false)
        #expect(decoded.pendingJoinRequest == nil)
        #expect(decoded.activePumpSession == nil)
        #expect(decoded.profile.id == seed.profile.id)
        #expect(decoded.household.id == seed.household.id)
    }

    @Test("Legacy PersistedAppState missing activePumpSession, ActiveNursingSession missing lastActiveSide, and Build 3 ActivePumpSession JSON migrate cleanly")
    func legacyActiveSessionBackwardCompatibleDecode() throws {
        var seed = SampleSeedData.makeDemoState()
        let startedAt = makeDate(hour: 12, minute: 0)
        seed.activeNursingSession = ActiveNursingSession(
            startedAt: startedAt,
            leftAccumulatedSeconds: 180,
            rightAccumulatedSeconds: 60,
            activeSide: .right,
            activeSegmentStartedAt: startedAt.addingTimeInterval(180),
            lastActiveSide: .right
        )
        seed.activePumpSession = ActivePumpSession(
            startedAt: startedAt,
            leftAccumulatedSeconds: 420,
            rightAccumulatedSeconds: 300,
            leftSegmentStartedAt: nil,
            rightSegmentStartedAt: startedAt.addingTimeInterval(420),
            sessionAccumulatedSeconds: 420,
            sessionSegmentStartedAt: startedAt.addingTimeInterval(420)
        )

        let encoded = try BlythesLifeJSONCoding.makeEncoder().encode(seed)
        let roundTripped = try BlythesLifeJSONCoding.makeDecoder().decode(PersistedAppState.self, from: encoded)
        #expect(roundTripped.activeNursingSession?.lastActiveSide == .right)
        #expect(roundTripped.activePumpSession == seed.activePumpSession)

        // Strip newly added keys to simulate pre-upgrade on-disk state
        var jsonObj = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        jsonObj.removeValue(forKey: "activePumpSession")
        var nursingObj = try #require(jsonObj["activeNursingSession"] as? [String: Any])
        nursingObj.removeValue(forKey: "lastActiveSide")
        jsonObj["activeNursingSession"] = nursingObj

        let legacyData = try JSONSerialization.data(withJSONObject: jsonObj)
        let decoded = try BlythesLifeJSONCoding.makeDecoder().decode(PersistedAppState.self, from: legacyData)
        #expect(decoded.activePumpSession == nil)
        let decodedNursing = try #require(decoded.activeNursingSession)
        #expect(decodedNursing.leftAccumulatedSeconds == 180)
        #expect(decodedNursing.rightAccumulatedSeconds == 60)
        #expect(decodedNursing.activeSide == .right)
        #expect(decodedNursing.lastActiveSide == nil)

        // Legacy Build 3 ActivePumpSession JSON migration: paused left
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let startedISO = formatter.string(from: startedAt)
        let segISO = formatter.string(from: startedAt.addingTimeInterval(300))

        let legacyPausedLeftJSON = """
        {
          "startedAt": "\(startedISO)",
          "accumulatedSeconds": 420,
          "isRunning": false,
          "side": "left"
        }
        """
        let migratedLeft = try BlythesLifeJSONCoding.makeDecoder().decode(
            ActivePumpSession.self,
            from: Data(legacyPausedLeftJSON.utf8)
        )
        #expect(migratedLeft.startedAt == startedAt)
        #expect(migratedLeft.leftAccumulatedSeconds == 420)
        #expect(migratedLeft.rightAccumulatedSeconds == 0)
        #expect(migratedLeft.sessionAccumulatedSeconds == 420)
        #expect(migratedLeft.isRunning == false)
        #expect(migratedLeft.derivedSide(asOf: startedAt.addingTimeInterval(500)) == .left)
        #expect(migratedLeft.elapsedSeconds(asOf: startedAt.addingTimeInterval(500)) == (420, 0, 420))

        // Legacy Build 3 ActivePumpSession JSON migration: running both with activeSegmentStartedAt
        let legacyRunningBothJSON = """
        {
          "startedAt": "\(startedISO)",
          "accumulatedSeconds": 180,
          "isRunning": true,
          "activeSegmentStartedAt": "\(segISO)",
          "side": "both"
        }
        """
        let migratedBoth = try BlythesLifeJSONCoding.makeDecoder().decode(
            ActivePumpSession.self,
            from: Data(legacyRunningBothJSON.utf8)
        )
        #expect(migratedBoth.isRunning == true)
        #expect(migratedBoth.isBothRunning == true)
        #expect(migratedBoth.leftAccumulatedSeconds == 180)
        #expect(migratedBoth.rightAccumulatedSeconds == 180)
        #expect(migratedBoth.sessionAccumulatedSeconds == 180)
        #expect(migratedBoth.leftSegmentStartedAt == startedAt.addingTimeInterval(300))
        #expect(migratedBoth.rightSegmentStartedAt == startedAt.addingTimeInterval(300))
        #expect(migratedBoth.sessionSegmentStartedAt == startedAt.addingTimeInterval(300))
        #expect(migratedBoth.elapsedSeconds(asOf: startedAt.addingTimeInterval(420)) == (300, 300, 300))

        // Legacy Build 3 ActivePumpSession JSON migration: running right without activeSegmentStartedAt falls back to startedAt
        let legacyRunningRightJSON = """
        {
          "startedAt": "\(startedISO)",
          "accumulatedSeconds": 0,
          "isRunning": true,
          "side": "right"
        }
        """
        let migratedRight = try BlythesLifeJSONCoding.makeDecoder().decode(
            ActivePumpSession.self,
            from: Data(legacyRunningRightJSON.utf8)
        )
        #expect(migratedRight.isLeftRunning == false)
        #expect(migratedRight.isRightRunning == true)
        #expect(migratedRight.rightSegmentStartedAt == startedAt)
        #expect(migratedRight.sessionSegmentStartedAt == startedAt)
        #expect(migratedRight.derivedSide(asOf: startedAt.addingTimeInterval(60)) == .right)
        #expect(migratedRight.elapsedSeconds(asOf: startedAt.addingTimeInterval(60)) == (0, 60, 60))
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
