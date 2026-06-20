//
//  CloudModels.swift
//  MealTracker
//
//  Data-transfer models and field manifest for syncing with the meal-tracker-web
//  backend. The field manifest is GENERATED from the Core Data model so that every
//  food metric (40 numeric values + 38 `*IsGuess` flags) round-trips 1:1 with the
//  web app. Do not hand-edit the manifest arrays — regenerate from the model.
//

import Foundation
import CoreData

// MARK: - Auth DTOs

struct TokenPair: Codable {
    let accessToken: String
    let refreshToken: String
    let tokenType: String?
    let expiresIn: Int
    let sessionId: String?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case tokenType = "token_type"
        case expiresIn = "expires_in"
        case sessionId = "session_id"
    }
}

struct UserPublic: Codable {
    let id: String
    let email: String?
    let displayName: String?
    let provider: String?
    let isAdmin: Bool?

    enum CodingKeys: String, CodingKey {
        case id, email, provider
        case displayName = "display_name"
        case isAdmin = "is_admin"
    }
}

// MARK: - Person DTO (mirrors meal.people)

struct PersonDTO: Codable {
    var id: String?
    var name: String
    var isDefault: Bool
    var isRemoved: Bool
    var deletedAt: String?

    enum CodingKeys: String, CodingKey {
        case id, name
        case isDefault = "is_default"
        case isRemoved = "is_removed"
        case deletedAt = "deleted_at"
    }
}

// MARK: - ISO 8601 date helpers
//
// The backend emits ISO 8601 timestamps that MAY include fractional seconds and a
// trailing `Z` or numeric offset. Foundation's `.iso8601` strategy rejects fractional
// seconds, so we parse/format explicitly and tolerate both shapes.

enum CloudDate {
    private static let withFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
    private static let noFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ s: String?) -> Date? {
        guard let s, !s.isEmpty else { return nil }
        return withFraction.date(from: s) ?? noFraction.date(from: s)
    }

    /// Always serialise with fractional seconds in UTC for maximum precision.
    static func string(from date: Date) -> String {
        withFraction.string(from: date)
    }
}

// MARK: - Meal field manifest (GENERATED)

enum MealFieldManifest {
    /// Numeric nutrient/metric fields (Core Data `Double`). Generated from the
    /// MealTracker Core Data model so every metric round-trips 1:1 with the backend.
    static let doubleFields: [(snake: String, camel: String)] = [
        (snake: "a1_beta_casein", camel: "a1BetaCasein"),
        (snake: "a2_beta_casein", camel: "a2BetaCasein"),
        (snake: "alcohol", camel: "alcohol"),
        (snake: "animal_protein", camel: "animalProtein"),
        (snake: "caffeine", camel: "caffeine"),
        (snake: "calcium", camel: "calcium"),
        (snake: "calories", camel: "calories"),
        (snake: "carbohydrates", camel: "carbohydrates"),
        (snake: "creatine", camel: "creatine"),
        (snake: "fat", camel: "fat"),
        (snake: "fibre", camel: "fibre"),
        (snake: "iodine", camel: "iodine"),
        (snake: "iron", camel: "iron"),
        (snake: "latitude", camel: "latitude"),
        (snake: "longitude", camel: "longitude"),
        (snake: "magnesium", camel: "magnesium"),
        (snake: "monounsaturated_fat", camel: "monounsaturatedFat"),
        (snake: "nicotine", camel: "nicotine"),
        (snake: "omega3", camel: "omega3"),
        (snake: "omega6", camel: "omega6"),
        (snake: "phosphorus", camel: "phosphorus"),
        (snake: "plant_protein", camel: "plantProtein"),
        (snake: "polyunsaturated_fat", camel: "polyunsaturatedFat"),
        (snake: "potassium", camel: "potassium"),
        (snake: "protein", camel: "protein"),
        (snake: "protein_supplements", camel: "proteinSupplements"),
        (snake: "saturated_fat", camel: "saturatedFat"),
        (snake: "sodium", camel: "sodium"),
        (snake: "starch", camel: "starch"),
        (snake: "sugars", camel: "sugars"),
        (snake: "taurine", camel: "taurine"),
        (snake: "theobromine", camel: "theobromine"),
        (snake: "trans_fat", camel: "transFat"),
        (snake: "vitamin_a", camel: "vitaminA"),
        (snake: "vitamin_b", camel: "vitaminB"),
        (snake: "vitamin_c", camel: "vitaminC"),
        (snake: "vitamin_d", camel: "vitaminD"),
        (snake: "vitamin_e", camel: "vitaminE"),
        (snake: "vitamin_k", camel: "vitaminK"),
        (snake: "zinc", camel: "zinc"),
    ]

