import BlythesLifeShared
import Foundation

public enum BackendAPIError: Error, Sendable, Equatable, LocalizedError {
    case invalidURL
    case invalidResponse
    case unauthorized
    case httpError(statusCode: Int, message: String?)
    case decodingError(String)
    case encodingError(String)
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid backend request URL."
        case .invalidResponse:
            return "Unexpected response from server."
        case .unauthorized:
            return "Your session expired. Sign in again to continue syncing."
        case .httpError(let statusCode, let message):
            if let message, !message.isEmpty {
                return "Server error (\(statusCode)): \(message)"
            }
            return "Server returned HTTP \(statusCode)."
        case .decodingError(let details):
            return "Could not decode server response: \(details)"
        case .encodingError(let details):
            return "Could not encode request payload: \(details)"
        case .networkError(let details):
            return "Network error: \(details)"
        }
    }
}

/// Async API protocol targeting the Blythe's Life Swift/PostgreSQL backend.
public protocol BackendAPIProviding: Sendable {
    func signInWithApple(_ request: AppleAuthRequest) async throws -> AuthSessionResponse
    func refreshSession(_ request: RefreshTokenRequest) async throws -> AuthSessionResponse
    func logout(_ request: LogoutRequest, accessToken: String?) async throws
    func deleteAccount(accessToken: String) async throws

    func createHousehold(name: String, accessToken: String) async throws -> HouseholdDTO
    func joinHousehold(inviteCode: String, displayName: String?, accessToken: String) async throws -> HouseholdDTO
    func rotateInviteCode(householdId: UUID, accessToken: String) async throws -> HouseholdDTO

    func syncPush(_ request: SyncPushRequest, accessToken: String) async throws -> SyncPushResponse
    func syncPull(since: Date?, limit: Int, accessToken: String) async throws -> SyncPullResponse
    func syncStream(accessToken: String) -> AsyncThrowingStream<SyncStreamNotification, Error>

    func presignScan(_ request: PresignUploadRequest, accessToken: String) async throws -> PresignUploadResponse
    func uploadScanBytes(to uploadURL: URL, headers: [String: String], data: Data) async throws
    func extractScan(_ request: ExtractPaperScanRequest, accessToken: String) async throws -> PaperScanDTO
    func confirmScan(_ request: ConfirmPaperScanRequest, accessToken: String) async throws -> PaperScanDTO

    func exportJSON(accessToken: String) async throws -> Data
    func exportCSV(profileId: UUID?, accessToken: String) async throws -> Data
}

public extension BackendAPIProviding {
    func logout(_ request: LogoutRequest) async throws {
        try await logout(request, accessToken: nil)
    }

    func syncPull(since: Date?, accessToken: String) async throws -> SyncPullResponse {
        try await syncPull(since: since, limit: 500, accessToken: accessToken)
    }

    func exportCSV(accessToken: String) async throws -> Data {
        try await exportCSV(profileId: nil, accessToken: accessToken)
    }
}

/// Pure incremental Server-Sent Events parser for `GET /v1/sync/stream`.
public struct SyncSSEParser: Sendable {
    private var dataLines: [String] = []

    public init() {}

    /// Feeds a single line from an SSE stream. Returns a decoded `SyncStreamNotification` when an event frame completes.
    public mutating func feed(line: String) -> SyncStreamNotification? {
        let trimmed = line.trimmingCharacters(in: .newlines)

        // Blank line flushes buffered multi-line `data:` frame.
        if trimmed.isEmpty {
            return flush()
        }

        // Ignore SSE comments (`: keepalive`) and metadata fields (`event:`, `id:`, `retry:`).
        if trimmed.hasPrefix(":") {
            return nil
        }

        if trimmed.hasPrefix("data:") {
            var payload = String(trimmed.dropFirst(5))
            if payload.hasPrefix(" ") {
                payload.removeFirst()
            }
            // Fast path: single-line JSON payload decodes immediately for minimal latency.
            if dataLines.isEmpty, let decoded = Self.decodeNotification(from: payload) {
                return decoded
            }
            dataLines.append(payload)
        }
        return nil
    }

    /// Flushes any buffered `data:` lines at frame boundary or EOF.
    public mutating func flush() -> SyncStreamNotification? {
        guard !dataLines.isEmpty else { return nil }
        let joined = dataLines.joined(separator: "\n")
        dataLines.removeAll(keepingCapacity: true)
        return Self.decodeNotification(from: joined)
    }

