//
//  MealFormView+Media.swift
//  MealTracker
//
//  Extracted camera/gallery/lifecycle/deletion logic from MealFormView+Logic.swift
//

import SwiftUI
import CoreData
import CoreLocation
import UIKit
import AVFoundation

extension MealFormView {

    // Shared formatter for vitamins/minerals shown in mg/µg (preserve decimals in mg mode)
    private func mgToUIText(_ mgValue: Double) -> String {
        switch vitaminsUnit {
        case .milligrams:
            // Up to 3 fractional digits, trim trailing zeros
            let nf = NumberFormatter()
            nf.locale = Locale.current
            nf.minimumFractionDigits = 0
            nf.maximumFractionDigits = 3
            nf.minimumIntegerDigits = 1
            return nf.string(from: NSNumber(value: mgValue)) ?? mgValue.cleanString
        case .micrograms:
            let micro = (mgValue * 1000.0).rounded()
            return String(Int(micro))
        }
    }

    // MARK: - Lifecycle wiring

    func onAppearSetup(l: LocalizationManager) {
        // Mark this home screen visible
        isHomeVisible = true

        // Build gallery items from Core Data or dev fallback
        reloadGalleryItems()

        if let meal = meal {
            // Initialize editable title from existing meal
            mealDescription = meal.title

            calories = Int(meal.calories).description
            // Use cleanString to preserve decimals for grams
            carbohydrates = meal.carbohydrates.cleanString
            protein = meal.protein.cleanString
            sodium = {
                if sodiumUnit == .milligrams {
                    return Int(meal.sodium).description
                } else {
                    return (meal.sodium / 1000.0).cleanString
                }
            }()
            fat = meal.fat.cleanString
            alcohol = meal.alcohol.cleanString
            nicotine = Int(meal.nicotine).description
            theobromine = Int(meal.theobromine).description
            caffeine = Int(meal.caffeine).description
            taurine = Int(meal.taurine).description
            // Creatine (mg, integer UI)
            creatine = Int(meal.creatine).description
            starch = meal.starch.cleanString
            sugars = meal.sugars.cleanString
            fibre = meal.fibre.cleanString
            monounsaturatedFat = meal.monounsaturatedFat.cleanString
            polyunsaturatedFat = meal.polyunsaturatedFat.cleanString
            saturatedFat = meal.saturatedFat.cleanString
            transFat = meal.transFat.cleanString
            omega3 = meal.omega3.cleanString
            omega6 = meal.omega6.cleanString
            animalProtein = meal.animalProtein.cleanString
            plantProtein = meal.plantProtein.cleanString
            proteinSupplements = meal.proteinSupplements.cleanString
            // A2/A1 beta-casein
            a2BetaCasein = meal.a2BetaCasein.cleanString
            a1BetaCasein = meal.a1BetaCasein.cleanString

            // Preserve decimals for vitamins (stored mg Double) and potassium
            vitaminA = mgToUIText(meal.vitaminA)
            vitaminB = mgToUIText(meal.vitaminB)
            vitaminC = mgToUIText(meal.vitaminC)
            vitaminD = mgToUIText(meal.vitaminD)
            vitaminE = mgToUIText(meal.vitaminE)
            vitaminK = mgToUIText(meal.vitaminK)

            // Minerals: calcium/iron/zinc/magnesium are Int mg; potassium is Double mg
            calcium = Int(vitaminsUnit.fromStorageMG(meal.calcium)).description
            iron = Int(vitaminsUnit.fromStorageMG(meal.iron)).description
            potassium = mgToUIText(meal.potassium)
            zinc = Int(vitaminsUnit.fromStorageMG(meal.zinc)).description
            magnesium = Int(vitaminsUnit.fromStorageMG(meal.magnesium)).description

            date = meal.date

            caloriesIsGuess = meal.caloriesIsGuess
            carbohydratesIsGuess = meal.carbohydratesIsGuess
            proteinIsGuess = meal.proteinIsGuess
            sodiumIsGuess = meal.sodiumIsGuess
            fatIsGuess = meal.fatIsGuess
            alcoholIsGuess = meal.alcoholIsGuess
            nicotineIsGuess = meal.nicotineIsGuess
            theobromineIsGuess = meal.theobromineIsGuess
            caffeineIsGuess = meal.caffeineIsGuess
            taurineIsGuess = meal.taurineIsGuess
            // Creatine accuracy flag
            creatineIsGuess = meal.creatineIsGuess
            starchIsGuess = meal.starchIsGuess
            sugarsIsGuess = meal.sugarsIsGuess
            fibreIsGuess = meal.fibreIsGuess
            monounsaturatedFatIsGuess = meal.monounsaturatedFatIsGuess
            polyunsaturatedFatIsGuess = meal.polyunsaturatedFatIsGuess
            saturatedFatIsGuess = meal.saturatedFatIsGuess
            transFatIsGuess = meal.transFatIsGuess
            omega3IsGuess = meal.omega3IsGuess
            omega6IsGuess = meal.omega6IsGuess

            animalProteinIsGuess = meal.animalProteinIsGuess
            plantProteinIsGuess = meal.plantProteinIsGuess
            proteinSupplementsIsGuess = meal.proteinSupplementsIsGuess
            a2BetaCaseinIsGuess = meal.a2BetaCaseinIsGuess
            a1BetaCaseinIsGuess = meal.a1BetaCaseinIsGuess

            vitaminAIsGuess = meal.vitaminAIsGuess
            vitaminBIsGuess = meal.vitaminBIsGuess
            vitaminCIsGuess = meal.vitaminCIsGuess
            vitaminDIsGuess = meal.vitaminDIsGuess
            vitaminEIsGuess = meal.vitaminEIsGuess
            vitaminKIsGuess = meal.vitaminKIsGuess

            calciumIsGuess = meal.calciumIsGuess
            ironIsGuess = meal.ironIsGuess
            potassiumIsGuess = meal.potassiumIsGuess
            zincIsGuess = meal.zincIsGuess
            magnesiumIsGuess = meal.magnesiumIsGuess

            sugarsTouched = !sugars.isEmpty
            starchTouched = !starch.isEmpty
            fibreTouched = !fibre.isEmpty
            monoTouched = !monounsaturatedFat.isEmpty
            polyTouched = !polyunsaturatedFat.isEmpty
            satTouched = !saturatedFat.isEmpty
            transTouched = !transFat.isEmpty
            omega3Touched = !omega3.isEmpty
            omega6Touched = !omega6.isEmpty
            animalTouched = !animalProtein.isEmpty
            plantTouched = !plantProtein.isEmpty
            supplementsTouched = !proteinSupplements.isEmpty

            func zeroToEmpty(_ s: String) -> String { s == "0" || s == "0.0" ? "" : s }

            carbohydrates = zeroToEmpty(carbohydrates)
            protein = zeroToEmpty(protein)
            sodium = zeroToEmpty(sodium)
            fat = zeroToEmpty(fat)
            alcohol = zeroToEmpty(alcohol)
            nicotine = zeroToEmpty(nicotine)
            theobromine = zeroToEmpty(theobromine)
            caffeine = zeroToEmpty(caffeine)
            taurine = zeroToEmpty(taurine)
            // Creatine normalization
            creatine = zeroToEmpty(creatine)

            starch = zeroToEmpty(starch)
            sugars = zeroToEmpty(sugars)
            fibre = zeroToEmpty(fibre)

            monounsaturatedFat = zeroToEmpty(monounsaturatedFat)
            polyunsaturatedFat = zeroToEmpty(polyunsaturatedFat)
            saturatedFat = zeroToEmpty(saturatedFat)
            transFat = zeroToEmpty(transFat)
            omega3 = zeroToEmpty(omega3)
            omega6 = zeroToEmpty(omega6)

            animalProtein = zeroToEmpty(animalProtein)
            plantProtein = zeroToEmpty(plantProtein)
            proteinSupplements = zeroToEmpty(proteinSupplements)
            a2BetaCasein = zeroToEmpty(a2BetaCasein)
            a1BetaCasein = zeroToEmpty(a1BetaCasein)

            vitaminA = zeroToEmpty(vitaminA)
            vitaminB = zeroToEmpty(vitaminB)
            vitaminC = zeroToEmpty(vitaminC)
            vitaminD = zeroToEmpty(vitaminD)
            vitaminE = zeroToEmpty(vitaminE)
            vitaminK = zeroToEmpty(vitaminK)

            calcium = zeroToEmpty(calcium)
            iron = zeroToEmpty(iron)
            potassium = zeroToEmpty(potassium)
            zinc = zeroToEmpty(zinc)
            magnesium = zeroToEmpty(magnesium)

        } else {
            // Use in-app language override for default title in new form
            mealDescription = Meal.autoTitle(for: date, languageCode: appLanguageCode)
        }

        recomputeConsistency(resetPrevMismatch: true)
    }

