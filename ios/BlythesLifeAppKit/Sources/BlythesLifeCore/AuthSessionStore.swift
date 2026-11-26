import BlythesLifeShared
import CryptoKit
import Foundation
import os
import Security

/// Error thrown when Keychain persistence fails unexpectedly.
public enum KeychainAuthStorageError: Error, Sendable, Equatable, LocalizedError {
    case encodingFailed(String)
    case unexpectedStatus(OSStatus)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed(let details):
            return "Could not encode authentication tokens: \(details)"
        case .unexpectedStatus(let status):
            return "Keychain operation failed with status \(status)."
        }
    }
}

/// Persisted authentication token bundle stored in Apple Keychain.
public struct StoredAuthTokens: Codable, Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String
    public var expiresAt: Date?
    public var deviceId: String

    public init(
        accessToken: String,
        refreshToken: String,
        expiresAt: Date? = nil,
        deviceId: String
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.deviceId = deviceId
    }
}

/// Abstraction for secure storage of auth tokens and stable per-device identity.
public protocol AuthTokenStorage: Sendable {
    func load() -> StoredAuthTokens?
    func save(_ tokens: StoredAuthTokens) throws
    func clear() throws
    func loadOrCreateDeviceId() -> String
}

/// Keychain-backed token and device-identity store using `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`.
public final class KeychainAuthTokenStorage: AuthTokenStorage, Sendable {
    public static let defaultService = "dev.brianphan.blytheslife.auth"

    private static let tokensAccount = "auth_tokens"
    private static let deviceIdAccount = "device_id"

    public let service: String
    public let accessGroup: String?

    private let lock = OSAllocatedUnfairLock<String?>(initialState: nil)

    public init(
        service: String = KeychainAuthTokenStorage.defaultService,
        accessGroup: String? = nil
    ) {
        self.service = service
        self.accessGroup = accessGroup
    }

    public func load() -> StoredAuthTokens? {
        lock.withLock { _ in
            guard let data = readGenericPasswordData(account: Self.tokensAccount) else {
                return nil
            }
            return try? BlythesLifeJSONCoding.makeDecoder().decode(StoredAuthTokens.self, from: data)
        }
    }

    public func save(_ tokens: StoredAuthTokens) throws {
        let encoded: Data
        do {
            encoded = try BlythesLifeJSONCoding.makeEncoder().encode(tokens)
        } catch {
            throw KeychainAuthStorageError.encodingFailed(error.localizedDescription)
        }

        try lock.withLock { fallbackDeviceId in
            try upsertGenericPasswordData(encoded, account: Self.tokensAccount)
            if !tokens.deviceId.isEmpty {
                fallbackDeviceId = tokens.deviceId
                try? upsertGenericPasswordData(Data(tokens.deviceId.utf8), account: Self.deviceIdAccount)
            }
        }
    }

    public func clear() throws {
        try lock.withLock { _ in
            try deleteGenericPassword(account: Self.tokensAccount)
        }
    }

    public func loadOrCreateDeviceId() -> String {
        lock.withLock { fallbackDeviceId in
            if let data = readGenericPasswordData(account: Self.deviceIdAccount),
               let stored = String(data: data, encoding: .utf8),
               !stored.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            {
                fallbackDeviceId = stored
                return stored
            }

            if let cached = fallbackDeviceId, !cached.isEmpty {
                return cached
            }

            let generated = UUID().uuidString.lowercased()
            fallbackDeviceId = generated
            try? upsertGenericPasswordData(Data(generated.utf8), account: Self.deviceIdAccount)
            return generated
        }
    }

    // MARK: - Keychain Primitives

    private func baseQuery(account: String) -> [String: Any] {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        if let accessGroup, !accessGroup.isEmpty {
            query[kSecAttrAccessGroup as String] = accessGroup
        }
        return query
    }

    private func readGenericPasswordData(account: String) -> Data? {
        var query = baseQuery(account: account)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return data
    }

    private func upsertGenericPasswordData(_ data: Data, account: String) throws {
        let query = baseQuery(account: account)
        let updateAttributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, updateAttributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw KeychainAuthStorageError.unexpectedStatus(addStatus)
            }
            return
        }

        throw KeychainAuthStorageError.unexpectedStatus(updateStatus)
    }

    private func deleteGenericPassword(account: String) throws {
        let status = SecItemDelete(baseQuery(account: account) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainAuthStorageError.unexpectedStatus(status)
        }
    }
}

/// Deterministic in-memory auth token storage for unit tests and SwiftUI Previews.
public final class InMemoryAuthTokenStorage: AuthTokenStorage, Sendable {
    private struct State: Sendable {
        var tokens: StoredAuthTokens?
        var deviceId: String?
    }

    private let stateLock: OSAllocatedUnfairLock<State>

    public init(initialTokens: StoredAuthTokens? = nil, deviceId: String? = nil) {
        self.stateLock = OSAllocatedUnfairLock(
            initialState: State(
                tokens: initialTokens,
                deviceId: deviceId ?? initialTokens?.deviceId
            )
        )
    }

    public func load() -> StoredAuthTokens? {
        stateLock.withLock { $0.tokens }
    }

    public func save(_ tokens: StoredAuthTokens) throws {
        stateLock.withLock { state in
            state.tokens = tokens
            if !tokens.deviceId.isEmpty {
                state.deviceId = tokens.deviceId
            }
        }
    }

    public func clear() throws {
        stateLock.withLock { state in
            state.tokens = nil
        }
    }

    public func loadOrCreateDeviceId() -> String {
        stateLock.withLock { state in
            if let existing = state.deviceId, !existing.isEmpty {
                return existing
            }
            let generated = UUID().uuidString.lowercased()
            state.deviceId = generated
            return generated
        }
    }
}

/// Cryptographic nonce generator and SHA-256 hex digest helper for Sign in with Apple.
public enum AppleNonceGenerator: Sendable {
    /// 64 URL-safe characters (power of two so masking by `0x3F` has zero modulo bias).
    private static let charset: [UInt8] = Array(
        "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-_".utf8
    )
    private static let hexAlphabet: [UInt8] = Array("0123456789abcdef".utf8)

    /// Generates a cryptographically secure URL-safe raw nonce string of the requested length.
    public static func randomNonceString(length: Int = 32) -> String {
        guard length > 0 else { return "" }

        var randomBytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, randomBytes.count, &randomBytes)
        if status != errSecSuccess {
            var generator = SystemRandomNumberGenerator()
            for idx in randomBytes.indices {
                randomBytes[idx] = UInt8.random(in: UInt8.min ... UInt8.max, using: &generator)
            }
        }

        var output = [UInt8]()
        output.reserveCapacity(length)
        for byte in randomBytes {
            output.append(charset[Int(byte & 0x3F)])
        }
        return String(decoding: output, as: UTF8.self)
    }

    /// Computes a lowercase hexadecimal SHA-256 digest matching the backend's `TokenCrypto.sha256Hex`.
    public static func sha256Hex(_ input: String) -> String {
        let digest = SHA256.hash(data: Data(input.utf8))
        var output = [UInt8]()
        output.reserveCapacity(64)
        for byte in digest {
            output.append(hexAlphabet[Int(byte >> 4)])
            output.append(hexAlphabet[Int(byte & 0x0F)])
        }
        return String(decoding: output, as: UTF8.self)
    }
}