    public static func decodeNotification(from jsonString: String) -> SyncStreamNotification? {
        let trimmed = jsonString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else { return nil }
        return try? BlythesLifeJSONCoding.makeDecoder().decode(SyncStreamNotification.self, from: data)
    }
}

/// Live `URLSession`-backed API client targeting `https://api.blythe.brianphan.dev` by default.
public final class URLSessionBackendAPIClient: BackendAPIProviding, Sendable {
    public static let defaultBaseURL = URL(string: "https://api.blythe.brianphan.dev")!

    public let baseURL: URL
    private let session: URLSession

    public init(
        baseURL: URL = URLSessionBackendAPIClient.defaultBaseURL,
        session: URLSession = .shared
    ) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Auth

    public func signInWithApple(_ request: AppleAuthRequest) async throws -> AuthSessionResponse {
        try await sendJSON(
            method: "POST",
            path: "/v1/auth/apple",
            body: request,
            accessToken: nil
        )
    }

    public func refreshSession(_ request: RefreshTokenRequest) async throws -> AuthSessionResponse {
        try await sendJSON(
            method: "POST",
            path: "/v1/auth/refresh",
            body: request,
            accessToken: nil
        )
    }

    public func logout(_ request: LogoutRequest, accessToken: String?) async throws {
        _ = try await sendEmptyResponse(
            method: "POST",
            path: "/v1/auth/logout",
            body: request,
            accessToken: accessToken
        )
    }

    public func deleteAccount(accessToken: String) async throws {
        _ = try await sendEmptyResponse(
            method: "DELETE",
            path: "/v1/auth/account",
            body: Optional<String>.none,
            accessToken: accessToken
        )
    }

    // MARK: - Households

    public func createHousehold(name: String, accessToken: String) async throws -> HouseholdDTO {
        try await sendJSON(
            method: "POST",
            path: "/v1/households",
            body: CreateHouseholdRequest(name: name),
            accessToken: accessToken
        )
    }

    public func joinHousehold(
        inviteCode: String,
        displayName: String?,
        accessToken: String
    ) async throws -> HouseholdDTO {
        try await sendJSON(
            method: "POST",
            path: "/v1/households/join",
            body: JoinHouseholdRequest(inviteCode: inviteCode, displayName: displayName),
            accessToken: accessToken
        )
    }

    public func rotateInviteCode(householdId: UUID, accessToken: String) async throws -> HouseholdDTO {
        try await sendJSON(
            method: "POST",
            path: "/v1/households/\(householdId.uuidString)/invite/rotate",
            body: Optional<String>.none,
            accessToken: accessToken
        )
    }

    // MARK: - Sync & SSE

    public func syncPush(_ request: SyncPushRequest, accessToken: String) async throws -> SyncPushResponse {
        try await sendJSON(
            method: "POST",
            path: "/v1/sync/push",
            body: request,
            accessToken: accessToken
        )
    }

    public func syncPull(since: Date?, limit: Int = 500, accessToken: String) async throws -> SyncPullResponse {
        var queryItems = [URLQueryItem(name: "limit", value: String(max(1, limit)))]
        if let since {
            queryItems.append(URLQueryItem(name: "since", value: BlythesLifeJSONCoding.formatISO8601(since)))
        }
        return try await sendJSON(
            method: "GET",
            path: "/v1/sync/pull",
            queryItems: queryItems,
            body: Optional<String>.none,
            accessToken: accessToken
        )
    }

