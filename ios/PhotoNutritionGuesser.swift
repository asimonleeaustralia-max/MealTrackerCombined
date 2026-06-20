//
//  PhotoNutritionGuesser.swift
//  MealTracker
//
//  iOS 13+ on-device pipeline: detect barcodes with Vision, look up in LocalBarcodeDB,
//  OCR nutrition labels, then FeaturePrint (no-training) fallback, and as a last resort,
//  a visual heuristic guess from the photo.
//

import Foundation
import Vision
import UIKit
import CoreImage

struct PhotoNutritionGuesser {

    struct GuessResult {
        // Units: kcal (Int), grams (Double), mg (Int for sodium; Double for vitamins and potassium)
        var calories: Int?
        var carbohydrates: Double?
        var protein: Double?
        var fat: Double?
        var sodiumMg: Int?

        var sugars: Double?
        var starch: Double?
        var fibre: Double?

        var monounsaturatedFat: Double?
        var polyunsaturatedFat: Double?
        var saturatedFat: Double?
        var transFat: Double?

        var animalProtein: Double?
        var plantProtein: Double?
        var proteinSupplements: Double?
        // New: A2 beta-casein (grams)
        var a2BetaCasein: Double?
        // New: A1 beta-casein (grams)
        var a1BetaCasein: Double?

        // Vitamins now Double? mg
        var vitaminA: Double?
        var vitaminB: Double?
        var vitaminC: Double?
        var vitaminD: Double?
        var vitaminE: Double?
        var vitaminK: Double?

        // Minerals: potassium Double? mg; others stay Int? for now
        var calcium: Int?
        var iron: Int?
        var potassium: Double?
        var zinc: Int?
        var magnesium: Int?
        // New: Iodine (Double? mg)
        var iodine: Double?
        // New: Phosphorus (Double? mg)
        var phosphorus: Double?

        // Stimulants/supplements
        // Alcohol in grams
        var alcohol: Double?
        // mg-based stimulants/supplements (integers)
        var nicotineMg: Int?
        var theobromineMg: Int?
        var caffeineMg: Int?
        var taurineMg: Int?
        var creatineMg: Int?
    }

    enum GuessError: Error {
        case invalidImage
        case processingFailed
    }

    // Debug flag to print OCR text
    private static let debugOCR = false

    // Public API: try barcode first; if no hit, OCR; heuristics disabled (no FeaturePrint/visual fallback)
    static func guess(from imageData: Data, languageCode: String? = nil) async throws -> GuessResult? {
        guard let image = UIImage(data: imageData) else {
            throw GuessError.invalidImage
        }
        // 1) Try barcode detection on full‑resolution image rotations (0°, 90°, 180°, 270°)
        let barcodeVariants = rotationVariants(of: image)
        for img in barcodeVariants {
            if let code = await detectFirstBarcode(in: img) {
                // 1a) Try local stores first (DuckDB, then bundled JSON)
                if let entry = await BarcodeRepository.shared.lookup(code: code) ?? LocalBarcodeDB.lookup(code: code) {
                    return map(entry: entry)
                }
                // 1b) If local miss, fetch from Open Food Facts and map
                do {
                    let product = try await OpenFoodFactsClient.fetchProduct(by: code)
                    if let offEntry = OpenFoodFactsClient.mapToEntry(from: product) {
                        // Best‑effort: upsert to local DB for next time (ignore errors)
                        try? await BarcodeRepository.shared.upsert(entry: offEntry)
                        return map(entry: offEntry)
                    }
                } catch {
                    // OFF fetch failed; continue to OCR path
                }
            }
        }

        // 2) OCR nutrition parsing (dual-pass) on each rotation, pick the best parse
        // Use a higher-res, preprocessed image for OCR only.
        var bestParsed: GuessResult?
        var bestParsedScore = -1
        for img in rotationVariants(of: image) {
            let ocrImg = ocrReadyImage(from: img, maxLongEdge: 2048)
            if let text = await recognizeTextDualPass(in: ocrImg, languageCode: languageCode) {
                if debugOCR {
                    print("OCR text (rotation variant):\n\(text)\n--- end OCR ---")
                }
                #if DEBUG
                var parseDiag: [String]? = []
                let result = parseNutrition(from: text, collecting: &parseDiag)
                #else
                let result = parseNutrition(from: text)
                #endif
                let score = result.parsedFieldCount
                if score > bestParsedScore {
                    bestParsedScore = score
                    bestParsed = result.hasAnyValue ? result : bestParsed
                    if score >= 10 { break }
                }
            }
        }
        if let parsed = bestParsed, parsed.hasAnyValue {
            return parsed
        }

        // 3) Heuristics disabled: do not attempt FeaturePrint or visual fallbacks.
        return nil
    }