    // MARK: - Camera handling

    func ensureMealForPhoto() -> Meal {
        if let m = meal {
            return m
        }
        let new = Meal(context: context)
        new.id = UUID()
        new.date = Date()
        // Use selected in-app language for title
        new.title = Meal.autoTitle(for: new.date, languageCode: appLanguageCode)
        try? context.save()
        self.meal = new
        return new
    }

    func handleCapturedPhoto(data: Data, suggestedExt: String?) async {
        let targetMeal = ensureMealForPhoto()
        do {
            let newPhoto = try await MainActor.run { () throws -> MealPhoto in
                try PhotoService.addPhoto(
                    from: data,
                    suggestedUTTypeExtension: suggestedExt,
                    to: targetMeal,
                    in: context,
                    session: session
                )
            }

            await MainActor.run {
                if let url = PhotoService.urlForUpload(newPhoto) ?? PhotoService.urlForOriginal(newPhoto) {
                    _ = warmUpFileRead(url: url, retries: 2, delay: 0.08)
                }
                reloadGalleryItems()
                selectedIndex = max(0, galleryItems.count - 1)
            }
        } catch PhotoServiceError.freeTierPhotoLimitReached(let max) {
            await MainActor.run {
                let l = LocalizationManager(languageCode: appLanguageCode)
                let fmt = l.localized("free_tier_photo_limit_reached") // expects %d
                limitErrorMessage = String(format: fmt, max)
                showingLimitAlert = true
            }
        } catch {
            await MainActor.run {
                let l = LocalizationManager(languageCode: appLanguageCode)
                let fmt = l.localized("failed_to_add_photo_format") // "Failed to add photo: %@"
                limitErrorMessage = String(format: fmt, error.localizedDescription)
                showingLimitAlert = true
            }
        }
    }

