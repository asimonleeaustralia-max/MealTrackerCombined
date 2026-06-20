//
//  TokenStore.swift
//  MealTracker
//
//  Stores the access/refresh JWT pair in the Keychain. Tokens are obtained at login
//  (before a stable user id is known), so they are namespaced under a fixed sentinel
//  account rather than the user id. Reuses the existing `KeychainService` so the same
//  access controls (kSecAttrAccessibleWhenUnlockedThisDeviceOnly) apply.
//

import Foundation

enum TokenStore {
    /// Fixed account namespace for auth tokens (not a real user id).
    private static let account = UUID(uuidString: "00000000-0000-0000-0000-0000000A0A0A")!

    static func save(_ pair: TokenPair) {
        try? KeychainService.upsert(Data(pair.accessToken.utf8), kind: .accessToken, userID: account)
        try? KeychainService.upsert(Data(pair.refreshToken.utf8), kind: .refreshToken, userID: account)
    }

    static func saveAccessToken(_ token: String) {
        try? KeychainService.upsert(Data(token.utf8), kind: .accessToken, userID: account)
    }

    static var accessToken: String? {
        guard let data = try? KeychainService.load(kind: .accessToken, userID: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static var refreshToken: String? {
        guard let data = try? KeychainService.load(kind: .refreshToken, userID: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static var hasSession: Bool { refreshToken != nil }

    static func clear() {
        try? KeychainService.delete(kind: .accessToken, userID: account)
        try? KeychainService.delete(kind: .refreshToken, userID: account)
    }
}
