//
//  APIConfig.swift
//  MealTracker
//
//  Resolves the meal-tracker-web API gateway base URL.
//
//  Resolution order:
//    1. A runtime override stored in UserDefaults under "apiBaseURL"
//       (set from Settings → Account → Server, handy for LAN device testing).
//    2. The `API_BASE_URL` key in Info.plist (set per build configuration).
//    3. A compiled-in default: localhost for DEBUG, production otherwise.
//

import Foundation

enum APIConfig {
    static let baseURLDefaultsKey = "apiBaseURL"

    /// Compiled-in fallback. Update the production host to your real gateway FQDN
    /// (Bicep output `gatewayFqdn`, e.g. https://api.macrossimple.com).
    private static var compiledDefault: URL {
        #if DEBUG
        return URL(string: "http://localhost:8080")!
        #else
        return URL(string: "https://api.macrossimple.com")!
        #endif
    }

    static var baseURL: URL {
        if let s = UserDefaults.standard.string(forKey: baseURLDefaultsKey),
           let u = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines)),
           u.scheme != nil {
            return u
        }
        if let s = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           let u = URL(string: s), u.scheme != nil {
            return u
        }
        return compiledDefault
    }

    /// Persist a runtime override. Pass `nil` to clear and fall back to Info.plist/default.
    static func setBaseURLOverride(_ string: String?) {
        let defaults = UserDefaults.standard
        if let string, !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            defaults.set(string.trimmingCharacters(in: .whitespacesAndNewlines), forKey: baseURLDefaultsKey)
        } else {
            defaults.removeObject(forKey: baseURLDefaultsKey)
        }
    }

    static func url(path: String, query: [URLQueryItem] = []) -> URL {
        var components = URLComponents(
            url: baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: false
        )!
        if !query.isEmpty { components.queryItems = query }
        return components.url!
    }
}
