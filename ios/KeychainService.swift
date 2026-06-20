import Foundation
import Security

enum KeychainError: LocalizedError {
    case itemNotFound
    case duplicateItem
    case unexpectedData
    case unexpectedStatus(OSStatus)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:
            return NSLocalizedString("keychain.item_not_found", comment: "Keychain item not found")
        case .duplicateItem:
            return NSLocalizedString("keychain.duplicate_item", comment: "Keychain item already exists")
        case .unexpectedData:
            return NSLocalizedString("keychain.unexpected_data", comment: "Unexpected keychain data format")
        case .unexpectedStatus(let status):
            let fmt = NSLocalizedString("keychain.unexpected_status_fmt", comment: "Keychain error format")
            return String(format: fmt, status)
        }
    }
}

// Simple Keychain wrapper for generic password items.
// We store separate items for email and password, namespaced by a single-user ID.
struct KeychainService {
    // Use your bundle id; fallback if not available in some contexts (tests).
    private static var service: String = {
        if let id = Bundle.main.bundleIdentifier {
            return id + ".auth"
        }
        return "MealTracker.auth"
    }()

    enum Kind: String {
        case email
        case password
        // ready for tokens later:
        case accessToken
        case refreshToken
    }

    // MARK: - Stubbing Support
    
    /// Enable stubbing to use in-memory storage instead of Keychain (useful for testing)
    static var isStubbed: Bool = false
    
    /// In-memory storage for stubbed keychain operations
    /// Key format: "kind:userID"
    private static var stubbedStorage: [String: Data] = [:]
    
    /// Clear all stubbed data
    static func clearStubs() {
        stubbedStorage.removeAll()
    }
    
    private static func stubbedKey(kind: Kind, userID: UUID) -> String {
        return "\(kind.rawValue):\(userID.uuidString)"
    }

    // Build a query dictionary with common attributes
    private static func baseQuery(kind: Kind, userID: UUID) -> [String: Any] {
        let account = "\(kind.rawValue):\(userID.uuidString)"
        return [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            // ThisDeviceOnly prevents iCloud Keychain sync (more secure for auth secrets)
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
    }

    static func save(_ data: Data, kind: Kind, userID: UUID) throws {
        if isStubbed {
            let key = stubbedKey(kind: kind, userID: userID)
            if stubbedStorage[key] != nil {
                throw KeychainError.duplicateItem
            }
            stubbedStorage[key] = data
            return
        }
        
        var query = baseQuery(kind: kind, userID: userID)
        query[kSecValueData as String] = data

        let status = SecItemAdd(query as CFDictionary, nil)
        switch status {
        case errSecSuccess:
            return
        case errSecDuplicateItem:
            throw KeychainError.duplicateItem
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func update(_ data: Data, kind: Kind, userID: UUID) throws {
        if isStubbed {
            let key = stubbedKey(kind: kind, userID: userID)
            guard stubbedStorage[key] != nil else {
                throw KeychainError.itemNotFound
            }
            stubbedStorage[key] = data
            return
        }
        
        let query = baseQuery(kind: kind, userID: userID)
        let attrs: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, attrs as CFDictionary)
        switch status {
        case errSecSuccess:
            return
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func upsert(_ data: Data, kind: Kind, userID: UUID) throws {
        do {
            try save(data, kind: kind, userID: userID)
        } catch KeychainError.duplicateItem {
            try update(data, kind: kind, userID: userID)
        }
    }

    static func load(kind: Kind, userID: UUID) throws -> Data {
        if isStubbed {
            let key = stubbedKey(kind: kind, userID: userID)
            guard let data = stubbedStorage[key] else {
                throw KeychainError.itemNotFound
            }
            return data
        }
        
        var query = baseQuery(kind: kind, userID: userID)
        query[kSecReturnData as String] = kCFBooleanTrue
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        switch status {
        case errSecSuccess:
            guard let data = item as? Data else { throw KeychainError.unexpectedData }
            return data
        case errSecItemNotFound:
            throw KeychainError.itemNotFound
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func delete(kind: Kind, userID: UUID) throws {
        if isStubbed {
            let key = stubbedKey(kind: kind, userID: userID)
            stubbedStorage.removeValue(forKey: key)
            return
        }
        
        let query = baseQuery(kind: kind, userID: userID)
        let status = SecItemDelete(query as CFDictionary)
        switch status {
        case errSecSuccess, errSecItemNotFound:
            return
        default:
            throw KeychainError.unexpectedStatus(status)
        }
    }

    static func deleteAll(for userID: UUID) {
        [Kind.email, .password, .accessToken, .refreshToken].forEach { kind in
            _ = try? delete(kind: kind, userID: userID)
        }
    }
}

extension KeychainService {
    static func saveEmail(_ email: String, for userID: UUID) throws {
        try upsert(Data(email.utf8), kind: .email, userID: userID)
    }

    static func loadEmail(for userID: UUID) throws -> String {
        let data = try load(kind: .email, userID: userID)
        guard let s = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return s
    }

    static func savePassword(_ password: String, for userID: UUID) throws {
        try upsert(Data(password.utf8), kind: .password, userID: userID)
    }

    static func loadPassword(for userID: UUID) throws -> String {
        let data = try load(kind: .password, userID: userID)
        guard let s = String(data: data, encoding: .utf8) else {
            throw KeychainError.unexpectedData
        }
        return s
    }
}

