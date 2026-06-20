//
//  MealTrackerAPI.swift
//  MealTracker
//
//  Thin async client for the meal-tracker-web API gateway.
//  Handles email/password auth, automatic access-token refresh on 401, and the
//  meal / person / unified-sync endpoints used by `SyncCoordinator`.
//
//  Endpoints (all relative to the gateway base URL):
//    POST /api/auth/signup            -> TokenPair
//    POST /api/auth/login             -> TokenPair
//    POST /api/auth/refresh           -> TokenPair
//    GET  /api/auth/me                -> UserPublic
//    GET  /api/meals?since=           -> [Meal JSON]
//    PUT  /api/meals/{id}             -> Meal JSON
//    DELETE /api/meals/{id}
//    GET  /api/people?since=          -> [Person JSON]
//    PUT  /api/people/{id}            -> Person JSON
//    DELETE /api/people/{id}
//    GET  /api/sync/changes?since=    -> { meals, people, photos, server_time }
//

import Foundation

enum APIError: LocalizedError {
    case notAuthenticated
    case http(status: Int, message: String)
    case decoding(String)
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return NSLocalizedString("auth.error.not_authenticated", comment: "Not signed in")
        case .http(let status, let message):
            if status == 401 { return NSLocalizedString("auth.error.invalid_credentials", comment: "Invalid email or password") }
            return message.isEmpty ? "Request failed (HTTP \(status))" : message
        case .decoding(let m):
            return "Unexpected server response: \(m)"
        case .transport(let m):
            return m
        }
    }
}

