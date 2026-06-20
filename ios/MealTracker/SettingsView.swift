import SwiftUI
import CoreData
import Combine

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject var session: SessionManager

    @AppStorage("energyUnit") private var energyUnit: EnergyUnit = .calories
    @AppStorage("appLanguageCode") private var appLanguageCode: String = LocalizationManager.defaultLanguageCode
    @AppStorage("sodiumUnit") private var sodiumUnit: SodiumUnit = .milligrams
    @AppStorage("showVitamins") private var showVitamins: Bool = false
    @AppStorage("vitaminsUnit") private var vitaminsUnit: VitaminsUnit = .milligrams
    @AppStorage("showMinerals") private var showMinerals: Bool = false
    @AppStorage("handedness") private var handedness: Handedness = .right
    @AppStorage("dataSharingPreference") private var dataSharing: DataSharingPreference = .public
    @AppStorage("showStimulants") private var showStimulants: Bool = false
    @AppStorage("openToNewMealOnLaunch") private var openToNewMealOnLaunch: Bool = false
    @AppStorage("aiFeedbackSeverity") private var aiFeedbackSeverity: AIFeedbackSeverity = .balanced
    // Keep storage but do not show any UI for it for now.
    @AppStorage("aiFeaturesEnabled") private var aiFeaturesEnabled: Bool = false
    // New: creatine visibility (default off)
    @AppStorage("showCreatine") private var showCreatine: Bool = false

    @State private var syncedDateText: String = "—"
    @State private var isSyncing: Bool = false
    @State private var syncError: String?

    @State private var showingLogin = false

    @FetchRequest(fetchRequest: Person.fetchAllRequest())
    private var people: FetchedResults<Person>

    @State private var showingAddPersonSheet: Bool = false
    @State private var newPersonName: String = ""
    @State private var addPersonError: String?

    @State private var personPendingDeletion: Person?

    // Export meals
    @State private var showingExportSuccess: Bool = false
    @State private var showingExportError: Bool = false
    @State private var exportErrorMessage: String = ""
    @State private var exportedFileURL: URL?

    private var availableLanguages: [String] {
        let codes = Bundle.main.localizations.filter { $0.lowercased() != "base" }
        let list = codes.isEmpty ? Bundle.main.preferredLocalizations : codes
        return Array(Set(list)).sorted()
    }

    private let maxActivePeople = 15
    private var isAtPeopleCap: Bool { people.count >= maxActivePeople }

    #if DEBUG
    @State private var barcodeLogCount: Int = 0
    @State private var labelDiagCount: Int = 0
    #endif

    var body: some View {
        let l = LocalizationManager(languageCode: appLanguageCode)

        // MARK: - Monetization/Entitlements (Stubbed)
        // TODO: Implement actual entitlements logic
        let tier: AccessTier = .free // Stubbed - always free tier
        let isFreeTier = true // Stubbed
        let mealsRemainingText: String = NSLocalizedString("unlimited", comment: "") // Stubbed
        let maxPhotos = 10 // Stubbed - arbitrary value

        NavigationView {
            Form {
                // Language
                Section {
                    Picker(l.localized("choose_language"), selection: $appLanguageCode) {
                        ForEach(availableLanguages, id: \.self) { code in
                            Text(LocalizationManager.displayName(for: code)).tag(code)
                        }
                    }
                }

                // Handedness
                Section(header: Text(l.localized("handedness_section_title"))) {
                    Picker("", selection: $handedness) {
                        Text(l.localized("left_handed")).tag(Handedness.left)
                        Text(l.localized("right_handed")).tag(Handedness.right)
                    }
                    .pickerStyle(.segmented)
                }

                // Nutrition options
                Section(header: Text(l.localized("nutrition_options_section_title"))) {
                    // Vitamins are always visible in Weekly Report now, but the unit still matters app-wide.
                    Picker(l.localized("vitamin_units"), selection: $vitaminsUnit) {
                        ForEach(VitaminsUnit.allCases, id: \.self) { unit in
                            Text(unit.displaySuffix(manager: l)).tag(unit)
                        }
                    }
                    Toggle(isOn: $showVitamins) { Text(l.localized("show_vitamins")) }
                    Toggle(isOn: $showMinerals) { Text(l.localized("show_minerals")) }
                    Toggle(isOn: $showStimulants) { Text(l.localized("show_stimulants")) }
                    // Localized: Creatine visibility toggle (default off)
                    Toggle(isOn: $showCreatine) { Text(l.localized("show_creatine")) }
                }

                #if DEBUG
                // Debug-only diagnostics
                Section(header: Text(l.localized("diagnostics_section_title"))) {
                    NavigationLink {
                        BarcodeLogView()
                    } label: {
                        HStack {
                            Text(l.localized("barcode_verbose_log"))
                            Spacer()
                            if barcodeLogCount > 0 {
                                Text("\(barcodeLogCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onAppear {
                        Task {
                            let count = await BarcodeLogStore.shared.lineCount()
                            await MainActor.run { barcodeLogCount = count }
                        }
                    }
                    .onReceive(BarcodeLogStore.shared.publisher.receive(on: DispatchQueue.main)) { lines in
                        barcodeLogCount = lines.count
                    }

                    NavigationLink {
                        LabelDiagnosticsView()
                    } label: {
                        HStack {
                            Text(l.localized("label_diagnostics"))
                            Spacer()
                            if labelDiagCount > 0 {
                                Text("\(labelDiagCount)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onAppear {
                        Task {
                            let count = await LabelDiagnosticsStore.shared.lineCount()
                            await MainActor.run { labelDiagCount = count }
                        }
                    }
                    .onReceive(LabelDiagnosticsStore.shared.eventsPublisher.receive(on: DispatchQueue.main)) { events in
                        labelDiagCount = events.count
                    }
                }
                #endif

                // About
                Section {
                    NavigationLink(destination: AboutView()) {
                        Text(l.localized("about_title"))
                    }
                }

                // Export Meals
                Section(header: Text(localizedOrFallback(l, "export_section_title", "Export"))) {
                    Button(action: exportMeals) {
                        HStack {
                            Text(localizedOrFallback(l, "export_meals_button", "Export Meals as JSON"))
                            Spacer()
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
            }
            .onAppear {
                Task { await loadSyncedDate() }
                enforceFreeTierPeopleIfNeeded(isFreeTier: isFreeTier)
            }
            .onChange(of: session.isLoggedIn) { _ in
                let newTier = Entitlements.tier(for: session)
                enforceFreeTierPeopleIfNeeded(isFreeTier: newTier == .free)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(l.localized("done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showingAddPersonSheet) {
                NavigationView {
                    Form {
                        Section(header: Text(NSLocalizedString("add_person_name_header", comment: "Name"))) {
                            TextField(NSLocalizedString("add_person_name_placeholder", comment: "Name"),
                                      text: Binding(
                                        get: { newPersonName },
                                        set: { value in
                                            newPersonName = value
                                            addPersonError = validationError(for: value)
                                        }
                                      ))
                                .textInputAutocapitalization(.words)
                                .disableAutocorrection(true)

                            if let error = addPersonError, !error.isEmpty {
                                Text(error).font(.footnote).foregroundStyle(.red)
                            }
                        }
                    }
                    .navigationTitle(NSLocalizedString("add_person_nav_title", comment: "Add Person"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button(NSLocalizedString("cancel", comment: "Cancel")) {
                                showingAddPersonSheet = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button(NSLocalizedString("save", comment: "Save")) {
                                attemptSaveNewPerson()
                            }
                            .disabled(validationError(for: newPersonName) != nil)
                        }
                    }
                }
            }
            .alert(localizedOrFallback(l, "export_success_title", "Export Successful"), isPresented: $showingExportSuccess) {
                if let url = exportedFileURL {
                    Button(localizedOrFallback(l, "share", "Share")) {
                        shareFile(url: url)
                    }
                }
                Button(localizedOrFallback(l, "ok", "OK"), role: .cancel) { }
            } message: {
                Text(localizedOrFallback(l, "export_success_message", "Your meals have been exported successfully."))
            }
            .alert(localizedOrFallback(l, "export_error_title", "Export Failed"), isPresented: $showingExportError) {
                Button(localizedOrFallback(l, "ok", "OK"), role: .cancel) { }
            } message: {
                Text(exportErrorMessage)
            }
        }
    }

    // ... rest of file unchanged ...

    // MARK: - Missing helper implemented to fix compile error

    private func localizedOrFallback(_ manager: LocalizationManager, _ key: String, _ fallback: String) -> String {
        let localized = manager.localized(key)
        return localized.isEmpty || localized == key ? fallback : localized
    }

    private func formatSyncedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .short
        return df.string(from: date)
    }

    private func setSyncUI(isSyncing: Bool, text: String?, error: String?) {
        self.isSyncing = isSyncing
        if let text { self.syncedDateText = text }
        self.syncError = error
    }

    private func setSyncUIOnMain(isSyncing: Bool, text: String?, error: String?) async {
        await MainActor.run {
            setSyncUI(isSyncing: isSyncing, text: text, error: error)
        }
    }

    private func loadSyncedDate() async {
        await setSyncUIOnMain(isSyncing: true, text: nil, error: nil)
        do {
            let date = try await session.dateSync.getSyncedDate()
            let text = date.map { formatSyncedDate($0) } ?? "—"
            await setSyncUIOnMain(isSyncing: false, text: text, error: nil)
        } catch {
            await setSyncUIOnMain(isSyncing: false, text: "—", error: error.localizedDescription)
        }
    }

    // MARK: - Free tier enforcement

    private func enforceFreeTierPeopleIfNeeded(isFreeTier: Bool) {
        guard isFreeTier else { return }
        // Ensure only one active person remains. Prefer the default person; otherwise keep the first.
        let active = people
        guard active.count > 1 else { return }

        // Determine keeper: default person if present, else first in fetch order.
        let keeper: Person = active.first(where: { $0.isDefault }) ?? active.first!

        // Make default if none active default exists
        if !keeper.isDefault {
            // Clear any existing default flags
            for p in active where p != keeper && p.isDefault {
                p.isDefault = false
            }
            keeper.isDefault = true
        }

        // Mark all others as removed
        for p in active where p != keeper {
            p.isRemoved = true
            p.isDefault = false
        }

        do {
            try context.save()
        } catch {
            // If save fails, silently ignore to avoid crashing settings UI
            // In a real app, you might surface an alert or log.
        }
    }

    // MARK: - Add Person helpers

    private func validationError(for rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)

        // Non-empty
        guard !trimmed.isEmpty else {
            return NSLocalizedString("person_name_error_empty", comment: "Please enter a name.")
        }

        // Reasonable length limits
        if trimmed.count > 40 {
            return NSLocalizedString("person_name_error_too_long", comment: "Name is too long.")
        }

        // Disallow names that are only punctuation/symbols
        let lettersAndDigits = trimmed.unicodeScalars.contains { CharacterSet.alphanumerics.contains($0) }
        if !lettersAndDigits {
            return NSLocalizedString("person_name_error_invalid_chars", comment: "Please use letters or numbers.")
        }

        // Uniqueness among active people (case-insensitive)
        let lower = trimmed.lowercased()
        if people.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == lower }) {
            return NSLocalizedString("person_name_error_duplicate", comment: "A person with this name already exists.")
        }

        return nil
    }

    private func attemptSaveNewPerson() {
        // Validate again before saving
        if let err = validationError(for: newPersonName) {
            addPersonError = err
            return
        }

        let name = newPersonName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Insert new Person
        let person = Person(context: context)
        person.id = UUID()
        person.name = name
        person.isRemoved = false

        // Make default if none active default exists
        let hasActiveDefault = people.contains(where: { $0.isDefault })
        person.isDefault = !hasActiveDefault

        do {
            try context.save()
            // Reset UI state
            newPersonName = ""
            addPersonError = nil
            showingAddPersonSheet = false
        } catch {
            addPersonError = error.localizedDescription
        }
    }

    // MARK: - Export Meals

    private func exportMeals() {
        Task {
            do {
                let fileURL = try await generateMealsJSON()
                await MainActor.run {
                    exportedFileURL = fileURL
                    showingExportSuccess = true
                }
            } catch {
                await MainActor.run {
                    exportErrorMessage = error.localizedDescription
                    showingExportError = true
                }
            }
        }
    }

    private func generateMealsJSON() async throws -> URL {
        // Fetch all meals
        let fetchRequest = Meal.fetchAllMealsRequest()
        
        return try await context.perform {
            let meals = try self.context.fetch(fetchRequest)
            
            // Convert meals to JSON-friendly dictionaries
            var mealsArray: [[String: Any]] = []
            
            for meal in meals {
                var mealDict: [String: Any] = [:]
                
                // Always include ID, title, and date
                mealDict["id"] = meal.id.uuidString
                if !meal.title.isEmpty {
                    mealDict["title"] = meal.title
                }
                mealDict["date"] = ISO8601DateFormatter().string(from: meal.date)
                
                // Add non-zero numeric values
                self.addIfNonZero(&mealDict, key: "calories", value: meal.calories, isGuess: meal.caloriesIsGuess)
                self.addIfNonZero(&mealDict, key: "carbohydrates", value: meal.carbohydrates, isGuess: meal.carbohydratesIsGuess)
                self.addIfNonZero(&mealDict, key: "protein", value: meal.protein, isGuess: meal.proteinIsGuess)
                self.addIfNonZero(&mealDict, key: "sodium", value: meal.sodium, isGuess: meal.sodiumIsGuess)
                self.addIfNonZero(&mealDict, key: "fat", value: meal.fat, isGuess: meal.fatIsGuess)
                
                // Location
                if meal.latitude != 0 || meal.longitude != 0 {
                    mealDict["latitude"] = meal.latitude
                    mealDict["longitude"] = meal.longitude
                }
                
                // Alcohol and stimulants
                self.addIfNonZero(&mealDict, key: "alcohol", value: meal.alcohol, isGuess: meal.alcoholIsGuess)
                self.addIfNonZero(&mealDict, key: "nicotine", value: meal.nicotine, isGuess: meal.nicotineIsGuess)
                self.addIfNonZero(&mealDict, key: "theobromine", value: meal.theobromine, isGuess: meal.theobromineIsGuess)
                self.addIfNonZero(&mealDict, key: "caffeine", value: meal.caffeine, isGuess: meal.caffeineIsGuess)
                self.addIfNonZero(&mealDict, key: "taurine", value: meal.taurine, isGuess: meal.taurineIsGuess)
                self.addIfNonZero(&mealDict, key: "creatine", value: meal.creatine, isGuess: meal.creatineIsGuess)
                
                // Carbohydrate breakdown
                self.addIfNonZero(&mealDict, key: "starch", value: meal.starch, isGuess: meal.starchIsGuess)
                self.addIfNonZero(&mealDict, key: "sugars", value: meal.sugars, isGuess: meal.sugarsIsGuess)
                self.addIfNonZero(&mealDict, key: "fibre", value: meal.fibre, isGuess: meal.fibreIsGuess)
                
                // Fat breakdown
                self.addIfNonZero(&mealDict, key: "monounsaturatedFat", value: meal.monounsaturatedFat, isGuess: meal.monounsaturatedFatIsGuess)
                self.addIfNonZero(&mealDict, key: "polyunsaturatedFat", value: meal.polyunsaturatedFat, isGuess: meal.polyunsaturatedFatIsGuess)
                self.addIfNonZero(&mealDict, key: "saturatedFat", value: meal.saturatedFat, isGuess: meal.saturatedFatIsGuess)
                self.addIfNonZero(&mealDict, key: "transFat", value: meal.transFat, isGuess: meal.transFatIsGuess)
                self.addIfNonZero(&mealDict, key: "omega3", value: meal.omega3, isGuess: meal.omega3IsGuess)
                self.addIfNonZero(&mealDict, key: "omega6", value: meal.omega6, isGuess: meal.omega6IsGuess)
                
                // Protein breakdown
                self.addIfNonZero(&mealDict, key: "animalProtein", value: meal.animalProtein, isGuess: meal.animalProteinIsGuess)
                self.addIfNonZero(&mealDict, key: "plantProtein", value: meal.plantProtein, isGuess: meal.plantProteinIsGuess)
                self.addIfNonZero(&mealDict, key: "proteinSupplements", value: meal.proteinSupplements, isGuess: meal.proteinSupplementsIsGuess)
                self.addIfNonZero(&mealDict, key: "a2BetaCasein", value: meal.a2BetaCasein, isGuess: meal.a2BetaCaseinIsGuess)
                self.addIfNonZero(&mealDict, key: "a1BetaCasein", value: meal.a1BetaCasein, isGuess: meal.a1BetaCaseinIsGuess)
                
                // Vitamins
                self.addIfNonZero(&mealDict, key: "vitaminA", value: meal.vitaminA, isGuess: meal.vitaminAIsGuess)
                self.addIfNonZero(&mealDict, key: "vitaminB", value: meal.vitaminB, isGuess: meal.vitaminBIsGuess)
                self.addIfNonZero(&mealDict, key: "vitaminC", value: meal.vitaminC, isGuess: meal.vitaminCIsGuess)
                self.addIfNonZero(&mealDict, key: "vitaminD", value: meal.vitaminD, isGuess: meal.vitaminDIsGuess)
                self.addIfNonZero(&mealDict, key: "vitaminE", value: meal.vitaminE, isGuess: meal.vitaminEIsGuess)
                self.addIfNonZero(&mealDict, key: "vitaminK", value: meal.vitaminK, isGuess: meal.vitaminKIsGuess)
                
                // Minerals
                self.addIfNonZero(&mealDict, key: "calcium", value: meal.calcium, isGuess: meal.calciumIsGuess)
                self.addIfNonZero(&mealDict, key: "iron", value: meal.iron, isGuess: meal.ironIsGuess)
                self.addIfNonZero(&mealDict, key: "potassium", value: meal.potassium, isGuess: meal.potassiumIsGuess)
                self.addIfNonZero(&mealDict, key: "zinc", value: meal.zinc, isGuess: meal.zincIsGuess)
                self.addIfNonZero(&mealDict, key: "magnesium", value: meal.magnesium, isGuess: meal.magnesiumIsGuess)
                self.addIfNonZero(&mealDict, key: "iodine", value: meal.iodine, isGuess: meal.iodineIsGuess)
                self.addIfNonZero(&mealDict, key: "phosphorus", value: meal.phosphorus, isGuess: meal.phosphorusIsGuess)
                
                // Optional strings
                if let syncGUID = meal.lastSyncGUID, !syncGUID.isEmpty {
                    mealDict["lastSyncGUID"] = syncGUID
                }
                if let guesserType = meal.photoGuesserType, !guesserType.isEmpty {
                    mealDict["photoGuesserType"] = guesserType
                }
                if let productName = meal.productName, !productName.isEmpty {
                    mealDict["productName"] = productName
                }
                
                mealsArray.append(mealDict)
            }
            
            // Create JSON data
            let jsonData = try JSONSerialization.data(withJSONObject: mealsArray, options: [.prettyPrinted, .sortedKeys])
            
            // Save to temporary file
            let tempDir = FileManager.default.temporaryDirectory
            let fileName = "meals_export_\(ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")).json"
            let fileURL = tempDir.appendingPathComponent(fileName)
            
            try jsonData.write(to: fileURL)
            
            return fileURL
        }
    }

    private func addIfNonZero(_ dict: inout [String: Any], key: String, value: Double, isGuess: Bool) {
        if value != 0 {
            dict[key] = value
            if isGuess {
                dict["\(key)IsGuess"] = true
            }
        }
    }

    private func shareFile(url: URL) {
        let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            
            // Find the topmost presented view controller
            var topController = rootViewController
            while let presented = topController.presentedViewController {
                topController = presented
            }
            
            // For iPad, set the popover presentation controller
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topController.view
                popover.sourceRect = CGRect(x: topController.view.bounds.midX, y: topController.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            topController.present(activityVC, animated: true)
        }
    }
}