    public func syncStream(accessToken: String) -> AsyncThrowingStream<SyncStreamNotification, Error> {
        let baseURL = self.baseURL
        let session = self.session

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard let url = Self.buildURL(baseURL: baseURL, path: "/v1/sync/stream", queryItems: []) else {
                        throw BackendAPIError.invalidURL
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.timeoutInterval = 3600
                    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
                    request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
                    request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

                    let (bytes, response) = try await session.bytes(for: request)
                    try Self.validateHTTPResponse(response, bodyData: nil)

                    var parser = SyncSSEParser()
                    for try await line in bytes.lines {
                        if Task.isCancelled { break }
                        if let notification = parser.feed(line: line) {
                            continuation.yield(notification)
                        }
                    }
                    if let trailing = parser.flush() {
                        continuation.yield(trailing)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch let error as BackendAPIError {
                    continuation.finish(throwing: error)
                } catch {
                    continuation.finish(throwing: BackendAPIError.networkError(error.localizedDescription))
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Paper Scans

    public func presignScan(_ request: PresignUploadRequest, accessToken: String) async throws -> PresignUploadResponse {
        try await sendJSON(
            method: "POST",
            path: "/v1/scans/presign",
            body: request,
            accessToken: accessToken
        )
    }

    public func uploadScanBytes(to uploadURL: URL, headers: [String: String], data: Data) async throws {
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.httpBody = data
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        }

        let (responseData, response): (Data, URLResponse)
        do {
            (responseData, response) = try await session.data(for: request)
        } catch {
            throw BackendAPIError.networkError(error.localizedDescription)
        }
        try Self.validateHTTPResponse(response, bodyData: responseData)
    }

    public func extractScan(_ request: ExtractPaperScanRequest, accessToken: String) async throws -> PaperScanDTO {
        try await sendJSON(
            method: "POST",
            path: "/v1/scans/extract",
            body: request,
            accessToken: accessToken
        )
    }

    public func confirmScan(_ request: ConfirmPaperScanRequest, accessToken: String) async throws -> PaperScanDTO {
        try await sendJSON(
            method: "POST",
            path: "/v1/scans/confirm",
            body: request,
            accessToken: accessToken
        )
    }

    // MARK: - Export

    public func exportJSON(accessToken: String) async throws -> Data {
        try await fetchRawData(
            method: "GET",
            path: "/v1/export/json",
            queryItems: [],
            accept: "application/json",
            accessToken: accessToken
        )
    }

    public func exportCSV(profileId: UUID?, accessToken: String) async throws -> Data {
        var queryItems: [URLQueryItem] = []
        if let profileId {
            queryItems.append(URLQueryItem(name: "profile_id", value: profileId.uuidString))
        }
        return try await fetchRawData(
            method: "GET",
            path: "/v1/export/csv",
            queryItems: queryItems,
            accept: "text/csv",
            accessToken: accessToken
        )
    }

    // MARK: - HTTP Helpers

    private func sendJSON<Body: Encodable, Response: Decodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem] = [],
        body: Body?,
        accessToken: String?
    ) async throws -> Response {
        let data = try await executeRequest(
            method: method,
            path: path,
            queryItems: queryItems,
            body: body,
            accept: "application/json",
            accessToken: accessToken
        )
        do {
            return try BlythesLifeJSONCoding.makeDecoder().decode(Response.self, from: data)
        } catch {
            throw BackendAPIError.decodingError(error.localizedDescription)
        }
    }

    private func sendEmptyResponse<Body: Encodable>(
        method: String,
        path: String,
        body: Body?,
        accessToken: String?
    ) async throws -> Data {
        try await executeRequest(
            method: method,
            path: path,
            queryItems: [],
            body: body,
            accept: "application/json",
            accessToken: accessToken
        )
    }

    private func fetchRawData(
        method: String,
        path: String,
        queryItems: [URLQueryItem],
        accept: String,
        accessToken: String
    ) async throws -> Data {
        try await executeRequest(
            method: method,
            path: path,
            queryItems: queryItems,
            body: Optional<String>.none,
            accept: accept,
            accessToken: accessToken
        )
    }

    private func executeRequest<Body: Encodable>(
        method: String,
        path: String,
        queryItems: [URLQueryItem],
        body: Body?,
        accept: String,
        accessToken: String?
    ) async throws -> Data {
        guard let url = Self.buildURL(baseURL: baseURL, path: path, queryItems: queryItems) else {
            throw BackendAPIError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(accept, forHTTPHeaderField: "Accept")
        if let accessToken {
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        }

        if let body {
            do {
                request.httpBody = try BlythesLifeJSONCoding.makeEncoder().encode(body)
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            } catch {
                throw BackendAPIError.encodingError(error.localizedDescription)
            }
        }

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw BackendAPIError.networkError(error.localizedDescription)
        }

        try Self.validateHTTPResponse(response, bodyData: data)
        return data
    }

    private static func buildURL(baseURL: URL, path: String, queryItems: [URLQueryItem]) -> URL? {
        let trimmedPath = path.hasPrefix("/") ? String(path.dropFirst()) : path
        let endpoint = baseURL.appendingPathComponent(trimmedPath)
        guard !queryItems.isEmpty else { return endpoint }
        guard var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: true) else {
            return nil
        }
        components.queryItems = queryItems
        return components.url
    }

    private static func validateHTTPResponse(_ response: URLResponse, bodyData: Data?) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw BackendAPIError.invalidResponse
        }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            if httpResponse.statusCode == 401 {
                throw BackendAPIError.unauthorized
            }
            let message = bodyData.flatMap { String(data: $0, encoding: .utf8) }?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw BackendAPIError.httpError(statusCode: httpResponse.statusCode, message: message)
        }
    }
}
