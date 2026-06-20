//
//  MealsRepository.swift
//  MealTracker
//
//  DuckDB-backed repository for reference meals used by the vision model.
//  The database is prebuilt and bundled as Meals.duckdb, copied to Application Support on first launch.
//

import Foundation

actor MealsRepository {
    static let shared = MealsRepository()

    struct MealRow: Sendable, Equatable {
        let id: Int64
        let title: String
        let description: String?
        let portionGrams: Double

        // Metrics (mirror of Meals table)
        let calories: Double?
        let carbohydrates: Double?
        let protein: Double?
        let sodium: Double?
        let fat: Double?

        let latitude: Double?
        let longitude: Double?

        let alcohol: Double?
        let nicotine: Double?
        let theobromine: Double?
        let caffeine: Double?
        let taurine: Double?

        let starch: Double?
        let sugars: Double?
        let fibre: Double?

        let monounsaturatedFat: Double?
        let polyunsaturatedFat: Double?
        let saturatedFat: Double?
        let transFat: Double?
        let omega3: Double?
        let omega6: Double?

        let animalProtein: Double?
        let plantProtein: Double?
        let proteinSupplements: Double?

        let vitaminA: Double?
        let vitaminB: Double?
        let vitaminC: Double?
        let vitaminD: Double?
        let vitaminE: Double?
        let vitaminK: Double?

        let calcium: Double?
        let iron: Double?
        let potassium: Double?
        let zinc: Double?
        let magnesium: Double?
    }

    // Fetch by primary key
    func fetch(id: Int64) async throws -> MealRow? {
        #if canImport(DuckDB)
        return try await MealsDBManager.shared.withConnection { conn in
            let sql = """
            SELECT * FROM meals WHERE id = ? LIMIT 1;
            """
            let rs = try conn.query(sql, id)
            guard rs.next() else { return nil }
            return self.mapRow(rs: rs)
        }
        #else
        throw NSError(domain: "MealsRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "DuckDB not available"])
        #endif
    }

    // Simple substring search on title and description (case-insensitive).
    // For FTS later, we can add a virtual table and route queries there.
    func search(query: String, limit: Int = 50, offset: Int = 0) async throws -> [MealRow] {
        #if canImport(DuckDB)
        let pattern = "%\(query)%"
        return try await MealsDBManager.shared.withConnection { conn in
            let sql = """
            SELECT * FROM meals
            WHERE lower(title) LIKE lower(?)
               OR (description IS NOT NULL AND lower(description) LIKE lower(?))
            ORDER BY title ASC
            LIMIT ? OFFSET ?;
            """
            let rs = try conn.query(sql, pattern, pattern, limit, offset)
            var out: [MealRow] = []
            while rs.next() {
                if let row = self.mapRow(rs: rs) {
                    out.append(row)
                }
            }
            return out
        }
        #else
        throw NSError(domain: "MealsRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "DuckDB not available"])
        #endif
    }

    // Page through all rows, ordered by title
    func listAll(limit: Int = 100, offset: Int = 0) async throws -> [MealRow] {
        #if canImport(DuckDB)
        return try await MealsDBManager.shared.withConnection { conn in
            let sql = """
            SELECT * FROM meals
            ORDER BY title ASC
            LIMIT ? OFFSET ?;
            """
            let rs = try conn.query(sql, limit, offset)
            var out: [MealRow] = []
            while rs.next() {
                if let row = self.mapRow(rs: rs) {
                    out.append(row)
                }
            }
            return out
        }
        #else
        throw NSError(domain: "MealsRepository", code: 1, userInfo: [NSLocalizedDescriptionKey: "DuckDB not available"])
        #endif
    }

    // Optional: upsert for maintenance; not required if DB is strictly read-only.
    func upsert(_ m: MealRow) async throws {
        #if canImport(DuckDB)
        _ = try await MealsDBManager.shared.withConnection { conn in
            let sql = """
            INSERT INTO meals (
                id, title, description, portion_grams,
                calories, carbohydrates, protein, sodium, fat,
                latitude, longitude,
                alcohol, nicotine, theobromine, caffeine, taurine,
                starch, sugars, fibre,
                monounsaturatedFat, polyunsaturatedFat, saturatedFat, transFat, omega3, omega6,
                animalProtein, plantProtein, proteinSupplements,
                vitaminA, vitaminB, vitaminC, vitaminD, vitaminE, vitaminK,
                calcium, iron, potassium, zinc, magnesium
            ) VALUES (
                ?, ?, ?, ?,
                ?, ?, ?, ?, ?,
                ?, ?,
                ?, ?, ?, ?, ?,
                ?, ?, ?,
                ?, ?, ?, ?, ?, ?,
                ?, ?, ?,
                ?, ?, ?, ?, ?, ?,
                ?, ?, ?, ?, ?
            )
            ON CONFLICT(id) DO UPDATE SET
                title = excluded.title,
                description = excluded.description,
                portion_grams = excluded.portion_grams,
                calories = excluded.calories,
                carbohydrates = excluded.carbohydrates,
                protein = excluded.protein,
                sodium = excluded.sodium,
                fat = excluded.fat,
                latitude = excluded.latitude,
                longitude = excluded.longitude,
                alcohol = excluded.alcohol,
                nicotine = excluded.nicotine,
                theobromine = excluded.theobromine,
                caffeine = excluded.caffeine,
                taurine = excluded.taurine,
                starch = excluded.starch,
                sugars = excluded.sugars,
                fibre = excluded.fibre,
                monounsaturatedFat = excluded.monounsaturatedFat,
                polyunsaturatedFat = excluded.polyunsaturatedFat,
                saturatedFat = excluded.saturatedFat,
                transFat = excluded.transFat,
                omega3 = excluded.omega3,
                omega6 = excluded.omega6,
                animalProtein = excluded.animalProtein,
                plantProtein = excluded.plantProtein,
                proteinSupplements = excluded.proteinSupplements,
                vitaminA = excluded.vitaminA,
                vitaminB = excluded.vitaminB,
                vitaminC = excluded.vitaminC,
                vitaminD = excluded.vitaminD,
                vitaminE = excluded.vitaminE,
                vitaminK = excluded.vitaminK,
                calcium = excluded.calcium,
                iron = excluded.iron,
                potassium = excluded.potassium,
                zinc = excluded.zinc,
                magnesium = excluded.magnesium;
            """
            return try conn.query(
                sql,
                m.id, m.title, m.description, m.portionGrams,
                m.calories, m.carbohydrates, m.protein, m.sodium, m.fat,
                m.latitude, m.longitude,
                m.alcohol, m.nicotine, m.theobromine, m.caffeine, m.taurine,
                m.starch, m.sugars, m.fibre,
                m.monounsaturatedFat, m.polyunsaturatedFat, m.saturatedFat, m.transFat, m.omega3, m.omega6,
                m.animalProtein, m.plantProtein, m.proteinSupplements,
                m.vitaminA, m.vitaminB, m.vitaminC, m.vitaminD, m.vitaminE, m.vitaminK,
                m.calcium, m.iron, m.potassium, m.zinc, m.magnesium
            )
        }
        #else
        return
        #endif
    }

    // MARK: - Mapping

    #if canImport(DuckDB)
    private func mapRow(rs: Result) -> MealRow? {
        func doubleOrNil(_ name: String) -> Double? { rs.get(name) as Double? }
        func int64OrZero(_ name: String) -> Int64 { (rs.get(name) as Int64?) ?? 0 }
        func stringOrNil(_ name: String) -> String? { rs.get(name) as String? }

        let id = int64OrZero("id")
        guard id > 0 else { return nil }

        return MealRow(
            id: id,
            title: (stringOrNil("title") ?? ""),
            description: stringOrNil("description"),
            portionGrams: doubleOrNil("portion_grams") ?? 0,

            calories: doubleOrNil("calories"),
            carbohydrates: doubleOrNil("carbohydrates"),
            protein: doubleOrNil("protein"),
            sodium: doubleOrNil("sodium"),
            fat: doubleOrNil("fat"),

            latitude: doubleOrNil("latitude"),
            longitude: doubleOrNil("longitude"),

            alcohol: doubleOrNil("alcohol"),
            nicotine: doubleOrNil("nicotine"),
            theobromine: doubleOrNil("theobromine"),
            caffeine: doubleOrNil("caffeine"),
            taurine: doubleOrNil("taurine"),

            starch: doubleOrNil("starch"),
            sugars: doubleOrNil("sugars"),
            fibre: doubleOrNil("fibre"),

            monounsaturatedFat: doubleOrNil("monounsaturatedFat"),
            polyunsaturatedFat: doubleOrNil("polyunsaturatedFat"),
            saturatedFat: doubleOrNil("saturatedFat"),
            transFat: doubleOrNil("transFat"),
            omega3: doubleOrNil("omega3"),
            omega6: doubleOrNil("omega6"),

            animalProtein: doubleOrNil("animalProtein"),
            plantProtein: doubleOrNil("plantProtein"),
            proteinSupplements: doubleOrNil("proteinSupplements"),

            vitaminA: doubleOrNil("vitaminA"),
            vitaminB: doubleOrNil("vitaminB"),
            vitaminC: doubleOrNil("vitaminC"),
            vitaminD: doubleOrNil("vitaminD"),
            vitaminE: doubleOrNil("vitaminE"),
            vitaminK: doubleOrNil("vitaminK"),

            calcium: doubleOrNil("calcium"),
            iron: doubleOrNil("iron"),
            potassium: doubleOrNil("potassium"),
            zinc: doubleOrNil("zinc"),
            magnesium: doubleOrNil("magnesium")
        )
    }
    #endif
}

