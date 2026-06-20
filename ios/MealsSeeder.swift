//
//  MealsSeeder.swift
//  MealTracker
//
//  Seeds the bundled Meals.duckdb with real-world meals from TheMealDB.
//  No fabricated nutrition values.
//  All nutrient fields remain nil unless sources provide values.
//

import Foundation

// MARK: - Public entry point

enum MealsSeeder {

    // Configure how many items to fetch (nil = all available).
    // Returns the number of upserts performed.
    static func seedMealsDB(maxItems: Int? = nil, log: ((String) -> Void)? = nil) async throws -> Int {
        var totalUpserts = 0
        let logger: (String) -> Void = { msg in
            #if DEBUG
            print("[MealsSeeder] \(msg)")
            #endif
            log?(msg)
        }

        // Fetch and insert meals
        logger("Fetching meals from TheMealDB…")
        let meals = try await TheMealDBClient.fetchAllMeals(logger: logger, maxItems: maxItems)
        logger("Fetched \(meals.count) meals; upserting…")
        for m in meals {
            do {
                try await MealsRepository.shared.upsert(m)
                totalUpserts += 1
            } catch {
                logger("Upsert meal id=\(m.id) failed: \(error.localizedDescription)")
            }
        }
        logger("Upserted \(meals.count) meals.")

        logger("Seeding complete. Total upserts: \(totalUpserts)")
        return totalUpserts
    }

    // Progress-reporting variant. The progress callback receives (downloaded, total, phase).
    // maxItems: Int? = nil means fetch all available items.
    // Returns the number of upserts performed.
    static func seedMealsDBWithProgress(
        maxItems: Int?,
        progress: @escaping (Int, Int, String) -> Void
    ) async throws -> Int {
        var totalUpserts = 0
        let logger: (String) -> Void = { msg in
            #if DEBUG
            print("[MealsSeeder] \(msg)")
            #endif
        }

        // Phase 1: Fetch meals
        let fetchPhase = NSLocalizedString("seeder_phase_fetching_meals", comment: "Fetching meals…")
        progress(0, 0, fetchPhase)
        logger("Fetching meals from TheMealDB…")
        
        let meals = try await TheMealDBClient.fetchAllMeals(logger: logger, maxItems: maxItems)
        let total = meals.count
        
        logger("Fetched \(total) meals; upserting…")
        
        // Phase 2: Upsert meals with progress
        let upsertPhase = NSLocalizedString("seeder_phase_saving_meals", comment: "Saving meals…")
        for (index, m) in meals.enumerated() {
            progress(index, total, upsertPhase)
            do {
                try await MealsRepository.shared.upsert(m)
                totalUpserts += 1
            } catch {
                logger("Upsert meal id=\(m.id) failed: \(error.localizedDescription)")
            }
        }
        
        // Final progress update
        progress(total, total, upsertPhase)
        logger("Upserted \(totalUpserts) meals.")
        logger("Seeding complete. Total upserts: \(totalUpserts)")
        
        return totalUpserts
    }


}

// ... TheMealDBClient remains unchanged below ...
// (Keep the rest of the file exactly as you already have it.)
