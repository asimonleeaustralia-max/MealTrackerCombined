//
//  OpenFoodFactsClient.swift
//  MealTracker
//
//  Minimal OFF client to fetch product nutriments by barcode.
//  Emits structured barcode log events with source payloads and conversion steps.
//

import Foundation

// MARK: - Minimal Open Food Facts models (only fields used below)

struct Product: Codable {
    let code: String?
    let product_name: String?
    let nutriments: Nutriments?
}

struct Nutriments: Codable {
    // Energy (kcal preferred; kJ fallback)
    let energy_kcal_serving: Double?
    let energy_kcal_100g: Double?
    let energy_serving: Double?    // kJ per serving
    let energy_100g: Double?       // kJ per 100 g/ml

    // Macros (g)
    let carbohydrates_serving: Double?
    let carbohydrates_100g: Double?
    let proteins_serving: Double?
    let proteins_100g: Double?
    let fat_serving: Double?
    let fat_100g: Double?

    // Sodium/salt (g). OFF commonly encodes sodium in grams.
    let sodium_serving: Double?
    let sodium_100g: Double?
    let salt_serving: Double?
    let salt_100g: Double?

    // Sub-macros (g)
    let sugars_serving: Double?
    let sugars_100g: Double?
    let fiber_serving: Double?
    let fiber_100g: Double?

    // Fats breakdown (g)
    let monounsaturated_fat_serving: Double?
    let monounsaturated_fat_100g: Double?
    let polyunsaturated_fat_serving: Double?
    let polyunsaturated_fat_100g: Double?
    let saturated_fat_serving: Double?
    let saturated_fat_100g: Double?
    let trans_fat_serving: Double?
    let trans_fat_100g: Double?

    // Minerals (serving/100g) with units (mg/µg typically in unit fields)
    let calcium_serving: Double?
    let calcium_100g: Double?
    let calcium_unit: String?

    let iron_serving: Double?
    let iron_100g: Double?
    let iron_unit: String?

    let potassium_serving: Double?
    let potassium_100g: Double?
    let potassium_unit: String?

    let zinc_serving: Double?
    let zinc_100g: Double?
    let zinc_unit: String?

    let magnesium_serving: Double?
    let magnesium_100g: Double?
    let magnesium_unit: String?

    // Vitamins (serving/100g) with units
    let vitamin_a_serving: Double?
    let vitamin_a_100g: Double?
    let vitamin_a_unit: String?

    let vitamin_c_serving: Double?
    let vitamin_c_100g: Double?
    let vitamin_c_unit: String?

    let vitamin_d_serving: Double?
    let vitamin_d_100g: Double?
    let vitamin_d_unit: String?

    let vitamin_e_serving: Double?
    let vitamin_e_100g: Double?
    let vitamin_e_unit: String?

    let vitamin_k_serving: Double?
    let vitamin_k_100g: Double?
    let vitamin_k_unit: String?
}

struct OpenFoodFactsClient {

    private static func normalizedCode(_ code: String) -> String {
        code.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
    }

    // Networking: fetch product by barcode from OFF (v2 with v1 fallback)
    struct V2Response: Decodable {
        let status: Int?
        let status_verbose: String?
        let product: Product?
    }

    struct V1Response: Decodable {
        let status: Int?
        let status_verbose: String?
        let product: Product?
    }

    static func fetchProduct(by rawCode: String, logger: ((String) -> Void)? = nil) async throws -> Product {
        let code = normalizedCode(rawCode)
        let l = LocalizationManager(languageCode: LocalizationManager.defaultLanguageCode)

        // Try v2 first
        if let prod = try await fetchProductV2(code: code, logger: logger) { return prod }
        // Fallback to v1 if v2 not found
        if let prod = try await fetchProductV1(code: code, logger: logger) { return prod }

        let fmt = l.localized("wizard_off_not_found_format") // "OFF: not found %@"
        #if DEBUG
        logger?(String(format: fmt, code))
        await BarcodeLogStore.shared.appendEvent(
            .init(stage: .offDecodeError, codeRaw: rawCode, codeNormalized: code, error: "OFF not found")
        )
        #endif
        let errFmt = l.localized("wizard_off_product_not_found_error_format") // "Product %@ not found"
        let err = NSError(domain: "OpenFoodFactsClient", code: 404, userInfo: [NSLocalizedDescriptionKey: String(format: errFmt, code)])
        throw err
    }