    /// `*IsGuess` accuracy flags (Core Data `Bool`).
    static let boolFields: [(snake: String, camel: String)] = [
        (snake: "a1_beta_casein_is_guess", camel: "a1BetaCaseinIsGuess"),
        (snake: "a2_beta_casein_is_guess", camel: "a2BetaCaseinIsGuess"),
        (snake: "alcohol_is_guess", camel: "alcoholIsGuess"),
        (snake: "animal_protein_is_guess", camel: "animalProteinIsGuess"),
        (snake: "caffeine_is_guess", camel: "caffeineIsGuess"),
        (snake: "calcium_is_guess", camel: "calciumIsGuess"),
        (snake: "calories_is_guess", camel: "caloriesIsGuess"),
        (snake: "carbohydrates_is_guess", camel: "carbohydratesIsGuess"),
        (snake: "creatine_is_guess", camel: "creatineIsGuess"),
        (snake: "fat_is_guess", camel: "fatIsGuess"),
        (snake: "fibre_is_guess", camel: "fibreIsGuess"),
        (snake: "iodine_is_guess", camel: "iodineIsGuess"),
        (snake: "iron_is_guess", camel: "ironIsGuess"),
        (snake: "magnesium_is_guess", camel: "magnesiumIsGuess"),
        (snake: "monounsaturated_fat_is_guess", camel: "monounsaturatedFatIsGuess"),
        (snake: "nicotine_is_guess", camel: "nicotineIsGuess"),
        (snake: "omega3_is_guess", camel: "omega3IsGuess"),
        (snake: "omega6_is_guess", camel: "omega6IsGuess"),
        (snake: "phosphorus_is_guess", camel: "phosphorusIsGuess"),
        (snake: "plant_protein_is_guess", camel: "plantProteinIsGuess"),
        (snake: "polyunsaturated_fat_is_guess", camel: "polyunsaturatedFatIsGuess"),
        (snake: "potassium_is_guess", camel: "potassiumIsGuess"),
        (snake: "protein_is_guess", camel: "proteinIsGuess"),
        (snake: "protein_supplements_is_guess", camel: "proteinSupplementsIsGuess"),
        (snake: "saturated_fat_is_guess", camel: "saturatedFatIsGuess"),
        (snake: "sodium_is_guess", camel: "sodiumIsGuess"),
        (snake: "starch_is_guess", camel: "starchIsGuess"),
        (snake: "sugars_is_guess", camel: "sugarsIsGuess"),
        (snake: "taurine_is_guess", camel: "taurineIsGuess"),
        (snake: "theobromine_is_guess", camel: "theobromineIsGuess"),
        (snake: "trans_fat_is_guess", camel: "transFatIsGuess"),
        (snake: "vitamin_a_is_guess", camel: "vitaminAIsGuess"),
        (snake: "vitamin_b_is_guess", camel: "vitaminBIsGuess"),
        (snake: "vitamin_c_is_guess", camel: "vitaminCIsGuess"),
        (snake: "vitamin_d_is_guess", camel: "vitaminDIsGuess"),
        (snake: "vitamin_e_is_guess", camel: "vitaminEIsGuess"),
        (snake: "vitamin_k_is_guess", camel: "vitaminKIsGuess"),
        (snake: "zinc_is_guess", camel: "zincIsGuess"),
    ]

    /// Optional string columns that sync as-is (camelCase key == Core Data attribute).
    /// `mealDescription` is intentionally excluded: it exists in the Core Data model but
    /// is used by neither the iOS UI nor the web app, and has no backend column.
    static let stringFields: [(snake: String, camel: String)] = [
        (snake: "photo_guesser_type", camel: "photoGuesserType"),
        (snake: "product_name", camel: "productName"),
    ]
}

// MARK: - Meal <-> JSON codec
//
// Rather than declare ~80 Codable properties, the codec is driven entirely by the
// generated manifest and Core Data KVC. This makes it impossible for a metric to be
// present on one side and silently dropped on the other.

enum MealCodec {

    /// Build the JSON body for `PUT /api/meals/{id}` from a Core Data `Meal`.
    /// Includes every food metric, location, title, date, provenance and (optionally)
    /// the owning person. Server-managed fields (user_id, timestamps) are never sent.
    static func requestBody(for meal: Meal, personID: UUID?) -> [String: Any] {
        var body: [String: Any] = [:]
        body["id"] = meal.id.uuidString
        body["title"] = meal.value(forKey: "title") as? String ?? ""
        body["date"] = CloudDate.string(from: meal.value(forKey: "date") as? Date ?? Date())

        for field in MealFieldManifest.doubleFields {
            body[field.snake] = (meal.value(forKey: field.camel) as? Double) ?? 0.0
        }
        for field in MealFieldManifest.boolFields {
            body[field.snake] = (meal.value(forKey: field.camel) as? Bool) ?? false
        }
        for field in MealFieldManifest.stringFields {
            if let v = meal.value(forKey: field.camel) as? String { body[field.snake] = v }
        }
        if let personID { body["person_id"] = personID.uuidString }
        return body
    }

    /// Apply a meal JSON object received from `GET /api/meals` or `/api/sync/changes`
    /// onto a Core Data `Meal`. Returns the server `last_sync_guid` (if any) so the
    /// caller can stamp the local row as clean.
    @discardableResult
    static func apply(_ json: [String: Any], to meal: Meal) -> String? {
        if let title = json["title"] as? String { meal.setValue(title, forKey: "title") }
        if let date = CloudDate.parse(json["date"] as? String) { meal.setValue(date, forKey: "date") }

        for field in MealFieldManifest.doubleFields {
            if let n = json[field.snake] as? NSNumber { meal.setValue(n.doubleValue, forKey: field.camel) }
        }
        for field in MealFieldManifest.boolFields {
            if let b = json[field.snake] as? NSNumber { meal.setValue(b.boolValue, forKey: field.camel) }
            else if let b = json[field.snake] as? Bool { meal.setValue(b, forKey: field.camel) }
        }
        for field in MealFieldManifest.stringFields {
            if json[field.snake] is NSNull { meal.setValue(nil, forKey: field.camel) }
            else if let s = json[field.snake] as? String { meal.setValue(s, forKey: field.camel) }
        }
        return json["last_sync_guid"] as? String
    }

    static func isTombstone(_ json: [String: Any]) -> Bool {
        if json["deleted_at"] is NSNull { return false }
        return (json["deleted_at"] as? String)?.isEmpty == false
    }

    static func id(of json: [String: Any]) -> UUID? {
        (json["id"] as? String).flatMap(UUID.init(uuidString:))
    }

    static func personID(of json: [String: Any]) -> UUID? {
        (json["person_id"] as? String).flatMap(UUID.init(uuidString:))
    }
}