    private static func downscaleIfNeeded(_ image: UIImage, maxLongEdge: CGFloat) -> UIImage {
        let size = image.size
        let longEdge = max(size.width, size.height)
        guard longEdge > maxLongEdge else { return image }
        let scale = maxLongEdge / longEdge
        let target = CGSize(width: floor(size.width * scale), height: floor(size.height * scale))
        let renderer = UIGraphicsImageRenderer(size: target)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    // Create a higher-res, preprocessed image tailored for OCR
    private static func ocrReadyImage(from source: UIImage, maxLongEdge: CGFloat) -> UIImage {
        let hiRes = downscaleIfNeeded(source, maxLongEdge: maxLongEdge)
        return ocrPreprocess(hiRes) ?? hiRes
    }

    // Simple OCR preprocessing: grayscale + contrast boost + mild unsharp mask
    private static func ocrPreprocess(_ image: UIImage) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let ci = CIImage(cgImage: cg)

        // 1) Desaturate and increase contrast slightly
        let contrasted = ci
            .applyingFilter("CIColorControls", parameters: [
                kCIInputSaturationKey: 0.0,     // grayscale
                kCIInputContrastKey: 1.25,      // mild boost
                kCIInputBrightnessKey: 0.0
            ])

        // 2) Mild unsharp mask to crispen soft glyphs
        let sharpened = contrasted
            .applyingFilter("CIUnsharpMask", parameters: [
                kCIInputRadiusKey: 1.2,
                kCIInputIntensityKey: 0.6
            ])

        let context = CIContext(options: nil)
        guard let outCG = context.createCGImage(sharpened, from: sharpened.extent) else { return nil }
        return UIImage(cgImage: outCG, scale: image.scale, orientation: image.imageOrientation)
    }

    // Create 0°, 90°, 180°, 270° rotation variants
    static func rotationVariants(of image: UIImage) -> [UIImage] {
        var list: [UIImage] = [image]
        if let r90 = rotate90(image, times: 1) { list.append(r90) }
        if let r180 = rotate90(image, times: 2) { list.append(r180) }
        if let r270 = rotate90(image, times: 3) { list.append(r270) }
        return list
    }

    // Rotate by 90° increments efficiently
    private static func rotate90(_ image: UIImage, times: Int) -> UIImage? {
        let t = ((times % 4) + 4) % 4
        guard t != 0 else { return image }
        var transform = CGAffineTransform.identity
        var newSize = image.size

        switch t {
        case 1: // 90°
            transform = CGAffineTransform(rotationAngle: .pi / 2).translatedBy(x: 0, y: -image.size.height)
            newSize = CGSize(width: image.size.height, height: image.size.width)
        case 2: // 180°
            transform = CGAffineTransform(rotationAngle: .pi).translatedBy(x: -image.size.width, y: -image.size.height)
        case 3: // 270°
            transform = CGAffineTransform(rotationAngle: 3 * .pi / 2).translatedBy(x: -image.size.width, y: 0)
            newSize = CGSize(width: image.size.height, height: image.size.width)
        default:
            break
        }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { ctx in
            ctx.cgContext.translateBy(x: 0, y: newSize.height)
            ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
            ctx.cgContext.concatenate(transform)
            if let cg = image.cgImage {
                ctx.cgContext.draw(cg, in: CGRect(origin: .zero, size: image.size))
            } else {
                image.draw(in: CGRect(origin: .zero, size: image.size))
            }
        }
    }

