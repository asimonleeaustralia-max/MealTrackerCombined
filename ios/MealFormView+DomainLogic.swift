//
//  MealFormView+DomainLogic.swift
//  MealTracker
//
//  Extracted wizard/analysis/validation/saving/consistency/autofill/utilities from MealFormView+Logic.swift
//

import SwiftUI
import CoreData
import CoreLocation
import UIKit
import AVFoundation
import Vision
import CryptoKit

extension MealFormView {

    // Snapshot of wizard-editable fields and flags for undo
    struct WizardSnapshot {
        let calories: String
        let carbohydrates: String
        let protein: String
        let sodium: String
        let fat: String

        let alcohol: String
        let nicotine: String
        let theobromine: String
        let caffeine: String
        let taurine: String

        let starch: String
        let sugars: String
        let fibre: String

        let monounsaturatedFat: String
        let polyunsaturatedFat: String
        let saturatedFat: String
        let transFat: String
        let omega3: String
        let omega6: String

        let animalProtein: String
        let plantProtein: String
        let proteinSupplements: String
        let a2BetaCasein: String
        let a1BetaCasein: String

        let vitaminA: String
        let vitaminB: String
        let vitaminC: String
        let vitaminD: String
        let vitaminE: String
        let vitaminK: String

        let calcium: String
        let iron: String
        let potassium: String
        let zinc: String
        let magnesium: String
        let iodine: String
        let phosphorus: String

        // Guess flags
        let caloriesIsGuess: Bool
        let carbohydratesIsGuess: Bool
        let proteinIsGuess: Bool
        let sodiumIsGuess: Bool
        let fatIsGuess: Bool

        let alcoholIsGuess: Bool
        let nicotineIsGuess: Bool
        let theobromineIsGuess: Bool
        let caffeineIsGuess: Bool
        let taurineIsGuess: Bool

        let starchIsGuess: Bool
        let sugarsIsGuess: Bool
        let fibreIsGuess: Bool

        let monounsaturatedFatIsGuess: Bool
        let polyunsaturatedFatIsGuess: Bool
        let saturatedFatIsGuess: Bool
        let transFatIsGuess: Bool
        let omega3IsGuess: Bool
        let omega6IsGuess: Bool

        let animalProteinIsGuess: Bool
        let plantProteinIsGuess: Bool
        let proteinSupplementsIsGuess: Bool
        let a2BetaCaseinIsGuess: Bool
        let a1BetaCaseinIsGuess: Bool

        let vitaminAIsGuess: Bool
        let vitaminBIsGuess: Bool
        let vitaminCIsGuess: Bool
        let vitaminDIsGuess: Bool
        let vitaminEIsGuess: Bool
        let vitaminKIsGuess: Bool

        let calciumIsGuess: Bool
        let ironIsGuess: Bool
        let potassiumIsGuess: Bool
        let zincIsGuess: Bool
        let magnesiumIsGuess: Bool
        let iodineIsGuess: Bool
        let phosphorusIsGuess: Bool
    }

    // MARK: - Analyze button logic

    func applyIfEmpty(_ source: inout String, with value: Int?, markGuess: inout Bool) {
        guard let v = value, source.isEmpty else { return }
        source = String(max(0, v))
        // Label/OCR-derived values are accurate
        markGuess = false
    }

    // Overload for Double? (grams), preserving decimals with cleanString
    func applyIfEmpty(_ source: inout String, with value: Double?, markGuess: inout Bool) {
        guard let v = value, source.isEmpty else { return }
        source = max(0.0, v).cleanString
        // Label/OCR-derived values are accurate
        markGuess = false
    }