actor MealTrackerAPI {
    static let shared = MealTrackerAPI()

    private let session: URLSession
    private let client = "ios"

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let config = URLSessionConfiguration.default
            config.timeoutIntervalForRequest = 30
            config.waitsForConnectivity = true
            self.session = URLSession(configuration: config)
        }
    }

    // MARK: - Auth

    func signup(email: String, password: String, displayName: String? = nil) async throws -> TokenPair {
        var payload: [String: Any] = ["email": email, "password": password, "client": client]
        if let displayName, !displayName.isEmpty { payload["display_name"] = displayName }
        let pair: TokenPair = try await postJSON(path: "api/auth/signup", body: payload, authorized: false)
        TokenStore.save(pair)
        return pair
    }

    func login(email: String, password: String) async throws -> TokenPair {
        let payload: [String: Any] = ["email": email, "password": password, "client": client]
        let pair: TokenPair = try await postJSON(path: "api/auth/login", body: payload, authorized: false)
        TokenStore.save(pair)
        return pair
    }

    @discardableResult
    func refresh() async throws -> TokenPair {
        guard let refreshToken = TokenStore.refreshToken else { throw APIError.notAuthenticated }
        let payload: [String: Any] = ["refresh_token": refreshToken]
        let pair: TokenPair = try await postJSON(path: "api/auth/refresh", body: payload, authorized: false)
        TokenStore.save(pair)
        return pair
    }

    func me() async throws -> UserPublic {
        let data = try await authorizedData(method: "GET", path: "api/auth/me")
        return try decode(UserPublic.self, from: data)
    }

    // MARK: - Meals

    /// Returns raw meal JSON objects (so `MealCodec` can apply them via KVC).
    func listMeals(since: Date?) async throws -> [[String: Any]] {
        var query: [URLQueryItem] = [URLQueryItem(name: "limit", value: "1000")]
        if let since { query.append(URLQueryItem(name: "since", value: CloudDate.string(from: since))) }
        let data = try await authorizedData(method: "GET", path: "api/meals", query: query)
        return try jsonArray(data)
    }

    @discardableResult
    func putMeal(id: UUID, body: [String: Any]) async throws -> [String: Any] {
        let data = try await authorizedData(method: "PUT", path: "api/meals/\(id.uuidString)", jsonBody: body)
        return try jsonObject(data)
    }

    func deleteMeal(id: UUID) async throws {
        _ = try await authorizedData(method: "DELETE", path: "api/meals/\(id.uuidString)")
    }

    // MARK: - People

    func listPeople(since: Date?) async throws -> [PersonDTO] {
        var query: [URLQueryItem] = []
        if let since { query.append(URLQueryItem(name: "since", value: CloudDate.string(from: since))) }
        let data = try await authorizedData(method: "GET", path: "api/people", query: query)
        return try decode([PersonDTO].self, from: data)
    }

    @discardableResult
    func putPerson(_ person: PersonDTO) async throws -> PersonDTO {
        guard let id = person.id, let uuid = UUID(uuidString: id) else { throw APIError.transport("Person missing id") }
        let body: [String: Any] = [
            "name": person.name,
            "is_default": person.isDefault,
            "is_removed": person.isRemoved,
        ]
        let data = try await authorizedData(method: "PUT", path: "api/people/\(uuid.uuidString)", jsonBody: body)
        return try decode(PersonDTO.self, from: data)
    }

    func deletePerson(id: UUID) async throws {
        _ = try await authorizedData(method: "DELETE", path: "api/people/\(id.uuidString)")
    }

    // MARK: - Unified sync

    struct SyncChanges {
        let meals: [[String: Any]]
        let people: [PersonDTO]
        let photos: [[String: Any]]
        let serverTime: Date
    }

    func syncChanges(since: Date) async throws -> SyncChanges {
        let query = [URLQueryItem(name: "since", value: CloudDate.string(from: since))]
        let data = try await authorizedData(method: "GET", path: "api/sync/changes", query: query)
        let obj = try jsonObject(data)
        let meals = (obj["meals"] as? [[String: Any]]) ?? []
        let photos = (obj["photos"] as? [[String: Any]]) ?? []
        let people: [PersonDTO]
        if let peopleData = try? JSONSerialization.data(withJSONObject: obj["people"] ?? []) {
            people = (try? decode([PersonDTO].self, from: peopleData)) ?? []
        } else {
            people = []
        }
        let serverTime = CloudDate.parse(obj["server_time"] as? String) ?? Date()
        return SyncChanges(meals: meals, people: people, photos: photos, serverTime: serverTime)
    }

    // MARK: - Request plumbing

    private func postJSON<T: Decodable>(path: String, body: [String: Any], authorized: Bool) async throws -> T {
        let data: Data
        if authorized {
            data = try await authorizedData(method: "POST", path: path, jsonBody: body)
        } else {
            var request = URLRequest(url: APIConfig.url(path: path))
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            data = try await perform(request)
        }
        return try decode(T.self, from: data)
    }

    /// Performs an authorized request, transparently refreshing the access token once
    /// on a 401 and retrying.
    @discardableResult
    private func authorizedData(
        method: String,
        path: String,
        query: [URLQueryItem] = [],
        jsonBody: [String: Any]? = nil
    ) async throws -> Data {
        guard let access = TokenStore.accessToken else { throw APIError.notAuthenticated }

        func build(_ token: String) throws -> URLRequest {
            var request = URLRequest(url: APIConfig.url(path: path, query: query))
            request.httpMethod = method
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            if let jsonBody {
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                request.httpBody = try JSONSerialization.data(withJSONObject: jsonBody)
            }
            return request
        }

        do {
            return try await perform(build(access))
        } catch APIError.http(status: 401, _) {
            // Access token likely expired — refresh once and retry.
            let pair = try await refresh()
            return try await perform(build(pair.accessToken))
        }
    }

    private func perform(_ request: URLRequest) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.transport(error.localizedDescription)
        }
        guard let http = response as? HTTPURLResponse else {
            throw APIError.transport("No HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError.http(status: http.statusCode, message: Self.errorMessage(from: data))
        }
        return data
    }

    // MARK: - Decoding helpers

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        if data.isEmpty, let empty = EmptyResponse() as? T { return empty }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error.localizedDescription)
        }
    }

    private func jsonObject(_ data: Data) throws -> [String: Any] {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw APIError.decoding("expected JSON object")
        }
        return obj
    }

    private func jsonArray(_ data: Data) throws -> [[String: Any]] {
        guard let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw APIError.decoding("expected JSON array")
        }
        return arr
    }

    private static func errorMessage(from data: Data) -> String {
        guard
            let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return "" }
        if let detail = obj["detail"] as? String { return detail }
        if let detail = obj["detail"] as? [[String: Any]],
           let first = detail.first, let msg = first["msg"] as? String { return msg }
        return ""
    }

    private struct EmptyResponse: Decodable {}
}