    private static func fetchProductV2(code: String, logger: ((String) -> Void)?) async throws -> Product? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v2/product/\(code).json") else { return nil }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else { return nil }
        do {
            let decoded = try JSONDecoder().decode(V2Response.self, from: data)
            if let status = decoded.status, status == 1, let product = decoded.product {
                #if DEBUG
                let src = BarcodeLogPretty.compactJSON(product) ?? ""
                await BarcodeLogStore.shared.appendEvent(
                    .init(stage: .offFetchV2, codeRaw: product.code, codeNormalized: normalizedCode(product.code ?? code), sourceJSON: src)
                )
                #endif
                return product
            } else {
                let l = LocalizationManager(languageCode: LocalizationManager.defaultLanguageCode)
                let fmt = l.localized("wizard_off_v2_status_format") // "OFF v2: status %d %@ for code %@"
                let msg = String(format: fmt, decoded.status ?? -1, decoded.status_verbose ?? "", code)
                logger?(msg)
                #if DEBUG
                await BarcodeLogStore.shared.appendEvent(
                    .init(stage: .offDecodeError, codeRaw: code, codeNormalized: code, error: msg)
                )
                #endif
                return nil
            }
        } catch {
            let l = LocalizationManager(languageCode: LocalizationManager.defaultLanguageCode)
            let fmt = l.localized("wizard_off_v2_decode_error_format") // "OFF v2: decode error for %@: %@"
            let msg = String(format: fmt, code, error.localizedDescription)
            logger?(msg)
            #if DEBUG
            await BarcodeLogStore.shared.appendEvent(
                .init(stage: .offDecodeError, codeRaw: code, codeNormalized: code, error: msg)
            )
            #endif
            return nil
        }
    }

    private static func fetchProductV1(code: String, logger: ((String) -> Void)?) async throws -> Product? {
        guard let url = URL(string: "https://world.openfoodfacts.org/api/v0/product/\(code).json") else { return nil }
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else { return nil }
        do {
            let decoded = try JSONDecoder().decode(V1Response.self, from: data)
            if let status = decoded.status, status == 1, let product = decoded.product {
                #if DEBUG
                let src = BarcodeLogPretty.compactJSON(product) ?? ""
                await BarcodeLogStore.shared.appendEvent(
                    .init(stage: .offFetchV1, codeRaw: product.code, codeNormalized: normalizedCode(product.code ?? code), sourceJSON: src)
                )
                #endif
                return product
            } else {
                let l = LocalizationManager(languageCode: LocalizationManager.defaultLanguageCode)
                let fmt = l.localized("wizard_off_v1_status_format") // "OFF v1: status %d %@ for code %@"
                let msg = String(format: fmt, decoded.status ?? -1, decoded.status_verbose ?? "", code)
                logger?(msg)
                #if DEBUG
                await BarcodeLogStore.shared.appendEvent(
                    .init(stage: .offDecodeError, codeRaw: code, codeNormalized: code, error: msg)
                )
                #endif
                return nil
            }
        } catch {
            let l = LocalizationManager(languageCode: LocalizationManager.defaultLanguageCode)
            let fmt = l.localized("wizard_off_v1_decode_error_format") // "OFF v1: decode error for %@: %@"
            let msg = String(format: fmt, code, error.localizedDescription)
            logger?(msg)
            #if DEBUG
            await BarcodeLogStore.shared.appendEvent(
                .init(stage: .offDecodeError, codeRaw: code, codeNormalized: code, error: msg)
            )
            #endif
            return nil
        }
    }

    // Map OFF Product -> LocalBarcodeDB.Entry (units: kcal, g, mg), emitting conversion steps
    static func mapToEntry(from product: Product) -> LocalBarcodeDB.Entry? {
        guard let nutr = product.nutriments else { return nil }

        #if DEBUG
        var steps: [String] = []
        #endif

        func toIntNonNegative(_ d: Double?) -> Int? {
            guard let d else { return nil }
            return max(0, Int((d).rounded()))
        }

        func toDoubleNonNegative(_ d: Double?) -> Double? {
            guard let d else { return nil }
            return max(0.0, d)
        }

        // Energy kcal
        let kcal: Int? = {
            if let v = nutr.energy_kcal_serving ?? nutr.energy_kcal_100g {
                #if DEBUG
                if let s = nutr.energy_kcal_serving { steps.append("energy: \(s) kcal (serving) -> \(Int(s.rounded())) kcal") }
                else if let h = nutr.energy_kcal_100g { steps.append("energy: \(h) kcal (100g) -> \(Int(h.rounded())) kcal") }
                #endif
                return toIntNonNegative(v)
            }
            if let kj = nutr.energy_serving ?? nutr.energy_100g {
                #if DEBUG
                steps.append("energy: \(kj) kJ -> \(Int((kj / 4.184).rounded())) kcal")
                #endif
                return toIntNonNegative(kj / 4.184)
            }
            return nil
        }()

        // Macros in grams (preserve decimals)
        let carbs = toDoubleNonNegative(nutr.carbohydrates_serving ?? nutr.carbohydrates_100g)
        #if DEBUG
        if let s = nutr.carbohydrates_serving { steps.append("carbohydrates: \(s) g (serving) -> \(s) g") }
        else if let h = nutr.carbohydrates_100g { steps.append("carbohydrates: \(h) g (100g) -> \(h) g") }
        #endif

        let protein = toDoubleNonNegative(nutr.proteins_serving ?? nutr.proteins_100g)
        #if DEBUG
        if let s = nutr.proteins_serving { steps.append("protein: \(s) g (serving) -> \(s) g") }
        else if let h = nutr.proteins_100g { steps.append("protein: \(h) g (100g) -> \(h) g") }
        #endif

        let fat = toDoubleNonNegative(nutr.fat_serving ?? nutr.fat_100g)
        #if DEBUG
        if let s = nutr.fat_serving { steps.append("fat: \(s) g (serving) -> \(s) g") }
        else if let h = nutr.fat_100g { steps.append("fat: \(h) g (100g) -> \(h) g") }
        #endif

        // Sodium mg
        let sodiumMg: Int? = {
            if let sG = nutr.sodium_serving ?? nutr.sodium_100g {
                #if DEBUG
                steps.append("sodium: \(sG) g -> \(Int((sG * 1000).rounded())) mg")
                #endif
                return toIntNonNegative(sG * 1000.0)
            }
            if let saltG = nutr.salt_serving ?? nutr.salt_100g {
                #if DEBUG
                steps.append("salt: \(saltG) g -> sodium ≈ \(Int((saltG * 400.0).rounded())) mg (1 g salt ≈ 400 mg sodium)")
                #endif
                return toIntNonNegative(saltG * 400.0)
            }
            return nil
        }()

        // Sub-macros
        let sugars = toDoubleNonNegative(nutr.sugars_serving ?? nutr.sugars_100g)
        #if DEBUG
        if let s = nutr.sugars_serving { steps.append("sugars: \(s) g (serving) -> \(s) g") }
        else if let h = nutr.sugars_100g { steps.append("sugars: \(h) g (100g) -> \(h) g") }
        #endif

        let fibre = toDoubleNonNegative(nutr.fiber_serving ?? nutr.fiber_100g)
        #if DEBUG
        if let s = nutr.fiber_serving { steps.append("fibre: \(s) g (serving) -> \(s) g") }
        else if let h = nutr.fiber_100g { steps.append("fibre: \(h) g (100g) -> \(h) g") }
        #endif

        let starch: Double? = nil

        // Fat breakdown (grams)
        let monounsaturatedFat = toDoubleNonNegative(nutr.monounsaturated_fat_serving ?? nutr.monounsaturated_fat_100g)
        let polyunsaturatedFat = toDoubleNonNegative(nutr.polyunsaturated_fat_serving ?? nutr.polyunsaturated_fat_100g)
        let saturatedFat = toDoubleNonNegative(nutr.saturated_fat_serving ?? nutr.saturated_fat_100g)
        let transFat = toDoubleNonNegative(nutr.trans_fat_serving ?? nutr.trans_fat_100g)
        #if DEBUG
        if let v = nutr.monounsaturated_fat_serving ?? nutr.monounsaturated_fat_100g { steps.append("mono: \(v) g -> \(v) g") }
        if let v = nutr.polyunsaturated_fat_serving ?? nutr.polyunsaturated_fat_100g { steps.append("poly: \(v) g -> \(v) g") }
        if let v = nutr.saturated_fat_serving ?? nutr.saturated_fat_100g { steps.append("saturated: \(v) g -> \(v) g") }
        if let v = nutr.trans_fat_serving ?? nutr.trans_fat_100g { steps.append("trans: \(v) g -> \(v) g") }
        #endif

        // Protein breakdown not provided by OFF
        let animalProtein: Double? = nil
        let plantProtein: Double? = nil
        let proteinSupplements: Double? = nil
        // New: A2 beta-casein not provided by OFF
        let a2BetaCasein: Double? = nil

        // New: Double-preserving mg converter (µg -> mg by /1000.0, no rounding)
        func toMgDouble(_ value: Double?, unit: String?, label: String) -> Double? {
            guard let value else { return nil }
            let u = (unit ?? "").lowercased()
            if u.contains("µg") || u.contains("mcg") || u.contains("ug") {
                #if DEBUG
                steps.append("\(label): \(value) µg -> \(value / 1000.0) mg")
                #endif
                return max(0.0, value / 1000.0)
            }
            #if DEBUG
            steps.append("\(label): \(value) mg -> \(value) mg")
            #endif
            return max(0.0, value)
        }

        // Vitamins (Double? mg)
        let vitaminA = toMgDouble(nutr.vitamin_a_serving ?? nutr.vitamin_a_100g, unit: nutr.vitamin_a_unit, label: "vitaminA")
        let vitaminB: Double? = nil
        let vitaminC = toMgDouble(nutr.vitamin_c_serving ?? nutr.vitamin_c_100g, unit: nutr.vitamin_c_unit, label: "vitaminC")
        let vitaminD = toMgDouble(nutr.vitamin_d_serving ?? nutr.vitamin_d_100g, unit: nutr.vitamin_d_unit, label: "vitaminD")
        let vitaminE = toMgDouble(nutr.vitamin_e_serving ?? nutr.vitamin_e_100g, unit: nutr.vitamin_e_unit, label: "vitaminE")
        let vitaminK = toMgDouble(nutr.vitamin_k_serving ?? nutr.vitamin_k_100g, unit: nutr.vitamin_k_unit, label: "vitaminK")

        // Minerals (mg), with potassium now Double?
        // Keep other minerals as Int? unless/ until you want them fractional too.
        func toMgInt(_ value: Double?, unit: String?, label: String) -> Int? {
            guard let v = toMgDouble(value, unit: unit, label: label) else { return nil }
            return max(0, Int(v.rounded()))
        }

        let calcium = toMgInt(nutr.calcium_serving ?? nutr.calcium_100g, unit: nutr.calcium_unit, label: "calcium")
        let iron = toMgInt(nutr.iron_serving ?? nutr.iron_100g, unit: nutr.iron_unit, label: "iron")
        let potassium = toMgDouble(nutr.potassium_serving ?? nutr.potassium_100g, unit: nutr.potassium_unit, label: "potassium")
        let zinc = toMgInt(nutr.zinc_serving ?? nutr.zinc_100g, unit: nutr.zinc_unit, label: "zinc")
        let magnesium = toMgInt(nutr.magnesium_serving ?? nutr.magnesium_100g, unit: nutr.magnesium_unit, label: "magnesium")

        let hasAny =
            kcal != nil || carbs != nil || protein != nil || fat != nil || sodiumMg != nil ||
            sugars != nil || fibre != nil || monounsaturatedFat != nil || polyunsaturatedFat != nil ||
            saturatedFat != nil || transFat != nil || vitaminA != nil || vitaminC != nil ||
            vitaminD != nil || vitaminE != nil || vitaminK != nil || calcium != nil || iron != nil ||
            potassium != nil || zinc != nil || magnesium != nil

        guard hasAny else { return nil }

        let code = normalizedCode(product.code ?? "")

        let entry = LocalBarcodeDB.Entry(
            code: code.isEmpty ? (product.code ?? "") : code,
            calories: kcal,
            carbohydrates: carbs,
            protein: protein,
            fat: fat,
            sodiumMg: sodiumMg,
            sugars: sugars,
            starch: starch,
            fibre: fibre,
            monounsaturatedFat: monounsaturatedFat,
            polyunsaturatedFat: polyunsaturatedFat,
            saturatedFat: saturatedFat,
            transFat: transFat,
            animalProtein: animalProtein,
            plantProtein: plantProtein,
            proteinSupplements: proteinSupplements,
            a2BetaCasein: a2BetaCasein,
            vitaminA: vitaminA,
            vitaminB: vitaminB,
            vitaminC: vitaminC,
            vitaminD: vitaminD,
            vitaminE: vitaminE,
            vitaminK: vitaminK,
            calcium: calcium,
            iron: iron,
            potassium: potassium,
            zinc: zinc,
            magnesium: magnesium
        )

        #if DEBUG
        Task {
            await BarcodeLogStore.shared.appendEvent(
                .init(stage: .offMapResult,
                      codeRaw: product.code,
                      codeNormalized: code.isEmpty ? (product.code ?? "") : code,
                      conversions: steps,
                      entry: entry)
            )
        }
        #endif

        return entry
    }
}