    // Wrapper: SHA-256 of normalized OCR text -> hex string (for synthetic keys)
    private func sha256Hex(of text: String) -> String {
        let data = Data(text.utf8)
        let digest = SHA256.hash(data: data)
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    // Strict sanity for OCR/label guess: returns list of insane fields (.stupid, negative, NaN/∞)
    private func insaneFields(in g: PhotoNutritionGuesser.GuessResult) -> [String] {
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

        if isInsaneInt(g.calories, thresholds: .calories) { bad.append("calories") }
        if isInsaneDouble(g.carbohydrates, thresholds: .grams) { bad.append("carbohydrates") }
        if isInsaneDouble(g.protein, thresholds: .grams) { bad.append("protein") }
        if isInsaneDouble(g.fat, thresholds: .grams) { bad.append("fat") }
        if isInsaneInt(g.sodiumMg, thresholds: .sodiumMg) { bad.append("sodium") }

        if isInsaneDouble(g.sugars, thresholds: .grams) { bad.append("sugars") }
        if isInsaneDouble(g.starch, thresholds: .grams) { bad.append("starch") }
        if isInsaneDouble(g.fibre, thresholds: .grams) { bad.append("fibre") }

        if isInsaneDouble(g.monounsaturatedFat, thresholds: .grams) { bad.append("monounsaturatedFat") }
        if isInsaneDouble(g.polyunsaturatedFat, thresholds: .grams) { bad.append("polyunsaturatedFat") }
        if isInsaneDouble(g.saturatedFat, thresholds: .grams) { bad.append("saturatedFat") }
        if isInsaneDouble(g.transFat, thresholds: .grams) { bad.append("transFat") }

        if isInsaneDouble(g.animalProtein, thresholds: .grams) { bad.append("animalProtein") }
        if isInsaneDouble(g.plantProtein, thresholds: .grams) { bad.append("plantProtein") }
        if isInsaneDouble(g.proteinSupplements, thresholds: .grams) { bad.append("proteinSupplements") }
        if isInsaneDouble(g.a2BetaCasein, thresholds: .grams) { bad.append("a2BetaCasein") }
        if isInsaneDouble(g.a1BetaCasein, thresholds: .grams) { bad.append("a1BetaCasein") }

        if isInsaneDouble(g.vitaminA, thresholds: .vitaminMineralMg) { bad.append("vitaminA") }
        if isInsaneDouble(g.vitaminB, thresholds: .vitaminMineralMg) { bad.append("vitaminB") }
        if isInsaneDouble(g.vitaminC, thresholds: .vitaminMineralMg) { bad.append("vitaminC") }
        if isInsaneDouble(g.vitaminD, thresholds: .vitaminMineralMg) { bad.append("vitaminD") }
        if isInsaneDouble(g.vitaminE, thresholds: .vitaminMineralMg) { bad.append("vitaminE") }
        if isInsaneDouble(g.vitaminK, thresholds: .vitaminMineralMg) { bad.append("vitaminK") }

        if isInsaneInt(g.calcium, thresholds: .vitaminMineralMg) { bad.append("calcium") }
        if isInsaneInt(g.iron, thresholds: .vitaminMineralMg) { bad.append("iron") }
        if isInsaneDouble(g.potassium, thresholds: .vitaminMineralMg) { bad.append("potassium") }
        if isInsaneInt(g.zinc, thresholds: .vitaminMineralMg) { bad.append("zinc") }
        if isInsaneInt(g.magnesium, thresholds: .vitaminMineralMg) { bad.append("magnesium") }
        if isInsaneDouble(g.iodine, thresholds: .vitaminMineralMg) { bad.append("iodine") }
        if isInsaneDouble(g.phosphorus, thresholds: .vitaminMineralMg) { bad.append("phosphorus") }

        // Stimulants/supplements (use grams for alcohol, mg thresholds for others)
        if isInsaneDouble(g.alcohol, thresholds: .grams) { bad.append("alcohol") }
        if isInsaneInt(g.nicotineMg, thresholds: .vitaminMineralMg) { bad.append("nicotine") }
        if isInsaneInt(g.theobromineMg, thresholds: .vitaminMineralMg) { bad.append("theobromine") }
        if isInsaneInt(g.caffeineMg, thresholds: .vitaminMineralMg) { bad.append("caffeine") }
        if isInsaneInt(g.taurineMg, thresholds: .vitaminMineralMg) { bad.append("taurine") }
        if isInsaneInt(g.creatineMg, thresholds: .vitaminMineralMg) { bad.append("creatine") }

        return bad
    }

    // NEW: Mirror any values the repository applied to the Meal into the on-screen form (empty-only).
    // Returns true if any field was filled.
    private func applyMealToFormIfEmpty(_ m: Meal) -> Bool {
        var filledAny = false

        func setIfEmptyDouble(_ target: inout String, _ value: Double, _ flag: inout Bool) {
            guard target.isEmpty, value > 0 else { return }
            target = value.cleanString
            flag = false
            filledAny = true
        }
        func setIfEmptyInt(_ target: inout String, _ value: Double, _ flag: inout Bool) {
            guard target.isEmpty, value > 0 else { return }
            target = String(Int(value.rounded()))
            flag = false
            filledAny = true
        }
        
        // Updated: also fill if current value is zero or a guess (matches barcode repository behavior)
        func setIfEmptyOrZeroOrGuessDouble(_ target: inout String, _ value: Double, _ flag: inout Bool) {
            let currentValue = Double(target.replacingOccurrences(of: ",", with: ".")) ?? 0
            guard (target.isEmpty || currentValue <= 0 || flag), value > 0 else { return }
            target = value.cleanString
            flag = false
            filledAny = true
        }
        func setIfEmptyOrZeroOrGuessInt(_ target: inout String, _ value: Double, _ flag: inout Bool) {
            let currentValue = Double(Int(target) ?? 0)
            guard (target.isEmpty || currentValue <= 0 || flag), value > 0 else { return }
            target = String(Int(value.rounded()))
            flag = false
            filledAny = true
        }
        
        func formatMG(_ mg: Double) -> String {
            let nf = NumberFormatter()
            nf.locale = Locale.current
            nf.minimumFractionDigits = 0
            nf.maximumFractionDigits = 3
            nf.minimumIntegerDigits = 1
            return nf.string(from: NSNumber(value: mg)) ?? mg.cleanString
        }

        // kcal - use new helper to fill if empty, zero, or guess
        setIfEmptyOrZeroOrGuessInt(&calories, m.calories, &caloriesIsGuess)

        // grams - use new helpers to override zero/guess values too
        setIfEmptyOrZeroOrGuessDouble(&carbohydrates, m.carbohydrates, &carbohydratesIsGuess)
        setIfEmptyOrZeroOrGuessDouble(&protein, m.protein, &proteinIsGuess)
        setIfEmptyOrZeroOrGuessDouble(&fat, m.fat, &fatIsGuess)

        // sodium UI - updated to fill if zero or guess
        let currentSodiumValue: Double
        if sodiumUnit == .milligrams {
            currentSodiumValue = Double(Int(sodium) ?? 0)
        } else {
            currentSodiumValue = Double(sodium.replacingOccurrences(of: ",", with: ".")) ?? 0
        }
        if (sodium.isEmpty || currentSodiumValue <= 0 || sodiumIsGuess), m.sodium > 0 {
            if sodiumUnit == .milligrams {
                sodium = String(Int(m.sodium.rounded()))
            } else {
                sodium = (m.sodium / 1000.0).cleanString
            }
            sodiumIsGuess = false
            filledAny = true
        }

        // sub-macros (grams) - use new helpers
        setIfEmptyOrZeroOrGuessDouble(&sugars, m.sugars, &sugarsIsGuess)
        setIfEmptyOrZeroOrGuessDouble(&starch, m.starch, &starchIsGuess)
        setIfEmptyOrZeroOrGuessDouble(&fibre, m.fibre, &fibreIsGuess)

        // fat breakdown (grams) - use new helpers
        setIfEmptyOrZeroOrGuessDouble(&monounsaturatedFat, m.monounsaturatedFat, &monounsaturatedFatIsGuess)
        setIfEmptyOrZeroOrGuessDouble(&polyunsaturatedFat, m.polyunsaturatedFat, &polyunsaturatedFatIsGuess)
        setIfEmptyOrZeroOrGuessDouble(&saturatedFat, m.saturatedFat, &saturatedFatIsGuess)
        setIfEmptyOrZeroOrGuessDouble(&transFat, m.transFat, &transFatIsGuess)

        // protein breakdown (grams) - use new helpers
        setIfEmptyOrZeroOrGuessDouble(&animalProtein, m.animalProtein, &animalProteinIsGuess)
        setIfEmptyOrZeroOrGuessDouble(&plantProtein, m.plantProtein, &plantProteinIsGuess)
        setIfEmptyOrZeroOrGuessDouble(&proteinSupplements, m.proteinSupplements, &proteinSupplementsIsGuess)
        setIfEmptyOrZeroOrGuessDouble(&a2BetaCasein, m.a2BetaCasein, &a2BetaCaseinIsGuess)
        setIfEmptyOrZeroOrGuessDouble(&a1BetaCasein, m.a1BetaCasein, &a1BetaCaseinIsGuess)

        // Vitamins/minerals (stored mg) - updated to fill if zero or guess
        func setVitaminUI(_ target: inout String, _ mg: Double, _ flag: inout Bool) {
            let currentValue: Double
            switch vitaminsUnit {
            case .milligrams:
                currentValue = Double(target.replacingOccurrences(of: ",", with: ".")) ?? 0
            case .micrograms:
                currentValue = Double(Int(target) ?? 0) / 1000.0 // convert µg UI to mg for comparison
            }
            guard (target.isEmpty || currentValue <= 0 || flag), mg > 0 else { return }
            switch vitaminsUnit {
            case .milligrams:
                target = formatMG(mg)
            case .micrograms:
                target = String(Int((mg * 1000.0).rounded()))
            }
            flag = false
            filledAny = true
        }
        // Vitamins
        setVitaminUI(&vitaminA, m.vitaminA, &vitaminAIsGuess)
        setVitaminUI(&vitaminB, m.vitaminB, &vitaminBIsGuess)
        setVitaminUI(&vitaminC, m.vitaminC, &vitaminCIsGuess)
        setVitaminUI(&vitaminD, m.vitaminD, &vitaminDIsGuess)
        setVitaminUI(&vitaminE, m.vitaminE, &vitaminEIsGuess)
        setVitaminUI(&vitaminK, m.vitaminK, &vitaminKIsGuess)

        // Minerals
        setVitaminUI(&calcium, m.calcium, &calciumIsGuess)
        setVitaminUI(&iron, m.iron, &ironIsGuess)
        setVitaminUI(&potassium, m.potassium, &potassiumIsGuess)
        setVitaminUI(&zinc, m.zinc, &zincIsGuess)
        setVitaminUI(&magnesium, m.magnesium, &magnesiumIsGuess)
        setVitaminUI(&iodine, m.iodine, &iodineIsGuess)
        setVitaminUI(&phosphorus, m.phosphorus, &phosphorusIsGuess)

        // Recompute group helpers/mismatch
        if filledAny {
            recomputeConsistency(resetPrevMismatch: false)
        }
        return filledAny
    }

    // Wrap analyzePhoto() to manage snapshot and undo state
    func analyzePhotoWithSnapshot() async {
        let l = LocalizationManager(languageCode: appLanguageCode)

        // Gate: need at least one image
        guard !galleryItems.isEmpty else {
            await MainActor.run {
                analyzeError = l.localized("wizard_add_photo_first")
            }
            return
        }

        await MainActor.run {
            isAnalyzing = true
            analyzeError = nil
            wizardProgress = l.localized("wizard_analyzing_ellipsis") // "Analyzing…"
            // Capture snapshot for undo before we modify anything
            wizardUndoSnapshot = WizardSnapshot(
                calories: calories,
                carbohydrates: carbohydrates,
                protein: protein,
                sodium: sodium,
                fat: fat,
                alcohol: alcohol,
                nicotine: nicotine,
                theobromine: theobromine,
                caffeine: caffeine,
                taurine: taurine,
                starch: starch,
                sugars: sugars,
                fibre: fibre,
                monounsaturatedFat: monounsaturatedFat,
                polyunsaturatedFat: polyunsaturatedFat,
                saturatedFat: saturatedFat,
                transFat: transFat,
                omega3: omega3,
                omega6: omega6,
                animalProtein: animalProtein,
                plantProtein: plantProtein,
                proteinSupplements: proteinSupplements,
                a2BetaCasein: a2BetaCasein,
                a1BetaCasein: a1BetaCasein,
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
                magnesium: magnesium,
                iodine: iodine,
                phosphorus: phosphorus,
                caloriesIsGuess: caloriesIsGuess,
                carbohydratesIsGuess: carbohydratesIsGuess,
                proteinIsGuess: proteinIsGuess,
                sodiumIsGuess: sodiumIsGuess,
                fatIsGuess: fatIsGuess,
                alcoholIsGuess: alcoholIsGuess,
                nicotineIsGuess: nicotineIsGuess,
                theobromineIsGuess: theobromineIsGuess,
                caffeineIsGuess: caffeineIsGuess,
                taurineIsGuess: taurineIsGuess,
                starchIsGuess: starchIsGuess,
                sugarsIsGuess: sugarsIsGuess,
                fibreIsGuess: fibreIsGuess,
                monounsaturatedFatIsGuess: monounsaturatedFatIsGuess,
                polyunsaturatedFatIsGuess: polyunsaturatedFatIsGuess,
                saturatedFatIsGuess: saturatedFatIsGuess,
                transFatIsGuess: transFatIsGuess,
                omega3IsGuess: omega3IsGuess,
                omega6IsGuess: omega6IsGuess,
                animalProteinIsGuess: animalProteinIsGuess,
                plantProteinIsGuess: plantProteinIsGuess,
                proteinSupplementsIsGuess: proteinSupplementsIsGuess,
                a2BetaCaseinIsGuess: a2BetaCaseinIsGuess,
                a1BetaCaseinIsGuess: a1BetaCaseinIsGuess,
                vitaminAIsGuess: vitaminAIsGuess,
                vitaminBIsGuess: vitaminBIsGuess,
                vitaminCIsGuess: vitaminCIsGuess,
                vitaminDIsGuess: vitaminDIsGuess,
                vitaminEIsGuess: vitaminEIsGuess,
                vitaminKIsGuess: vitaminKIsGuess,
                calciumIsGuess: calciumIsGuess,
                ironIsGuess: ironIsGuess,
                potassiumIsGuess: potassiumIsGuess,
                zincIsGuess: zincIsGuess,
                magnesiumIsGuess: magnesiumIsGuess,
                iodineIsGuess: iodineIsGuess,
                phosphorusIsGuess: phosphorusIsGuess
            )
            // While analyzing, disable undo until we apply
            wizardCanUndo = false
        }

        // Load image data from the selected gallery item
        let item = galleryItems[min(max(0, selectedIndex), galleryItems.count - 1)]
        let imageData: Data?
        switch item {
        case .persistent(_, let url, _):
            imageData = try? Data(contentsOf: url)
        case .inMemory(_, _, let data, _, _):
            imageData = data
        }

        guard let data = imageData else {
            await MainActor.run {
                isAnalyzing = false
                wizardProgress = nil
                analyzeError = l.localized("wizard_could_not_read_image")
            }
            return
        }

        // OPTION A: Probe barcode first to show status and set lastDetectedBarcode; run repository lookups if found.
        if let uiImage = UIImage(data: data) {
            await MainActor.run { wizardProgress = l.localized("wizard_detecting_barcode") }
            // Try rotation variants for robustness (reuse PhotoNutritionGuesser helper)
            let variants = PhotoNutritionGuesser.rotationVariants(of: uiImage)
            var decodedCode: String? = nil
            for img in variants {
                if let code = await PhotoNutritionGuesser.detectFirstBarcode(in: img) {
                    decodedCode = code
                    break
                }
            }
            if let code = decodedCode, !code.isEmpty {
                await MainActor.run {
                    lastDetectedBarcode = code
                    wizardProgress = l.localized("wizard_looking_up_product")
                }
                // Ensure we have a Meal to apply to
                let m = ensureMealForPhoto()
                // Kick off local DB + OFF lookups; feed progress back into wizardProgress
                await BarcodeRepository.shared.handleScannedBarcode(
                    code,
                    for: m,
                    in: context,
                    sodiumUnit: sodiumUnit,
                    vitaminsUnit: vitaminsUnit,
                    logger: { msg in
                        Task { @MainActor in
                            // Only update while analyzing to avoid overwriting post-apply status
                            if isAnalyzing {
                                wizardProgress = msg
                            }
                        }
                    }
                )
                // Mirror any applied values from Meal into the on-screen form (fill empty-only).
                await MainActor.run {
                    let didFill = applyMealToFormIfEmpty(m)
                    if didFill {
                        wizardCanUndo = true
                        forceEnableSave = true
                    }
                }
            } else {
                await MainActor.run {
                    // Keep a subtle status to indicate we tried
                    if wizardProgress == l.localized("wizard_detecting_barcode") {
                        wizardProgress = l.localized("wizard_no_barcode_reading_label")
                    }
                }
            }
        }

        // Run the on-device pipeline (barcode -> OCR -> feature fallback)
        let parsed: PhotoNutritionGuesser.GuessResult
        do {
            if let guess = try await PhotoNutritionGuesser.guess(from: data, languageCode: appLanguageCode) {
                parsed = guess
            } else {
                await MainActor.run {
                    isAnalyzing = false
                    wizardProgress = nil
                    analyzeError = l.localized("wizard_no_label_recognized")
                }
                return
            }
        } catch {
            await MainActor.run {
                isAnalyzing = false
                wizardProgress = nil
                analyzeError = error.localizedDescription
            }
            return
        }

        // Strict sanity check for parsed label; reject entire apply if any insane
        let bad = insaneFields(in: parsed)
        if !bad.isEmpty {
            await MainActor.run {
                isAnalyzing = false
                wizardProgress = nil
                // "Label rejected: insane values in %@" where %@ = comma-joined field keys
                let fmt = l.localized("wizard_label_rejected_insane")
                analyzeError = String(format: fmt, bad.joined(separator: ", "))
                // Do not enable undo or apply anything
                wizardCanUndo = false
            }
            return
        }

        // Apply empty-only fields from parsed result
        await MainActor.run {
            var filled: [String] = []

            // calories (kcal)
            let beforeCalories = calories
            applyIfEmpty(&calories, with: parsed.calories, markGuess: &caloriesIsGuess)
            if calories != beforeCalories { filled.append("calories") }

            // grams
            let bCarb = carbohydrates
            applyIfEmpty(&carbohydrates, with: parsed.carbohydrates, markGuess: &carbohydratesIsGuess)
            if carbohydrates != bCarb { filled.append("carbohydrates") }

            let bProt = protein
            applyIfEmpty(&protein, with: parsed.protein, markGuess: &proteinIsGuess)
            if protein != bProt { filled.append("protein") }

            let bFat = fat
            applyIfEmpty(&fat, with: parsed.fat, markGuess: &fatIsGuess)
            if fat != bFat { filled.append("fat") }

            // sodium UI: parsed.sodiumMg is mg
            let bSodium = sodium
            if sodium.isEmpty, let mg = parsed.sodiumMg {
                if sodiumUnit == .milligrams {
                    sodium = String(max(0, mg))
                } else {
                    // convert mg -> g (rounded to preserve decimals)
                    sodium = (Double(mg) / 1000.0).cleanString
                }
                sodiumIsGuess = false
            }
            if sodium != bSodium { filled.append("sodium") }

            // sub-macros (grams)
            let bSug = sugars
            applyIfEmpty(&sugars, with: parsed.sugars, markGuess: &sugarsIsGuess)
            if sugars != bSug { filled.append("sugars") }

            let bSta = starch
            applyIfEmpty(&starch, with: parsed.starch, markGuess: &starchIsGuess)
            if starch != bSta { filled.append("starch") }

            let bFib = fibre
            applyIfEmpty(&fibre, with: parsed.fibre, markGuess: &fibreIsGuess)
            if fibre != bFib { filled.append("fibre") }

            // fat breakdown (grams)
            let bMono = monounsaturatedFat
            applyIfEmpty(&monounsaturatedFat, with: parsed.monounsaturatedFat, markGuess: &monounsaturatedFatIsGuess)
            if monounsaturatedFat != bMono { filled.append("monounsaturatedFat") }

            let bPoly = polyunsaturatedFat
            applyIfEmpty(&polyunsaturatedFat, with: parsed.polyunsaturatedFat, markGuess: &polyunsaturatedFatIsGuess)
            if polyunsaturatedFat != bPoly { filled.append("polyunsaturatedFat") }

            let bSat = saturatedFat
            applyIfEmpty(&saturatedFat, with: parsed.saturatedFat, markGuess: &saturatedFatIsGuess)
            if saturatedFat != bSat { filled.append("saturatedFat") }

            let bTrans = transFat
            applyIfEmpty(&transFat, with: parsed.transFat, markGuess: &transFatIsGuess)
            if transFat != bTrans { filled.append("transFat") }

            // protein breakdown (grams)
            let bAni = animalProtein
            applyIfEmpty(&animalProtein, with: parsed.animalProtein, markGuess: &animalProteinIsGuess)
            if animalProtein != bAni { filled.append("animalProtein") }

            let bPlant = plantProtein
            applyIfEmpty(&plantProtein, with: parsed.plantProtein, markGuess: &plantProteinIsGuess)
            if plantProtein != bPlant { filled.append("plantProtein") }

            let bSupp = proteinSupplements
            applyIfEmpty(&proteinSupplements, with: parsed.proteinSupplements, markGuess: &proteinSupplementsIsGuess)
            if proteinSupplements != bSupp { filled.append("proteinSupplements") }

            // New: A2 beta-casein (grams)
            let bA2 = a2BetaCasein
            applyIfEmpty(&a2BetaCasein, with: parsed.a2BetaCasein, markGuess: &a2BetaCaseinIsGuess)
            if a2BetaCasein != bA2 { filled.append("a2BetaCasein") }

            // New: A1 beta-casein (grams)
            let bA1 = a1BetaCasein
            applyIfEmpty(&a1BetaCasein, with: parsed.a1BetaCasein, markGuess: &a1BetaCaseinIsGuess)
            if a1BetaCasein != bA1 { filled.append("a1BetaCasein") }

            func setVitaminUI(_ target: inout String, _ valueMg: Double?, _ flag: inout Bool, name: String) {
                let before = target
                guard target.isEmpty, let mg = valueMg else { return }
                switch vitaminsUnit {
                case .milligrams:
                    let nf = NumberFormatter()
                    nf.locale = Locale.current
                    nf.minimumFractionDigits = 0
                    nf.maximumFractionDigits = 3
                    nf.minimumIntegerDigits = 1
                    target = nf.string(from: NSNumber(value: mg)) ?? mg.cleanString
                case .micrograms:
                    target = String(max(0, Int((mg * 1000.0).rounded())))
                }
                flag = false
                if target != before { filled.append(name) }
            }
            setVitaminUI(&vitaminA, parsed.vitaminA, &vitaminAIsGuess, name: "vitaminA")
            setVitaminUI(&vitaminB, parsed.vitaminB, &vitaminBIsGuess, name: "vitaminB")
            setVitaminUI(&vitaminC, parsed.vitaminC, &vitaminCIsGuess, name: "vitaminC")
            setVitaminUI(&vitaminD, parsed.vitaminD, &vitaminDIsGuess, name: "vitaminD")
            setVitaminUI(&vitaminE, parsed.vitaminE, &vitaminEIsGuess, name: "vitaminE")
            setVitaminUI(&vitaminK, parsed.vitaminK, &vitaminKIsGuess, name: "vitaminK")

            func setMineralUIInt(_ target: inout String, _ valueMg: Int?, _ flag: inout Bool, name: String) {
                let before = target
                guard target.isEmpty, let mg = valueMg else { return }
                switch vitaminsUnit {
                case .milligrams:
                    target = String(max(0, mg))
                case .micrograms:
                    target = String(max(0, mg * 1000))
                }
                flag = false
                if target != before { filled.append(name) }
            }
            func setMineralUIDouble(_ target: inout String, _ valueMg: Double?, _ flag: inout Bool, name: String) {
                let before = target
                guard target.isEmpty, let mg = valueMg else { return }
                switch vitaminsUnit {
                case .milligrams:
                    let nf = NumberFormatter()
                    nf.locale = Locale.current
                    nf.minimumFractionDigits = 0
                    nf.maximumFractionDigits = 3
                    nf.minimumIntegerDigits = 1
                    target = nf.string(from: NSNumber(value: mg)) ?? mg.cleanString
                case .micrograms:
                    target = String(max(0, Int((mg * 1000.0).rounded())))
                }
                flag = false
                if target != before { filled.append(name) }
            }

            setMineralUIInt(&calcium, parsed.calcium, &calciumIsGuess, name: "calcium")
            setMineralUIInt(&iron, parsed.iron, &ironIsGuess, name: "iron")
            setMineralUIDouble(&potassium, parsed.potassium, &potassiumIsGuess, name: "potassium")
            setMineralUIInt(&zinc, parsed.zinc, &zincIsGuess, name: "zinc")
            setMineralUIInt(&magnesium, parsed.magnesium, &magnesiumIsGuess, name: "magnesium")
            // New: Iodine (mg Double)
            setMineralUIDouble(&iodine, parsed.iodine, &iodineIsGuess, name: "iodine")
            // New: Phosphorus (mg Double)
            setMineralUIDouble(&phosphorus, parsed.phosphorus, &phosphorusIsGuess, name: "phosphorus")

            recomputeConsistency(resetPrevMismatch: false)

            // After successful apply: enable undo and save
            wizardCanUndo = true
            forceEnableSave = true
            analyzeError = nil
            wizardProgress = nil
            isAnalyzing = false

            #if DEBUG
            Task { await LabelDiagnosticsStore.shared.appendEvent(.init(stage: .applyToForm, fieldsFilled: filled)) }
            #endif
        }
    }

    // MARK: - Undo wizard changes

    func undoWizard() {
        guard let snap = wizardUndoSnapshot else { return }
        // Restore UI text fields
        calories = snap.calories
        carbohydrates = snap.carbohydrates
        protein = snap.protein
        sodium = snap.sodium
        fat = snap.fat

        alcohol = snap.alcohol
        nicotine = snap.nicotine
        theobromine = snap.theobromine
        caffeine = snap.caffeine
        taurine = snap.taurine

        starch = snap.starch
        sugars = snap.sugars
        fibre = snap.fibre

        monounsaturatedFat = snap.monounsaturatedFat
        polyunsaturatedFat = snap.polyunsaturatedFat
        saturatedFat = snap.saturatedFat
        transFat = snap.transFat
        omega3 = snap.omega3
        omega6 = snap.omega6

        animalProtein = snap.animalProtein
        plantProtein = snap.plantProtein
        proteinSupplements = snap.proteinSupplements
        a2BetaCasein = snap.a2BetaCasein
        a1BetaCasein = snap.a1BetaCasein

        vitaminA = snap.vitaminA
        vitaminB = snap.vitaminB
        vitaminC = snap.vitaminC
        vitaminD = snap.vitaminD
        vitaminE = snap.vitaminE
        vitaminK = snap.vitaminK

        calcium = snap.calcium
        iron = snap.iron
        potassium = snap.potassium
        zinc = snap.zinc
        magnesium = snap.magnesium
        iodine = snap.iodine
        phosphorus = snap.phosphorus

        // Restore flags
        caloriesIsGuess = snap.caloriesIsGuess
        carbohydratesIsGuess = snap.carbohydratesIsGuess
        proteinIsGuess = snap.proteinIsGuess
        sodiumIsGuess = snap.sodiumIsGuess
        fatIsGuess = snap.fatIsGuess

        alcoholIsGuess = snap.alcoholIsGuess
        nicotineIsGuess = snap.nicotineIsGuess
        theobromineIsGuess = snap.theobromineIsGuess
        caffeineIsGuess = snap.caffeineIsGuess
        taurineIsGuess = snap.taurineIsGuess

        starchIsGuess = snap.starchIsGuess
        sugarsIsGuess = snap.sugarsIsGuess
        fibreIsGuess = snap.fibreIsGuess

        monounsaturatedFatIsGuess = snap.monounsaturatedFatIsGuess
        polyunsaturatedFatIsGuess = snap.polyunsaturatedFatIsGuess
        saturatedFatIsGuess = snap.saturatedFatIsGuess
        transFatIsGuess = snap.transFatIsGuess
        omega3IsGuess = snap.omega3IsGuess
        omega6IsGuess = snap.omega6IsGuess

        animalProteinIsGuess = snap.animalProteinIsGuess
        plantProteinIsGuess = snap.plantProteinIsGuess
        proteinSupplementsIsGuess = snap.proteinSupplementsIsGuess
        a2BetaCaseinIsGuess = snap.a2BetaCaseinIsGuess
        a1BetaCaseinIsGuess = snap.a1BetaCaseinIsGuess

        vitaminAIsGuess = snap.vitaminAIsGuess
        vitaminBIsGuess = snap.vitaminBIsGuess
        vitaminCIsGuess = snap.vitaminCIsGuess
        vitaminDIsGuess = snap.vitaminDIsGuess
        vitaminEIsGuess = snap.vitaminEIsGuess
        vitaminKIsGuess = snap.vitaminKIsGuess

        calciumIsGuess = snap.calciumIsGuess
        ironIsGuess = snap.ironIsGuess
        potassiumIsGuess = snap.potassiumIsGuess
        zincIsGuess = snap.zincIsGuess
        magnesiumIsGuess = snap.magnesiumIsGuess
        iodineIsGuess = snap.iodineIsGuess
        phosphorusIsGuess = snap.phosphorusIsGuess

        // Clear undo state and UI status
        wizardCanUndo = false
        wizardUndoSnapshot = nil
        analyzeError = nil
        wizardProgress = nil

        // Recompute helpers/mismatch indicators after restoration
        recomputeConsistency(resetPrevMismatch: true)
    }

    // ... rest unchanged ...
}

// MARK: - Consistency and helper text logic (added)

extension MealFormView {
    // Parse a Double from UI text (accepts dot/comma)
    private func parseDouble(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    // Epsilon for comparing sums
    private var sumEpsilon: Double { 0.01 }

    // Recompute mismatch flags and helper texts for carbs/protein/fat
    func recomputeConsistency(resetPrevMismatch: Bool) {
        // Carbs
        let totalCarbs = parseDouble(carbohydrates)
        let sugarsV = parseDouble(sugars)
        let starchV = parseDouble(starch)
        let fibreV = parseDouble(fibre)
        let carbsSum = sugarsV + starchV + fibreV

        carbsMismatch = (totalCarbs > 0 || carbsSum > 0) && abs(totalCarbs - carbsSum) > sumEpsilon
        carbsHelperText = carbsSum > 0 ? carbsSum.cleanString : ""
        carbsHelperVisible = !carbohydrates.isEmpty || carbsSum > 0

        // Protein
        let totalProtein = parseDouble(protein)
        let animalV = parseDouble(animalProtein)
        let plantV = parseDouble(plantProtein)
        let suppV = parseDouble(proteinSupplements)
        let a2V = parseDouble(a2BetaCasein)
        let a1V = parseDouble(a1BetaCasein)
        let proteinSum = animalV + plantV + suppV + a2V + a1V

        proteinMismatch = (totalProtein > 0 || proteinSum > 0) && abs(totalProtein - proteinSum) > sumEpsilon
        proteinHelperText = proteinSum > 0 ? proteinSum.cleanString : ""
        proteinHelperVisible = !protein.isEmpty || proteinSum > 0

        // Fat
        let totalFat = parseDouble(fat)
        let monoV = parseDouble(monounsaturatedFat)
        let polyV = parseDouble(polyunsaturatedFat)
        let satV = parseDouble(saturatedFat)
        let transV = parseDouble(transFat)
        let fatSum = monoV + polyV + satV + transV

        fatMismatch = (totalFat > 0 || fatSum > 0) && abs(totalFat - fatSum) > sumEpsilon
        fatHelperText = fatSum > 0 ? fatSum.cleanString : ""
        fatHelperVisible = !fat.isEmpty || fatSum > 0

        if resetPrevMismatch {
            prevCarbsMismatch = carbsMismatch
            prevProteinMismatch = proteinMismatch
            prevFatMismatch = fatMismatch
        }
    }

    // Call after edits to trigger a quick green blink when a mismatch gets fixed
    func recomputeConsistencyAndBlinkIfFixed() {
        let wasCarbs = carbsMismatch
        let wasProtein = proteinMismatch
        let wasFat = fatMismatch

        recomputeConsistency(resetPrevMismatch: false)

        // Blink if transitioning from mismatch to matched
        if wasCarbs && !carbsMismatch {
            carbsBlink = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { carbsBlink = false }
        }
        if wasProtein && !proteinMismatch {
            proteinBlink = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { proteinBlink = false }
        }
        if wasFat && !fatMismatch {
            fatBlink = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { fatBlink = false }
        }

        // Update previous mismatch trackers
        prevCarbsMismatch = carbsMismatch
        prevProteinMismatch = proteinMismatch
        prevFatMismatch = fatMismatch
    }
}

