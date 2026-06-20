import Foundation
import Combine
import CoreData

/// Owns authentication state and bridges login/logout to the meal-tracker-web backend.
///
/// Replaces the former local stub: credentials are now verified by the auth-service via
/// `MealTrackerAPI`, the JWT pair is stored in the Keychain (`TokenStore`), and a sync is
/// kicked off after a successful sign-in so cloud meals appear on the device.
@MainActor
final class SessionManager: ObservableObject {
    // Published login state for UI
    @Published var isLoggedIn: Bool = false

    // Current single-user identifier (stable across launches once known)
    @Published private(set) var currentUserID: UUID? = nil

    // Non-sensitive display email (optional, for showing in UI)
    @Published var displayEmail: String? = nil

    // True while a network auth call is in flight
    @Published private(set) var isAuthenticating: Bool = false

    // Cloud date sync stub (kept for the existing Settings "synced date" affordance)
    let dateSync: DateSyncService

    private let api = MealTrackerAPI.shared

    init(dateSync: DateSyncService = CloudDateSyncStub()) {
        self.dateSync = dateSync
    }

    // MARK: - Errors

    struct LoginError: LocalizedError {
        let description: String
        var errorDescription: String? { description }
        static let invalidEmail = LoginError(description: NSLocalizedString("login.error.invalid_email", comment: "Invalid email"))
        static let invalidPassword = LoginError(description: NSLocalizedString("login.error.invalid_password", comment: "Invalid password"))
    }

    // MARK: - Session restore

    /// Call once at launch. If a refresh token is present, validate it against `/auth/me`
    /// (refreshing transparently if the access token expired) and restore the session.
    func restoreSession() async {
        guard TokenStore.hasSession else { return }
        do {
            let user = try await api.me()
            applyUser(user)
            isLoggedIn = true
            SyncCoordinator.shared.requestSync()
        } catch APIError.notAuthenticated {
            TokenStore.clear()
        } catch {
            // Network hiccup at launch — keep tokens, stay logged out until next attempt.
        }
    }

    // MARK: - Login / Signup / Logout

    func login(email: String, password: String) async throws {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { throw LoginError.invalidEmail }
        guard !password.isEmpty else { throw LoginError.invalidPassword }

        isAuthenticating = true
        defer { isAuthenticating = false }

        _ = try await api.login(email: email, password: password)
        let user = try await api.me()
        applyUser(user)
        displayEmail = user.email ?? email
        isLoggedIn = true
        SyncCoordinator.shared.requestSync()
    }

    func signup(email: String, password: String, displayName: String? = nil) async throws {
        let email = email.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !email.isEmpty else { throw LoginError.invalidEmail }
        guard !password.isEmpty else { throw LoginError.invalidPassword }

        isAuthenticating = true
        defer { isAuthenticating = false }

        _ = try await api.signup(email: email, password: password, displayName: displayName)
        let user = try await api.me()
        applyUser(user)
        displayEmail = user.email ?? email
        isLoggedIn = true
        SyncCoordinator.shared.requestSync()
    }

    func logout() async {
        TokenStore.clear()
        SyncCoordinator.shared.resetSyncState()
        currentUserID = nil
        displayEmail = nil
        isLoggedIn = false
    }

    // MARK: - Helpers

    private func applyUser(_ user: UserPublic) {
        currentUserID = UUID(uuidString: user.id)
        if let email = user.email { displayEmail = email }
    }

    func loadEmail() throws -> String? { displayEmail }

    /// Passwords are never stored on-device any more (auth is token-based).
    func loadPassword() throws -> String? { nil }
}
