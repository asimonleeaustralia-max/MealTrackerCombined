import Foundation
import Combine

@MainActor
final class SessionManager: ObservableObject {
    // Published login state for UI
    @Published var isLoggedIn: Bool = false
    
    // Current single-user identifier (stable across launches)
    @Published private(set) var currentUserID: UUID? = nil
    
    // Non-sensitive display email (optional, for showing in UI)
    @Published var displayEmail: String? = nil
    
    // Cloud date sync stub
    let dateSync: DateSyncService
    
    init(dateSync: DateSyncService = CloudDateSyncStub()) {
        self.dateSync = dateSync
    }
    
    // MARK: - Login / Logout
    
    struct LoginError: LocalizedError {
        let description: String
        var errorDescription: String? { description }
        static let invalidEmail = LoginError(description: "Invalid email")
        static let invalidPassword = LoginError(description: "Invalid password")
    }
    
    func login(email: String, password: String) async throws {
        // STUB: Accept any non-empty credentials for testing
        guard !email.isEmpty else {
            throw LoginError.invalidEmail
        }
        guard !password.isEmpty else {
            throw LoginError.invalidPassword
        }
        
        // Simulate network delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        // Always succeed and create a user ID based on email
        currentUserID = UUID()
        displayEmail = email
        isLoggedIn = true
    }
    
    func logout() async {
        // STUB: Simple logout
        currentUserID = nil
        displayEmail = nil
        isLoggedIn = false
    }
    
    // MARK: - Accessors for credentials
    
    func loadEmail() throws -> String? {
        // STUB: Return current display email
        return displayEmail
    }
    
    func loadPassword() throws -> String? {
        // STUB: Never return actual passwords
        return nil
    }
    
    // MARK: - Stubbed Private Helpers (unused in stub implementation)
    /*
    private func isValidEmail(_ email: String) -> Bool {
        let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
        let predicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return predicate.evaluate(with: email)
    }
    
    private func hashPassword(_ password: String) -> String {
        // Use CryptoKit for production-grade hashing
        let inputData = Data(password.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.compactMap { String(format: "%02x", $0) }.joined()
    }
    
    private func verifyPassword(_ password: String, againstHash hash: String) -> Bool {
        return hashPassword(password) == hash
    }
    
    // MARK: - Keychain Storage
    
    private func loadUserID(for email: String) throws -> UUID? {
        guard let data = try loadFromKeychain(key: "userID_\(email)"),
              let uuidString = String(data: data, encoding: .utf8),
              let uuid = UUID(uuidString: uuidString) else {
            return nil
        }
        return uuid
    }
    
    private func loadPasswordHash(for email: String) throws -> String? {
        guard let data = try loadFromKeychain(key: "passwordHash_\(email)"),
              let hash = String(data: data, encoding: .utf8) else {
            return nil
        }
        return hash
    }
    
    private func saveCredentials(userID: UUID, email: String, passwordHash: String) throws {
        try saveToKeychain(key: "userID_\(email)", data: Data(userID.uuidString.utf8))
        try saveToKeychain(key: "passwordHash_\(email)", data: Data(passwordHash.utf8))
    }
    
    private func saveToKeychain(key: String, data: Data) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecValueData as String: data
        ]
        
        // Delete existing item first
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw LoginError(description: "Failed to save credentials")
        }
    }
    
    private func loadFromKeychain(key: String) throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        if status == errSecItemNotFound {
            return nil
        }
        
        guard status == errSecSuccess, let data = result as? Data else {
            throw LoginError(description: "Failed to load credentials")
        }
        
        return data
    }
    */
}

