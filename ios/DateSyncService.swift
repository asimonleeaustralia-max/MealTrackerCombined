import Foundation

protocol DateSyncService {
    func getSyncedDate() async throws -> Date?
    func setSyncedDate(_ date: Date?) async throws
}

// A development stub that pretends to sync with "the cloud".
// Priority:
// - If iCloud KVS is available and user is logged into iCloud, use NSUbiquitousKeyValueStore
// - Otherwise fall back to UserDefaults so behavior is deterministic during development
final class CloudDateSyncStub: DateSyncService {
    private let kvsKey = "cloud_stub_synced_date_iso8601"
    private let userDefaultsKey = "cloud_stub_synced_date_iso8601_local"
    private let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private var ubiquitous: NSUbiquitousKeyValueStore? {
        NSUbiquitousKeyValueStore.default
    }

    private var useUbiquitous: Bool {
        // We optimistically try to use NSUbiquitousKeyValueStore; if not available, fallback will handle it.
        return true
    }

    func getSyncedDate() async throws -> Date? {
        if useUbiquitous {
            let store = ubiquitous
            // synchronize() is not strictly necessary, but helps ensure latest values during development
            store?.synchronize()
            if let s = store?.string(forKey: kvsKey), let d = iso8601.date(from: s) {
                return d
            }
        }
        if let s = UserDefaults.standard.string(forKey: userDefaultsKey), let d = iso8601.date(from: s) {
            return d
        }
        return nil
    }

    func setSyncedDate(_ date: Date?) async throws {
        let string: String? = date.map { iso8601.string(from: $0) }
        if useUbiquitous {
            let store = ubiquitous
            if let string {
                store?.set(string, forKey: kvsKey)
            } else {
                store?.removeObject(forKey: kvsKey)
            }
            store?.synchronize()
        }
        if let string {
            UserDefaults.standard.set(string, forKey: userDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: userDefaultsKey)
        }
    }
}