    private static func map(entry: LocalBarcodeDB.Entry) -> GuessResult {
        GuessResult(
            calories: entry.calories,
            carbohydrates: entry.carbohydrates,
            protein: entry.protein,
            fat: entry.fat,
            sodiumMg: entry.sodiumMg,
            sugars: entry.sugars,
            starch: entry.starch,
            fibre: entry.fibre,
            monounsaturatedFat: entry.monounsaturatedFat,
            polyunsaturatedFat: entry.polyunsaturatedFat,
            saturatedFat: entry.saturatedFat,
            transFat: entry.transFat,
            animalProtein: entry.animalProtein,
            plantProtein: entry.plantProtein,
            proteinSupplements: entry.proteinSupplements,
            // New: map a2BetaCasein if present in DB entry
            a2BetaCasein: entry.a2BetaCasein,
            // a1BetaCasein not in LocalBarcodeDB.Entry currently
            a1BetaCasein: nil,
            vitaminA: entry.vitaminA,
            vitaminB: entry.vitaminB,
            vitaminC: entry.vitaminC,
            vitaminD: entry.vitaminD,
            vitaminE: entry.vitaminE,
            vitaminK: entry.vitaminK,
            calcium: entry.calcium,
            iron: entry.iron,
            potassium: entry.potassium,
            zinc: entry.zinc,
            magnesium: entry.magnesium,
            // New minerals not present in LocalBarcodeDB.Entry currently
            iodine: nil,
            phosphorus: nil,
            // Stimulants/supplements are not present in LocalBarcodeDB.Entry; leave nil
            alcohol: nil,
            nicotineMg: nil,
            theobromineMg: nil,
            caffeineMg: nil,
            taurineMg: nil,
            creatineMg: nil
        )
    }

    // Fixed: ensure the continuation is resumed exactly once.
    static func detectFirstBarcode(in image: UIImage) async -> String? {
        // Try Vision first (with correct orientation)
        if let code = await detectBarcodeVision(in: image) { return code }
        #if targetEnvironment(simulator)
        // Simulator fallback: OCR numeric decoding (EAN/UPC)
        if let code = await fallbackBarcodeByOCR(in: image) { return code }
        #endif
        return nil
    }

    private static func detectBarcodeVision(in image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        let orientation = cgImagePropertyOrientation(from: image.imageOrientation)

        return await withCheckedContinuation { continuation in
            var didResume = false
            func resumeOnce(_ value: String?) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: value)
            }

            let request = VNDetectBarcodesRequest { request, error in
                if let _ = error {
                    resumeOnce(nil)
                    return
                }
                let payloads = (request.results as? [VNBarcodeObservation])?
                    .compactMap { $0.payloadStringValue }
                resumeOnce(payloads?.first)
            }

