//
//  BarcodeRepository.swift
//  MealTracker
//
//  DuckDB-backed repository for barcode -> nutrition lookups.
//  Emits structured barcode log events around normalization, local lookup, and upsert.
//

import Foundation
import CoreData

actor BarcodeRepository {
    static let shared = BarcodeRepository()

    // Normalize barcode string to digits-only (your JSON used trimming+space removal)
    private func normalize(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
    }

    func lookup(code raw: String) async -> LocalBarcodeDB.Entry? {
        let code = normalize(raw)

        #if canImport(DuckDB)
        do {
            let entry = try await DuckDBManager.shared.withConnection { conn -> LocalBarcodeDB.Entry? in
                let sql = """
                SELECT
                    code,
                    calories, carbohydrates, protein, fat, sodiumMg,
                    sugars, starch, fibre,
                    monounsaturatedFat, polyunsaturatedFat, saturatedFat, transFat,
                    animalProtein, plantProtein, proteinSupplements, a2BetaCasein,
                    vitaminA, vitaminB, vitaminC, vitaminD, vitaminE, vitaminK,
                    calcium, iron, potassium, zinc, magnesium
                FROM barcodes
                WHERE code = ?
                LIMIT 1;
                """
                let rs = try conn.query(sql, code)
                guard rs.next() else { return nil }

                func intOrNil(_ name: String) -> Int? { rs.get(name) as Int? }
                func doubleOrNil(_ name: String) -> Double? { rs.get(name) as Double? }
                func stringOrNil(_ name: String) -> String? { rs.get(name) as String? }

                let codeVal = stringOrNil("code") ?? code

                return LocalBarcodeDB.Entry(
                    code: codeVal,
                    calories: intOrNil("calories"),
                    carbohydrates: doubleOrNil("carbohydrates"),
                    protein: doubleOrNil("protein"),
                    fat: doubleOrNil("fat"),
                    sodiumMg: intOrNil("sodiumMg"),
                    sugars: doubleOrNil("sugars"),
                    starch: doubleOrNil("starch"),
                    fibre: doubleOrNil("fibre"),
                    monounsaturatedFat: doubleOrNil("monounsaturatedFat"),
                    polyunsaturatedFat: doubleOrNil("polyunsaturatedFat"),
                    saturatedFat: doubleOrNil("saturatedFat"),
                    transFat: doubleOrNil("transFat"),
                    animalProtein: doubleOrNil("animalProtein"),
                    plantProtein: doubleOrNil("plantProtein"),
                    proteinSupplements: doubleOrNil("proteinSupplements"),
                    a2BetaCasein: doubleOrNil("a2BetaCasein"),
                    vitaminA: doubleOrNil("vitaminA"),
                    vitaminB: doubleOrNil("vitaminB"),
                    vitaminC: doubleOrNil("vitaminC"),
                    vitaminD: doubleOrNil("vitaminD"),
                    vitaminE: doubleOrNil("vitaminE"),
                    vitaminK: doubleOrNil("vitaminK"),
                    calcium: intOrNil("calcium"),
                    iron: intOrNil("iron"),
                    potassium: doubleOrNil("potassium"),
                    zinc: intOrNil("zinc"),
                    magnesium: intOrNil("magnesium")
                )
            }
            // Prefer DB result; fall back to bundled JSON if nil
            return entry ?? LocalBarcodeDB.lookup(code: code)
        } catch {
            // On any DB error, fall back to JSON
            return LocalBarcodeDB.lookup(code: code)
        }
        #else
        // If DuckDB is not available in this target, use the bundled JSON only.
        return LocalBarcodeDB.lookup(code: code)
        #endif
    }

    // Upsert a barcode entry into DuckDB using INSERT ... ON CONFLICT DO UPDATE.
    func upsert(entry e: LocalBarcodeDB.Entry) async throws {
        // Strict precondition: reject if any metric is insane
        let badFields = insaneFields(in: e)
        if !badFields.isEmpty {
            #if DEBUG
            await BarcodeLogStore.shared.appendEvent(
                .init(stage: .upsertFailure,
                      codeRaw: e.code,
                      codeNormalized: e.code,
                      entry: e,
                      error: "Rejected insane fields: \(badFields.joined(separator: ", "))")
            )
            #endif
            throw NSError(domain: "BarcodeRepository", code: 400, userInfo: [NSLocalizedDescriptionKey: "Insane nutriment values: \(badFields.joined(separator: ", "))"])
        }

        #if DEBUG
        await BarcodeLogStore.shared.appendEvent(
            .init(stage: .upsertAttempt,
                  codeRaw: e.code,
                  codeNormalized: e.code,
                  entry: e)
        )
        #endif

        #if canImport(DuckDB)
        do {
            try await DuckDBManager.shared.withConnection { conn in
                let sql = """
                INSERT INTO barcodes (
                    code,
                    calories, carbohydrates, protein, fat, sodiumMg,
                    sugars, starch, fibre,
                    monounsaturatedFat, polyunsaturatedFat, saturatedFat, transFat,
                    animalProtein, plantProtein, proteinSupplements, a2BetaCasein,
                    vitaminA, vitaminB, vitaminC, vitaminD, vitaminE, vitaminK,
                    calcium, iron, potassium, zinc, magnesium
                ) VALUES (
                    ?, ?, ?, ?, ?, ?,
                    ?, ?, ?,
                    ?, ?, ?, ?,
                    ?, ?, ?, ?,
                    ?, ?, ?, ?, ?, ?,
                    ?, ?, ?, ?, ?
                )
                ON CONFLICT(code) DO UPDATE SET
                    calories = excluded.calories,
                    carbohydrates = excluded.carbohydrates,
                    protein = excluded.protein,
                    fat = excluded.fat,
                    sodiumMg = excluded.sodiumMg,
                    sugars = excluded.sugars,
                    starch = excluded.starch,
                    fibre = excluded.fibre,
                    monounsaturatedFat = excluded.monounsaturatedFat,
                    polyunsaturatedFat = excluded.polyunsaturatedFat,
                    saturatedFat = excluded.saturatedFat,
                    transFat = excluded.transFat,
                    animalProtein = excluded.animalProtein,
                    plantProtein = excluded.plantProtein,
                    proteinSupplements = excluded.proteinSupplements,
                    a2BetaCasein = excluded.a2BetaCasein,
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
                _ = try conn.query(
                    sql,
                    e.code,
                    e.calories, e.carbohydrates, e.protein, e.fat, e.sodiumMg,
                    e.sugars, e.starch, e.fibre,
                    e.monounsaturatedFat, e.polyunsaturatedFat, e.saturatedFat, e.transFat,
                    e.animalProtein, e.plantProtein, e.proteinSupplements, e.a2BetaCasein,
                    e.vitaminA, e.vitaminB, e.vitaminC, e.vitaminD, e.vitaminE, e.vitaminK,
                    e.calcium, e.iron, e.potassium, e.zinc, e.magnesium
                )
            }
            #if DEBUG
            await BarcodeLogStore.shared.appendEvent(
                .init(stage: .upsertSuccess, codeRaw: e.code, codeNormalized: e.code, entry: e)
            )
            #endif
        } catch {
            #if DEBUG
            await BarcodeLogStore.shared.appendEvent(
                .init(stage: .upsertFailure, codeRaw: e.code, codeNormalized: e.code, entry: e, error: error.localizedDescription)
            )
            #endif
            throw error
        }
        #else
        // No-op on targets without DuckDB
        return
        #endif
    }

    // High-level: handle a scanned barcode -> local DB -> OFF -> save to DB and apply to meal.
    // Added optional debug logger to surface API progress/errors to the wizard.
    func handleScannedBarcode(_ rawCode: String,
                              for meal: Meal,
                              in context: NSManagedObjectContext,
                              sodiumUnit: SodiumUnit,
                              vitaminsUnit: VitaminsUnit,
                              logger: ((String) -> Void)? = nil) async {
        let code = normalize(rawCode)
        let l = LocalizationManager(languageCode: LocalizationManager.defaultLanguageCode)

        #if DEBUG
        await BarcodeLogStore.shared.appendEvent(
            .init(stage: .normalizeCode, codeRaw: rawCode, codeNormalized: code)
        )
        #endif

        // 1) Local lookup
        if let local = await lookup(code: code) {
            // Strict sanity check for local entry (defensive in case older DB has bad values)
            let bad = insaneFields(in: local)
            if !bad.isEmpty {
                let fmt = l.localized("wizard_local_db_rejected_format") // "Local barcode DB hit rejected: insane values (%@)"
                let msg = String(format: fmt, bad.joined(separator: ", "))
                logger?(msg)
                #if DEBUG
                await BarcodeLogStore.shared.appendEvent(
                    .init(stage: .localLookupHit, codeRaw: rawCode, codeNormalized: code, entry: local, error: msg)
                )
                #endif
            } else {
                let fmt = l.localized("wizard_local_db_hit_format") // "Local barcode DB hit for %@"
                let msg = String(format: fmt, code)
                logger?(msg)
                #if DEBUG
                await BarcodeLogStore.shared.appendEvent(
                    .init(stage: .localLookupHit, codeRaw: rawCode, codeNormalized: code, entry: local)
                )
                #endif
                await MainActor.run {
                    applyEntryToMealForm(entry: local, meal: meal, context: context, sodiumUnit: sodiumUnit, vitaminsUnit: vitaminsUnit)
                }
            }
        } else {
            let fmt = l.localized("wizard_local_db_miss_format") // "Local barcode DB miss for %@"
            let msg = String(format: fmt, code)
            logger?(msg)
            #if DEBUG
            await BarcodeLogStore.shared.appendEvent(
                .init(stage: .localLookupMiss, codeRaw: rawCode, codeNormalized: code)
            )
            #endif
        }

        // 2) Open Food Facts
        do {
            let fmtStart = l.localized("wizard_off_fetching_format") // "OFF: fetching product %@…"
            logger?(String(format: fmtStart, code))

            let product = try await OpenFoodFactsClient.fetchProduct(by: code, logger: { s in
                logger?(s)
            })

            let fmtFound = l.localized("wizard_off_found_format") // "OFF: product found for %@"
            logger?(String(format: fmtFound, code))

            // NEW: Save product_name onto the Meal if present
            if let rawName = product.product_name?.trimmingCharacters(in: .whitespacesAndNewlines),
               !rawName.isEmpty {
                await MainActor.run {
                    // Only set if empty or different; keep latest from OFF
                    if meal.productName != rawName {
                        meal.productName = rawName
                        try? context.save()
                    }
                }
            }

            if let offEntry = OpenFoodFactsClient.mapToEntry(from: product) {
                // Strict sanity check BEFORE any upsert/apply
                let insane = insaneFields(in: offEntry)
                if !insane.isEmpty {
                    let human = insane.joined(separator: ", ")
                    let fmt = l.localized("wizard_off_rejected_insane_format") // "OFF: rejected insane values (%@); not inserting/applying."
                    logger?(String(format: fmt, human))
                    #if DEBUG
                    await BarcodeLogStore.shared.appendEvent(
                        .init(stage: .offMapResult,
                              codeRaw: rawCode,
                              codeNormalized: code,
                              conversions: ["Rejected insane fields: \(human)"],
                              entry: offEntry,
                              error: "Insane values present")
                    )
                    #endif
                    return
                }

                let (sanitized, dropped) = sanitize(entry: offEntry)

                // Wizard overlay logging for sanitization result
                if !dropped.isEmpty {
                    let human = dropped.joined(separator: ", ")
                    let fmt = l.localized("wizard_off_sanitized_dropped_format") // "OFF: sanitized entry (dropped: %@)"
                    logger?(String(format: fmt, human))
                } else {
                    logger?(l.localized("wizard_off_sanitized_no_red")) // "OFF: sanitized entry (no red fields)"
                }

                #if DEBUG
                if !dropped.isEmpty {
                    await BarcodeLogStore.shared.appendEvent(
                        .init(stage: .offMapResult,
                              codeRaw: rawCode,
                              codeNormalized: code,
                              conversions: ["Dropped red fields: \(dropped.joined(separator: ", "))"],
                              entry: sanitized)
                    )
                } else {
                    await BarcodeLogStore.shared.appendEvent(
                        .init(stage: .offMapResult,
                              codeRaw: rawCode,
                              codeNormalized: code,
                              conversions: ["No red fields dropped"],
                              entry: sanitized)
                    )
                }
                #endif

                // Upsert into DuckDB with safe fields only
                try? await upsert(entry: sanitized)

                // Apply to meal (fill empty-only)
                await MainActor.run {
                    applyEntryToMealForm(entry: sanitized, meal: meal, context: context, sodiumUnit: sodiumUnit, vitaminsUnit: vitaminsUnit)
                }
            } else {
                logger?(l.localized("wizard_off_no_usable_nutriments")) // "OFF: mapping returned no usable nutriments"
                #if DEBUG
                await BarcodeLogStore.shared.appendEvent(
                    .init(stage: .offMapStart, codeRaw: rawCode, codeNormalized: code, error: "No usable nutriments")
                )
                #endif
            }
        } catch {
            let fmt = LocalizationManager(languageCode: LocalizationManager.defaultLanguageCode).localized("wizard_off_error_format") // "OFF: error for %@: %@"
            let msg = String(format: fmt, code, error.localizedDescription)
            logger?(msg)
            #if DEBUG
            await BarcodeLogStore.shared.appendEvent(
                .init(stage: .offDecodeError, codeRaw: rawCode, codeNormalized: code, error: msg)
            )
            #endif
        }
    }

    // Fill empty fields only, mark as accurate (guess=false), respect UI units for sodium/vitamins.
    @MainActor
    private func applyEntryToMealForm(entry: LocalBarcodeDB.Entry,
                                      meal: Meal,
                                      context: NSManagedObjectContext,
                                      sodiumUnit: SodiumUnit,
                                      vitaminsUnit: VitaminsUnit) {
        // Fill if current value is zero or negative, OR if it's a guess value
        // Barcode data is always authoritative (non-guess), so it should override guesses
        func fillDoubleIfZeroOrGuess(_ current: Double, isGuess: Bool, with v: Double?) -> Double {
            guard let v else { return current }
            if current <= 0 || isGuess {
                return max(0.0, v)
            }
            return current
        }

        // Apply calories from barcode if current value is 0 OR if current value is a guess
        // This ensures barcode data (which is accurate) overwrites placeholder/guess values
        if let kcal = entry.calories {
            if meal.calories <= 0 || meal.caloriesIsGuess {
                meal.calories = Double(max(0, kcal))
                meal.caloriesIsGuess = false
            }
        }

        meal.carbohydrates = fillDoubleIfZeroOrGuess(meal.carbohydrates, isGuess: meal.carbohydratesIsGuess, with: entry.carbohydrates)
        if entry.carbohydrates != nil && meal.carbohydrates > 0 { meal.carbohydratesIsGuess = false }

        meal.protein = fillDoubleIfZeroOrGuess(meal.protein, isGuess: meal.proteinIsGuess, with: entry.protein)
        if entry.protein != nil && meal.protein > 0 { meal.proteinIsGuess = false }

        meal.fat = fillDoubleIfZeroOrGuess(meal.fat, isGuess: meal.fatIsGuess, with: entry.fat)
        if entry.fat != nil && meal.fat > 0 { meal.fatIsGuess = false }

        // Sodium: convert from mg, overwrite if zero or guess
        if let mg = entry.sodiumMg {
            if meal.sodium <= 0 || meal.sodiumIsGuess {
                meal.sodium = Double(max(0, mg))
                meal.sodiumIsGuess = false
            }
        }

        meal.sugars = fillDoubleIfZeroOrGuess(meal.sugars, isGuess: meal.sugarsIsGuess, with: entry.sugars)
        if entry.sugars != nil && meal.sugars > 0 { meal.sugarsIsGuess = false }

        meal.starch = fillDoubleIfZeroOrGuess(meal.starch, isGuess: meal.starchIsGuess, with: entry.starch)
        if entry.starch != nil && meal.starch > 0 { meal.starchIsGuess = false }

        meal.fibre = fillDoubleIfZeroOrGuess(meal.fibre, isGuess: meal.fibreIsGuess, with: entry.fibre)
        if entry.fibre != nil && meal.fibre > 0 { meal.fibreIsGuess = false }

        meal.monounsaturatedFat = fillDoubleIfZeroOrGuess(meal.monounsaturatedFat, isGuess: meal.monounsaturatedFatIsGuess, with: entry.monounsaturatedFat)
        if entry.monounsaturatedFat != nil && meal.monounsaturatedFat > 0 { meal.monounsaturatedFatIsGuess = false }

        meal.polyunsaturatedFat = fillDoubleIfZeroOrGuess(meal.polyunsaturatedFat, isGuess: meal.polyunsaturatedFatIsGuess, with: entry.polyunsaturatedFat)
        if entry.polyunsaturatedFat != nil && meal.polyunsaturatedFat > 0 { meal.polyunsaturatedFatIsGuess = false }

        meal.saturatedFat = fillDoubleIfZeroOrGuess(meal.saturatedFat, isGuess: meal.saturatedFatIsGuess, with: entry.saturatedFat)
        if entry.saturatedFat != nil && meal.saturatedFat > 0 { meal.saturatedFatIsGuess = false }

        meal.transFat = fillDoubleIfZeroOrGuess(meal.transFat, isGuess: meal.transFatIsGuess, with: entry.transFat)
        if entry.transFat != nil && meal.transFat > 0 { meal.transFatIsGuess = false }

        meal.animalProtein = fillDoubleIfZeroOrGuess(meal.animalProtein, isGuess: meal.animalProteinIsGuess, with: entry.animalProtein)
        if entry.animalProtein != nil && meal.animalProtein > 0 { meal.animalProteinIsGuess = false }

        meal.plantProtein = fillDoubleIfZeroOrGuess(meal.plantProtein, isGuess: meal.plantProteinIsGuess, with: entry.plantProtein)
        if entry.plantProtein != nil && meal.plantProtein > 0 { meal.plantProteinIsGuess = false }

        meal.proteinSupplements = fillDoubleIfZeroOrGuess(meal.proteinSupplements, isGuess: meal.proteinSupplementsIsGuess, with: entry.proteinSupplements)
        if entry.proteinSupplements != nil && meal.proteinSupplements > 0 { meal.proteinSupplementsIsGuess = false }

        // New: A2 beta-casein
        meal.a2BetaCasein = fillDoubleIfZeroOrGuess(meal.a2BetaCasein, isGuess: meal.a2BetaCaseinIsGuess, with: entry.a2BetaCasein)
        if entry.a2BetaCasein != nil && meal.a2BetaCasein > 0 { meal.a2BetaCaseinIsGuess = false }

        // Helper for vitamins/minerals (Double values, can override if guess)
        func fillVitaminMineralDouble(_ current: Double, isGuess: Bool, with mg: Double?) -> Double {
            guard let mg else { return current }
            if current <= 0 || isGuess {
                return max(0.0, mg)
            }
            return current
        }
        
        // Helper for vitamins/minerals (Int values, can override if guess)
        func fillVitaminMineralInt(_ current: Double, isGuess: Bool, with mg: Int?) -> Double {
            guard let mg else { return current }
            if current <= 0 || isGuess {
                return Double(max(0, mg))
            }
            return current
        }

        meal.vitaminA = fillVitaminMineralDouble(meal.vitaminA, isGuess: meal.vitaminAIsGuess, with: entry.vitaminA)
        if entry.vitaminA != nil && meal.vitaminA > 0 { meal.vitaminAIsGuess = false }

        meal.vitaminB = fillVitaminMineralDouble(meal.vitaminB, isGuess: meal.vitaminBIsGuess, with: entry.vitaminB)
        if entry.vitaminB != nil && meal.vitaminB > 0 { meal.vitaminBIsGuess = false }

        meal.vitaminC = fillVitaminMineralDouble(meal.vitaminC, isGuess: meal.vitaminCIsGuess, with: entry.vitaminC)
        if entry.vitaminC != nil && meal.vitaminC > 0 { meal.vitaminCIsGuess = false }

        meal.vitaminD = fillVitaminMineralDouble(meal.vitaminD, isGuess: meal.vitaminDIsGuess, with: entry.vitaminD)
        if entry.vitaminD != nil && meal.vitaminD > 0 { meal.vitaminDIsGuess = false }

        meal.vitaminE = fillVitaminMineralDouble(meal.vitaminE, isGuess: meal.vitaminEIsGuess, with: entry.vitaminE)
        if entry.vitaminE != nil && meal.vitaminE > 0 { meal.vitaminEIsGuess = false }

        meal.vitaminK = fillVitaminMineralDouble(meal.vitaminK, isGuess: meal.vitaminKIsGuess, with: entry.vitaminK)
        if entry.vitaminK != nil && meal.vitaminK > 0 { meal.vitaminKIsGuess = false }

        meal.calcium = fillVitaminMineralInt(meal.calcium, isGuess: meal.calciumIsGuess, with: entry.calcium)
        if entry.calcium != nil && meal.calcium > 0 { meal.calciumIsGuess = false }

        meal.iron = fillVitaminMineralInt(meal.iron, isGuess: meal.ironIsGuess, with: entry.iron)
        if entry.iron != nil && meal.iron > 0 { meal.ironIsGuess = false }

        meal.potassium = fillVitaminMineralDouble(meal.potassium, isGuess: meal.potassiumIsGuess, with: entry.potassium)
        if entry.potassium != nil && meal.potassium > 0 { meal.potassiumIsGuess = false }

        meal.zinc = fillVitaminMineralInt(meal.zinc, isGuess: meal.zincIsGuess, with: entry.zinc)
        if entry.zinc != nil && meal.zinc > 0 { meal.zincIsGuess = false }

        meal.magnesium = fillVitaminMineralInt(meal.magnesium, isGuess: meal.magnesiumIsGuess, with: entry.magnesium)
        if entry.magnesium != nil && meal.magnesium > 0 { meal.magnesiumIsGuess = false }

        try? context.save()
    }
}

// MARK: - Sanitization using UI thresholds (per-field omission)
private extension BarcodeRepository {
    // Returns a copy of the entry with any “red” fields nilled out, and the list of dropped field keys.
    func sanitize(entry e: LocalBarcodeDB.Entry) -> (LocalBarcodeDB.Entry, [String]) {
        var dropped: [String] = []

        func keepInt(_ value: Int?, thresholds: ValidationThresholds, key: String) -> Int? {
            guard let v = value else { return nil }
            if thresholds.severity(for: v) == .stupid { dropped.append(key); return nil }
            return max(0, v)
        }

        func keepDouble(_ value: Double?, thresholds: ValidationThresholds, key: String) -> Double? {
            guard let v = value else { return nil }
            if thresholds.severityDouble(v) == .stupid { dropped.append(key); return nil }
            return max(0.0, v)
        }

        // Build sanitized entry
        let sanitized = LocalBarcodeDB.Entry(
            code: e.code,
            calories: keepInt(e.calories, thresholds: .calories, key: "calories"),
            carbohydrates: keepDouble(e.carbohydrates, thresholds: .grams, key: "carbohydrates"),
            protein: keepDouble(e.protein, thresholds: .grams, key: "protein"),
            fat: keepDouble(e.fat, thresholds: .grams, key: "fat"),
            sodiumMg: keepInt(e.sodiumMg, thresholds: .sodiumMg, key: "sodiumMg"),

            sugars: keepDouble(e.sugars, thresholds: .grams, key: "sugars"),
            starch: keepDouble(e.starch, thresholds: .grams, key: "starch"),
            fibre: keepDouble(e.fibre, thresholds: .grams, key: "fibre"),

            monounsaturatedFat: keepDouble(e.monounsaturatedFat, thresholds: .grams, key: "monounsaturatedFat"),
            polyunsaturatedFat: keepDouble(e.polyunsaturatedFat, thresholds: .grams, key: "polyunsaturatedFat"),
            saturatedFat: keepDouble(e.saturatedFat, thresholds: .grams, key: "saturatedFat"),
            transFat: keepDouble(e.transFat, thresholds: .grams, key: "transFat"),

            animalProtein: keepDouble(e.animalProtein, thresholds: .grams, key: "animalProtein"),
            plantProtein: keepDouble(e.plantProtein, thresholds: .grams, key: "plantProtein"),
            proteinSupplements: keepDouble(e.proteinSupplements, thresholds: .grams, key: "proteinSupplements"),
            a2BetaCasein: keepDouble(e.a2BetaCasein, thresholds: .grams, key: "a2BetaCasein"),

            vitaminA: keepDouble(e.vitaminA, thresholds: .vitaminMineralMg, key: "vitaminA"),
            vitaminB: keepDouble(e.vitaminB, thresholds: .vitaminMineralMg, key: "vitaminB"),
            vitaminC: keepDouble(e.vitaminC, thresholds: .vitaminMineralMg, key: "vitaminC"),
            vitaminD: keepDouble(e.vitaminD, thresholds: .vitaminMineralMg, key: "vitaminD"),
            vitaminE: keepDouble(e.vitaminE, thresholds: .vitaminMineralMg, key: "vitaminE"),
            vitaminK: keepDouble(e.vitaminK, thresholds: .vitaminMineralMg, key: "vitaminK"),

            calcium: keepInt(e.calcium, thresholds: .vitaminMineralMg, key: "calcium"),
            iron: keepInt(e.iron, thresholds: .vitaminMineralMg, key: "iron"),
            potassium: keepDouble(e.potassium, thresholds: .vitaminMineralMg, key: "potassium"),
            zinc: keepInt(e.zinc, thresholds: .vitaminMineralMg, key: "zinc"),
            magnesium: keepInt(e.magnesium, thresholds: .vitaminMineralMg, key: "magnesium")
        )

        return (sanitized, dropped)
    }

    // Strict sanity: return list of fields that are “insane” (.stupid threshold, negative, NaN/∞)
    func insaneFields(in e: LocalBarcodeDB.Entry) -> [String] {
        var bad: [String] = []

        func isInsaneInt(_ v: Int?, thresholds: ValidationThresholds) -> Bool {
            guard let v else { return false }
            if v < 0 { return true }
            return thresholds.severity(for: v) == .stupid
        }
        func isInsaneDouble(_ v: Double?, thresholds: ValidationThresholds) -> Bool {
            guard let v else { return false }
            if v.isNaN || v.isInfinite || v < 0 { return true }
            return thresholds.severityDouble(v) == .stupid
        }

        if isInsaneInt(e.calories, thresholds: .calories) { bad.append("calories") }
        if isInsaneDouble(e.carbohydrates, thresholds: .grams) { bad.append("carbohydrates") }
        if isInsaneDouble(e.protein, thresholds: .grams) { bad.append("protein") }
        if isInsaneDouble(e.fat, thresholds: .grams) { bad.append("fat") }
        if isInsaneInt(e.sodiumMg, thresholds: .sodiumMg) { bad.append("sodiumMg") }

        if isInsaneDouble(e.sugars, thresholds: .grams) { bad.append("sugars") }
        if isInsaneDouble(e.starch, thresholds: .grams) { bad.append("starch") }
        if isInsaneDouble(e.fibre, thresholds: .grams) { bad.append("fibre") }

        if isInsaneDouble(e.monounsaturatedFat, thresholds: .grams) { bad.append("monounsaturatedFat") }
        if isInsaneDouble(e.polyunsaturatedFat, thresholds: .grams) { bad.append("polyunsaturatedFat") }
        if isInsaneDouble(e.saturatedFat, thresholds: .grams) { bad.append("saturatedFat") }
        if isInsaneDouble(e.transFat, thresholds: .grams) { bad.append("transFat") }

        if isInsaneDouble(e.animalProtein, thresholds: .grams) { bad.append("animalProtein") }
        if isInsaneDouble(e.plantProtein, thresholds: .grams) { bad.append("plantProtein") }
        if isInsaneDouble(e.proteinSupplements, thresholds: .grams) { bad.append("proteinSupplements") }
        if isInsaneDouble(e.a2BetaCasein, thresholds: .grams) { bad.append("a2BetaCasein") }

        if isInsaneDouble(e.vitaminA, thresholds: .vitaminMineralMg) { bad.append("vitaminA") }
        if isInsaneDouble(e.vitaminB, thresholds: .vitaminMineralMg) { bad.append("vitaminB") }
        if isInsaneDouble(e.vitaminC, thresholds: .vitaminMineralMg) { bad.append("vitaminC") }
        if isInsaneDouble(e.vitaminD, thresholds: .vitaminMineralMg) { bad.append("vitaminD") }
        if isInsaneDouble(e.vitaminE, thresholds: .vitaminMineralMg) { bad.append("vitaminE") }
        if isInsaneDouble(e.vitaminK, thresholds: .vitaminMineralMg) { bad.append("vitaminK") }

        if isInsaneInt(e.calcium, thresholds: .vitaminMineralMg) { bad.append("calcium") }
        if isInsaneInt(e.iron, thresholds: .vitaminMineralMg) { bad.append("iron") }
        if isInsaneDouble(e.potassium, thresholds: .vitaminMineralMg) { bad.append("potassium") }
        if isInsaneInt(e.zinc, thresholds: .vitaminMineralMg) { bad.append("zinc") }
        if isInsaneInt(e.magnesium, thresholds: .vitaminMineralMg) { bad.append("magnesium") }

        return bad
    }
}