    func warmUpFileRead(url: URL, retries: Int, delay: TimeInterval) -> Bool {
        if (try? Data(contentsOf: url)) != nil { return true }
        var remaining = retries
        while remaining > 0 {
            remaining -= 1
            RunLoop.current.run(until: Date().addingTimeInterval(delay))
            if (try? Data(contentsOf: url)) != nil { return true }
        }
        return false
    }

    // Camera auto-open functionality disabled
    // The camera no longer opens automatically when creating a new meal
    func scheduleAutoOpenCameraIfNeeded() {
        // Functionality removed - camera must be opened manually by the user
    }

    @MainActor
    func presentCameraAfterPermission() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let l = LocalizationManager(languageCode: appLanguageCode)
        switch status {
        case .authorized:
            showingCamera = true
        case .notDetermined:
            let granted = await requestCameraAccess()
            if granted {
                showingCamera = true
            } else {
                cameraPermissionMessage = l.localized("camera_access_needed_message")
                showingCameraPermissionAlert = true
            }
        case .denied, .restricted:
            cameraPermissionMessage = l.localized("camera_access_disabled_message")
            showingCameraPermissionAlert = true
        @unknown default:
            break
        }
    }

    func requestCameraAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - Deletion

    func deleteMeal() {
        guard let meal = meal else { return }

        // Remember the id so the deletion propagates to the cloud on the next sync.
        let deletedID = meal.id

        if let set = meal.value(forKey: "photos") as? Set<MealPhoto>, !set.isEmpty {
            for photo in set {
                PhotoService.removePhoto(photo, in: context)
            }
        }

        context.delete(meal)

        do {
            try context.save()
            SyncCoordinator.shared.enqueueMealDelete(deletedID)
            dismiss()
        } catch {
            print("Failed to delete meal: \(error)")
        }
    }

    // MARK: - Gallery composition

    func reloadGalleryItems() {
        var items: [GalleryItem] = []

        if let meal = meal {
            if let set = meal.value(forKey: "photos") as? Set<MealPhoto>, !set.isEmpty {
                let sorted = set.sorted { (a, b) in
                    let da = a.createdAt ?? .distantFuture
                    let db = b.createdAt ?? .distantFuture
                    return da < db
                }
                for p in sorted.prefix(maxPhotos) {
                    if let url = PhotoService.urlForUpload(p) ?? PhotoService.urlForOriginal(p) {
                        let version = fileVersionToken(for: url)
                        items.append(.persistent(photo: p, url: url, version: version))
                    }
                }
            }
        }

        self.galleryItems = items
        self.selectedIndex = min(self.selectedIndex, max(0, items.count - 1))
    }

    func fileVersionToken(for url: URL) -> String {
        let keys: Set<URLResourceKey> = [.contentModificationDateKey, .fileSizeKey]
        if let vals = try? url.resourceValues(forKeys: keys) {
            let ts = vals.contentModificationDate?.timeIntervalSince1970 ?? 0
            let size = (vals.fileSize ?? 0)
            return "\(ts)-\(size)"
        }
        return UUID().uuidString
    }
}