            if #available(iOS 15.0, *) {
                request.symbologies = [.UPCE, .EAN13, .EAN8, .Code128, .Code39, .Code93, .ITF14]
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    resumeOnce(nil)
                }
            }
        }
    }

    #if targetEnvironment(simulator)
    private static func fallbackBarcodeByOCR(in image: UIImage) async -> String? {
        guard let cgImage = image.cgImage else { return nil }
        let orientation = cgImagePropertyOrientation(from: image.imageOrientation)

        func recognize(level: VNRequestTextRecognitionLevel) async -> String? {
            await withCheckedContinuation { continuation in
                let request = VNRecognizeTextRequest { req, err in
                    guard err == nil, let obs = req.results as? [VNRecognizedTextObservation], !obs.isEmpty else {
                        continuation.resume(returning: nil)
                        return
                    }
                    let lines = obs.compactMap { $0.topCandidates(1).first?.string }
                    continuation.resume(returning: lines.joined(separator: "\n"))
                }
                request.recognitionLevel = level
                request.usesLanguageCorrection = false
                request.recognitionLanguages = ["en"]
                let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
                DispatchQueue.global(qos: .userInitiated).async {
                    do { try handler.perform([request]) } catch { continuation.resume(returning: nil) }
                }
            }
        }

        // Try fast first, then accurate
        let textFast = await recognize(level: .fast)
        let fullText: String?
        if let t = textFast {
            fullText = t
        } else {
            fullText = await recognize(level: .accurate)
        }
        guard let text = fullText, !text.isEmpty else { return nil }

        // Extract digit runs allowing optional spaces/hyphens between digits (8–14 digits total)
        let pattern = "(?<!\\d)(?:\\d[\\s-]?){8,14}(?!\\d)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(location: 0, length: (text as NSString).length)
        let matches = regex.matches(in: text, options: [], range: range)

        // Bucket by cleaned code to count occurrences and keep raw samples
        var buckets: [String: (count: Int, raws: [String])] = [:]
        for m in matches {
            let r = m.range
            guard r.location != NSNotFound, let swiftRange = Range(r, in: text) else { continue }
            let raw = String(text[swiftRange])
            let cleaned = raw.replacingOccurrences(of: "[^\\d]", with: "", options: .regularExpression)
            guard cleaned.count >= 8 && cleaned.count <= 14 else { continue }
            var entry = buckets[cleaned] ?? (0, [])
            entry.count += 1
            entry.raws.append(raw)
            buckets[cleaned] = entry
        }
        guard !buckets.isEmpty else { return nil }

        struct CandidateScore { let code: String; let score: Int; let len: Int; let valid: Bool }

        func scoreCandidate(code: String, info: (count: Int, raws: [String])) -> CandidateScore {
            let len = code.count
            let validEAN13 = (len == 13 && validateEAN13(code))
            let validUPCA = (len == 12 && validateUPCA(code))
            let validEAN8 = (len == 8 && validateEAN8(code))
            let validEAN14 = (len == 14 && validateEAN14(code))
            let isValid = validEAN13 || validUPCA || validEAN8 || validEAN14

            var s = 0
            // Symbology preference (typical retail priority)
            switch len {
            case 13: s += 50
            case 12: s += 40
            case 8:  s += 30
            case 14: s += 10
            default: s -= 100
            }
            // Check digit validation bonuses
            if validEAN13 { s += 50 }
            if validUPCA  { s += 45 }
            if validEAN8  { s += 35 }
            if validEAN14 { s += 20 }
            // Frequency bonus (duplicate mentions)
            s += min(10, max(0, info.count - 1) * 2)
            // Grouping hints in raw samples (common human-readable formats)
            let hasEAN13Grouping = info.raws.contains { $0.range(of: #"^\s*\d[\s-]\d{5,6}[\s-]\d{5,6}\s*$"#, options: .regularExpression) != nil }
            let hasUPCAGrouping  = info.raws.contains { $0.range(of: #"^\s*\d[\s-]\d{5}[\s-]\d{5}[\s-]\d\s*$"#, options: .regularExpression) != nil }
            if len == 13 && hasEAN13Grouping { s += 6 }
            if len == 12 && hasUPCAGrouping  { s += 6 }

            return CandidateScore(code: code, score: s, len: len, valid: isValid)
        }

        var scored: [CandidateScore] = []
        for (code, info) in buckets {
            scored.append(scoreCandidate(code: code, info: info))
        }

        // Pick best by score, then validity, then longer length, then lexicographically for determinism
        guard let best = scored.max(by: { a, b in
            if a.score != b.score { return a.score < b.score }
            if a.valid != b.valid { return !a.valid && b.valid }
            if a.len != b.len { return a.len < b.len }
            return a.code < b.code
        }) else { return nil }

        return best.code
    }
    #endif

    private static func cgImagePropertyOrientation(from orientation: UIImage.Orientation) -> CGImagePropertyOrientation {
        switch orientation {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }

    // MARK: - Check digit validators
    private static func validateEAN13(_ code: String) -> Bool {
        guard code.count == 13, code.allSatisfy({ $0.isNumber }) else { return false }
        let digits = code.compactMap { Int(String($0)) }
        guard digits.count == 13 else { return false }
        let sum = (0..<12).reduce(0) { acc, idx in
            let weight = (idx % 2 == 0) ? 1 : 3
            return acc + digits[idx] * weight
        }
        let check = (10 - (sum % 10)) % 10
        return check == digits[12]
    }

    private static func validateUPCA(_ code: String) -> Bool {
        // UPC-A is 12 digits with EAN-13 equivalence by prefixing 0
        guard code.count == 12, code.allSatisfy({ $0.isNumber }) else { return false }
        let ean = "0" + code
        return validateEAN13(ean)
    }

    private static func validateEAN8(_ code: String) -> Bool {
        guard code.count == 8, code.allSatisfy({ $0.isNumber }) else { return false }
        let digits = code.compactMap { Int(String($0)) }
        guard digits.count == 8 else { return false }
        let sum = (0..<7).reduce(0) { acc, idx in
            let weight = (idx % 2 == 0) ? 3 : 1
            return acc + digits[idx] * weight
        }
        let check = (10 - (sum % 10)) % 10
        return check == digits[7]
    }

    private static func validateEAN14(_ code: String) -> Bool {
        // EAN-14 uses Mod 10 with weights 3/1 alternating from the right
        guard code.count == 14, code.allSatisfy({ $0.isNumber }) else { return false }
        let digits = code.compactMap { Int(String($0)) }
        guard digits.count == 14 else { return false }
        // compute check over first 13 digits
        var sum = 0
        for (i, d) in digits[..<13].enumerated() {
            // position from right (excluding check): i from left => idxFromRight = 12 - i
            let idxFromRight = 12 - i
            let weight = (idxFromRight % 2 == 0) ? 3 : 1
            sum += d * weight
        }
        let check = (10 - (sum % 10)) % 10
        return check == digits[13]
    }

    // New: richer barcode presence probe to distinguish unreadable vs none
    enum BarcodePresence {
        case decoded(String)
        case presentButUnreadable
        case none
    }

    static func probeBarcodePresence(in image: UIImage) async -> BarcodePresence {
        guard let cgImage = image.cgImage else { return .none }

        return await withCheckedContinuation { continuation in
            var didResume = false
            func resumeOnce(_ value: BarcodePresence) {
                guard !didResume else { return }
                didResume = true
                continuation.resume(returning: value)
            }

            let request = VNDetectBarcodesRequest { request, error in
                if let _ = error {
                    resumeOnce(.none)
                    return
                }
                guard let obs = request.results as? [VNBarcodeObservation], !obs.isEmpty else {
                    resumeOnce(.none)
                    return
                }

                // If any payload decodes, report decoded
                if let code = obs.compactMap({ $0.payloadStringValue }).first, !code.isEmpty {
                    resumeOnce(.decoded(code))
                    return
                }

                // Otherwise, heuristically decide if something barcode-like is present but unreadable:
                // - at least one observation
                // - confidence reasonable OR bounding box size suggests a visible region
                let unreadableLikely = obs.contains { o in
                    let area = o.boundingBox.width * o.boundingBox.height
                    let conf = o.confidence
                    // area is in normalized 0..1; threshold ~1.5% of frame, or moderate confidence
                    return area > 0.015 || conf > 0.4
                }
                resumeOnce(unreadableLikely ? .presentButUnreadable : .none)
            }

            if #available(iOS 15.0, *) {
                request.symbologies = [.UPCE, .EAN13, .EAN8, .Code128, .Code39, .Code93, .ITF14]
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    resumeOnce(.none)
                }
            }
        }
    }

    // Single-dish confidence: based on largest salient object only
    private static func visualConfidenceSingleDish(in image: UIImage, guess: GuessResult) -> Double {
        guard let cg = image.cgImage else { return -Double.infinity }
        let area = largestSalientObjectAreaRatio(cgImage: cg)
        let macroPresence = (guess.carbohydrates ?? 0) + (guess.protein ?? 0) + (guess.fat ?? 0)
        return area * 1.0 + (macroPresence > 0 ? 0.1 : 0.0)
    }

    // MARK: - Visual fallback guess (heuristic) with single-dish constraint
    // Produces conservative estimates for calories/carbs/protein/fat only.
    // Enhanced for fried, beige, large-plate scenes (e.g., fish & chips).
    private static func visualGuessSingleDish(in image: UIImage) -> GuessResult? {
        guard let cgImage = image.cgImage else { return nil }

        // 1) Estimate area of the LARGEST salient object (single-dish proxy)
        let rawAreaRatio = largestSalientObjectAreaRatio(cgImage: cgImage) // 0.0 ... 1.0

        // 2) Color features for category and “hearty fried plate” detection
        let stats = colorFeatures(from: image)
        let category = dominantFoodCategory(fromStats: stats)

        // Hearty fried plate signal: warm + neutral dominate, very little green
        let heartyPlate = (stats.warm + stats.neutral) > 0.70 && stats.green < 0.10
        let isDessert = (category == .dessertOrCake)

        // 3) Portion proxy with override: for hearty plates, raise the area floor
        let clampedAreaBase = max(0.12, min(0.85, rawAreaRatio))
        let clampedArea = heartyPlate ? max(0.55, clampedAreaBase) : clampedAreaBase

        // Slightly stronger scaling, benefits large single-dish scenes
        let scale = 0.70 + 1.00 * (clampedArea - 0.30) // area 0.30 -> 0.70x, 0.85 -> ~1.25x

        // Base kcal per serving (raised where appropriate)
        let baseKcal: Double
        let macroSplit: (carb: Double, protein: Double, fat: Double)
        switch category {
        case .dessertOrCake:
            baseKcal = 420
            macroSplit = (carb: 0.55, protein: 0.07, fat: 0.38)
        case .carbHeavy:
            baseKcal = 540
            macroSplit = (carb: 0.64, protein: 0.12, fat: 0.24)
        case .proteinHeavy:
            baseKcal = 460
            macroSplit = (carb: 0.12, protein: 0.48, fat: 0.40)
        case .vegOrSalad:
            baseKcal = 180
            macroSplit = (carb: 0.45, protein: 0.15, fat: 0.40)
        }

        // Fried bonus scaled by warm+neutral dominance
        let friedSignal = stats.warm + stats.neutral
        let friedBonus: Double = {
            guard clampedArea > 0.35 else { return 0 }
            if friedSignal > 0.78 { return 320 }
            if friedSignal > 0.65 { return 220 }
            if friedSignal > 0.52 { return 140 }
            return 0
        }()

        // Compute kcal
        var kcal = Int((baseKcal * scale + friedBonus).rounded())

        // Apply “hearty floor” ONLY for non-dessert categories to avoid cupcakes hitting 700 kcal.
        if heartyPlate && !isDessert {
            kcal = max(kcal, 680)
        }
        let kcalClamped = max(180, min(1400, kcal))

        // Convert macro proportions to grams using kcal factors (4/4/9)
        let carbKcal = Double(kcalClamped) * macroSplit.carb
        let proteinKcal = Double(kcalClamped) * macroSplit.protein
        let fatKcal = Double(kcalClamped) * macroSplit.fat

        let carbG = (carbKcal / 4.0)
        let proteinG = (proteinKcal / 4.0)
        let fatG = (fatKcal / 9.0)

        var guess = GuessResult()
        guess.calories = max(50, kcalClamped)
        guess.carbohydrates = max(0, carbG)
        guess.protein = max(0, proteinG)
        guess.fat = max(0, fatG)

        // Minimal vitamin/mineral fallback (mg), category-based conservative values
        switch category {
        case .dessertOrCake:
            guess.vitaminA = 0; guess.vitaminB = 0; guess.vitaminC = 0; guess.vitaminD = 0; guess.vitaminE = 0; guess.vitaminK = 0
            guess.calcium = 20; guess.iron = 0; guess.potassium = 40; guess.zinc = 0; guess.magnesium = 5
        case .carbHeavy:
            guess.vitaminA = 0; guess.vitaminB = 0; guess.vitaminC = 0; guess.vitaminD = 0; guess.vitaminE = 0; guess.vitaminK = 0
            guess.calcium = 10; guess.iron = 0; guess.potassium = 50; guess.zinc = 0; guess.magnesium = 10
        case .proteinHeavy:
            guess.vitaminA = 0; guess.vitaminB = 0; guess.vitaminC = 0; guess.vitaminD = 0; guess.vitaminE = 0; guess.vitaminK = 0
            guess.calcium = 15; guess.iron = 1; guess.potassium = 80; guess.zinc = 1; guess.magnesium = 12
        case .vegOrSalad:
            guess.vitaminA = 0; guess.vitaminB = 0; guess.vitaminC = 12; guess.vitaminD = 0; guess.vitaminE = 0; guess.vitaminK = 0
            guess.calcium = 40; guess.iron = 1; guess.potassium = 200; guess.zinc = 0; guess.magnesium = 20
        }

        return guess
    }

    // Food category buckets for heuristic
    private enum FoodCategory {
        case dessertOrCake
        case carbHeavy
        case proteinHeavy
        case vegOrSalad
    }

    // Largest salient object ratio (single-dish proxy)
    private static func largestSalientObjectAreaRatio(cgImage: CGImage) -> Double {
        if #available(iOS 13.0, *) {
            let request = VNGenerateAttentionBasedSaliencyImageRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
                if let result = request.results?.first as? VNSaliencyImageObservation,
                   let salient = result.salientObjects, !salient.isEmpty {
                    // Take the largest salient object's area (normalized)
                    let largest = salient.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height })!
                    let area = Double(largest.boundingBox.width * largest.boundingBox.height)
                    return max(0.0, min(1.0, area))
                }
            } catch {
                // fall through to simple fallback
            }
        }
        // Fallback: modest single-dish assumption if saliency unavailable
        return 0.35
    }

    // Extract coarse color features used by category/bias rules
    private static func colorFeatures(from image: UIImage) -> (warm: Double, green: Double, neutral: Double, dark: Double, bright: Double) {
        // Downscale and compute average + histogram-ish buckets
        let size = CGSize(width: 64, height: 64)
        UIGraphicsBeginImageContextWithOptions(size, true, 1.0)
        image.draw(in: CGRect(origin: .zero, size: size))
        let small = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let img = small, let cg = img.cgImage else { return (0,0,0,0,0) }
        let width = cg.width
        let height = cg.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        let bitsPerComponent = 8
        var data = [UInt8](repeating: 0, count: Int(bytesPerRow * height))
        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return (0,0,0,0,0) }
        guard let ctx = CGContext(data: &data,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: bitsPerComponent,
                                  bytesPerRow: bytesPerRow,
                                  space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return (0,0,0,0,0) }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))

        var warmCount = 0, greenCount = 0, neutralCount = 0, darkCount = 0, brightCount = 0

        for y in 0..<height {
            for x in 0..<width {
                let idx = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = Double(data[idx + 0])
                let g = Double(data[idx + 1])
                let b = Double(data[idx + 2])
                let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b

                if r > g && r > b { warmCount += 1 } // browns/reds -> baked/fried/dessert
                if g > r && g > b { greenCount += 1 } // greens -> veg/salad
                if abs(r - g) < 20 && abs(g - b) < 20 { neutralCount += 1 } // beige/neutral -> carbs/grains
                if luma < 60 { darkCount += 1 }
                if luma > 200 { brightCount += 1 }
            }
        }

        let total = max(1, width * height)
        return (warm: Double(warmCount)/Double(total),
                green: Double(greenCount)/Double(total),
                neutral: Double(neutralCount)/Double(total),
                dark: Double(darkCount)/Double(total),
                bright: Double(brightCount)/Double(total))
    }

    // Category using precomputed stats (so we don't recompute twice)
    private static func dominantFoodCategory(fromStats stats: (warm: Double, green: Double, neutral: Double, dark: Double, bright: Double)) -> FoodCategory {
        let warmRatio = stats.warm
        let greenRatio = stats.green
        let neutralRatio = stats.neutral
        let darkRatio = stats.dark
        let brightRatio = stats.bright

        // Dessert/cake: warm colors + either bright highlights (frosting) or dark (chocolate)
        if warmRatio > 0.35 && (brightRatio > 0.08 || darkRatio > 0.10) {
            return .dessertOrCake
        }
        // Veg/salad: a lot of green
        if greenRatio > 0.28 {
            return .vegOrSalad
        }
        // Carb-heavy: neutral/beige dominates (bread, pasta, rice, fried potatoes)
        if neutralRatio > 0.30 {
            return .carbHeavy
        }
        // Protein-heavy fallback (meats often warm but without extreme highlights)
        if warmRatio > 0.28 {
            return .proteinHeavy
        }
        // Default to carb-heavy if uncertain
        return .carbHeavy
    }
}
