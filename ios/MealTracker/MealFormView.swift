//
//  MealFormView.swift
//  MealTracker
//
//  Created by Simon Lee on 17/11/2025.
//

import SwiftUI
import CoreData
import UIKit
import AVFoundation

struct MealFormView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.managedObjectContext) var context
    @EnvironmentObject var session: SessionManager
    @Environment(\.scenePhase) var scenePhase

    // App settings
    @AppStorage("energyUnit") var energyUnit: EnergyUnit = .calories
    @AppStorage("appLanguageCode") var appLanguageCode: String = LocalizationManager.defaultLanguageCode
    @AppStorage("sodiumUnit") var sodiumUnit: SodiumUnit = .milligrams
    @AppStorage("showVitamins") var showVitamins: Bool = false
    @AppStorage("vitaminsUnit") var vitaminsUnit: VitaminsUnit = .milligrams
    @AppStorage("showMinerals") var showMinerals: Bool = false
    // New: stimulants group visibility (key matches SettingsView)
    @AppStorage("showStimulants") var showStimulants: Bool = false
    // New: AI features master toggle (matches SettingsView)
    @AppStorage("aiFeaturesEnabled") var aiFeaturesEnabled: Bool = false
    // New: creatine visibility (default off)
    @AppStorage("showCreatine") var showCreatine: Bool = false

    // Fetch active people (non-soft-deleted)
    @FetchRequest(fetchRequest: Person.fetchAllRequest())
    private var people: FetchedResults<Person>

    // Selected person for this meal (Pro only)
    @State private var selectedPerson: Person?

    // Person picker presentation
    @State private var showingPersonPicker: Bool = false

    // Hidden title/date inputs removed from UI; we still keep local state for default title logic
    @State var mealDescription: String = "" // not shown in UI for new meals
    // Numeric inputs (grams now allow decimals)
    @State var calories: String = ""
    @State var carbohydrates: String = ""
    @State var protein: String = ""
    @State var sodium: String = ""          // renamed from salt for UI
    @State var fat: String = ""
    // Alcohol (grams)
    @State var alcohol: String = ""
    // Nicotine (milligrams)
    @State var nicotine: String = ""
    // Theobromine (milligrams)
    @State var theobromine: String = ""
    // Caffeine (milligrams) [NEW]
    @State var caffeine: String = ""
    // Taurine (milligrams) [NEW]
    @State var taurine: String = ""
    // Creatine (milligrams) [NEW]
    @State var creatine: String = ""

    // Added missing nutrient fields
    @State var starch: String = ""
    @State var sugars: String = ""
    @State var fibre: String = ""
    // New fat breakdown fields
    @State var monounsaturatedFat: String = ""
    @State var polyunsaturatedFat: String = ""
    @State var saturatedFat: String = ""
    @State var transFat: String = ""
    // New: Omega-3 (grams)
    @State var omega3: String = ""
    // New: Omega-6 (grams)
    @State var omega6: String = ""

    // New protein breakdown fields
    @State var animalProtein: String = ""
    @State var plantProtein: String = ""
    @State var proteinSupplements: String = ""
    // New: A2 beta-casein (grams)
    @State var a2BetaCasein: String = ""
    // New: A1 beta-casein (grams)
    @State var a1BetaCasein: String = ""

    // Vitamins (UI text values; storage is mg, conversion applied)
    @State var vitaminA: String = ""
    @State var vitaminB: String = ""
    @State var vitaminC: String = ""
    @State var vitaminD: String = ""
    @State var vitaminE: String = ""
    @State var vitaminK: String = ""

    // Minerals (UI text values; storage is mg, conversion applied)
    @State var calcium: String = ""
    @State var iron: String = ""
    @State var potassium: String = ""
    @State var zinc: String = ""
    @State var magnesium: String = ""
    // New: Iodine (UI text value; storage is mg)
    @State var iodine: String = ""
    // New: Phosphorus (UI text value; storage is mg)
    @State var phosphorus: String = ""

    // Accuracy flags: default Guess = true
    @State var caloriesIsGuess = true
    @State var carbohydratesIsGuess = true
    @State var proteinIsGuess = true
    @State var sodiumIsGuess = true
    @State var fatIsGuess = true
    @State var alcoholIsGuess = true
    @State var nicotineIsGuess = true
    @State var theobromineIsGuess = true
    // Caffeine accuracy flag [NEW]
    @State var caffeineIsGuess = true
    // Taurine accuracy flag [NEW]
    @State var taurineIsGuess = true
    // Creatine accuracy flag [NEW]
    @State var creatineIsGuess = true
    @State var starchIsGuess = true
    @State var sugarsIsGuess = true
    @State var fibreIsGuess = true
    @State var monounsaturatedFatIsGuess = true
    @State var polyunsaturatedFatIsGuess = true
    @State var saturatedFatIsGuess = true
    @State var transFatIsGuess = true
    // New: Omega-3 accuracy flag
    @State var omega3IsGuess = true
    // New: Omega-6 accuracy flag
    @State var omega6IsGuess = true

    // Protein breakdown flags
    @State var animalProteinIsGuess = true
    @State var plantProteinIsGuess = true
    @State var proteinSupplementsIsGuess = true
    // New: A2 beta-casein flag
    @State var a2BetaCaseinIsGuess = true
    // New: A1 beta-casein flag
    @State var a1BetaCaseinIsGuess = true
    // Vitamins guess flags
    @State var vitaminAIsGuess = true
    @State var vitaminBIsGuess = true
    @State var vitaminCIsGuess = true
    @State var vitaminDIsGuess = true
    @State var vitaminEIsGuess = true
    @State var vitaminKIsGuess = true
    // Minerals guess flags
    @State var calciumIsGuess = true
    @State var ironIsGuess = true
    @State var potassiumIsGuess = true
    @State var zincIsGuess = true
    @State var magnesiumIsGuess = true
    // New: Iodine guess flag
    @State var iodineIsGuess = true
    // New: Phosphorus guess flag
    @State var phosphorusIsGuess = true

    // Touched flags to avoid overwriting manual edits
    @State var sugarsTouched = false
    @State var starchTouched = false
    @State var fibreTouched = false

    @State var monoTouched = false
    @State var polyTouched = false
    @State var satTouched = false
    @State var transTouched = false
    @State var omega3Touched = false
    @State var omega6Touched = false

    @State var animalTouched = false
    @State var plantTouched = false
    @State var supplementsTouched = false

    // Track last auto-sum for totals so we can keep updating while user types
    @State var carbsLastAutoSum: Int?
    @State var proteinLastAutoSum: Int?
    @State var fatLastAutoSum: Int?

    // We won’t show date picker; date will be set on save
    @State var date: Date = Date()

    // Settings presentation
    @State var showingSettings = false

    // Expand/collapse state (per session, compatible with older iOS)
    @State var expandedCarbs = false
    @State var expandedProtein = false
    @State var expandedFat = false
    @State var expandedVitamins = false
    @State var expandedMinerals = false
    // New: Stimulants expansion
    @State var expandedStimulants = false

    // Group consistency states
    @State var carbsMismatch = false
    @State var proteinMismatch = false
    @State var fatMismatch = false

    @State var carbsBlink = false
    @State var proteinBlink = false
    @State var fatBlink = false

    // New: short red blink when subfields have values but top-level is empty at time of edit
    @State var carbsRedBlink = false
    @State var proteinRedBlink = false
    @State var fatRedBlink = false

    // Helper number states (brief “(sum)” display)
    @State var carbsHelperText: String = ""
    @State var proteinHelperText: String = ""
    @State var fatHelperText: String = ""

    @State var carbsHelperVisible: Bool = false
    @State var proteinHelperVisible: Bool = false
    @State var fatHelperVisible: Bool = false

    // Track previous mismatch to detect corrections
    @State var prevCarbsMismatch = false
    @State var prevProteinMismatch = false
    @State var prevFatMismatch = false

    // Focus handling to delay validation until leaving a field
    enum FocusedField: Hashable {
        case calories
        case carbsTotal
        case proteinTotal
        case fatTotal
        case sodium
        case generic(String) // use for all other fields to support Done dismissal
    }
    @FocusState var focused: FocusedField?
    @State var lastFocused: FocusedField?

    // MARK: - Gallery state
    let maxPhotos = 2
    @State var galleryItems: [GalleryItem] = [] // ordered, display-ready
    @State var selectedIndex: Int = 0

    // Expanded header height toggle (kept from previous UI)
    @State var isImageExpanded: Bool = false

    // MARK: - Analyze button state
    @State var isAnalyzing: Bool = false
    @State var analyzeError: String?

    // New: live progress/status line for the wizard overlay
    @State var wizardProgress: String?

    // New: transient barcode display
    @State var lastDetectedBarcode: String?

    // Force-enable Save after wand finishes
    @State var forceEnableSave: Bool = false

    // MARK: - Limit alert state
    @State var showingLimitAlert: Bool = false
    @State var limitErrorMessage: String?

    // MARK: - Delete confirmation state
    @State var showingDeleteConfirm: Bool = false

    // MARK: - Camera state
    @State var showingCamera: Bool = false
    @State var cameraErrorMessage: String?

    // Auto-open gating and permission alert
    @State var didAutoOpenThisActivation: Bool = false
    @State var showingCameraPermissionAlert: Bool = false
    @State var cameraPermissionMessage: String?

    // Track if this home screen is currently visible (not pushed away)
    @State var isHomeVisible: Bool = false

    // MARK: - Photo library state
    @State var showingPhotoPicker: Bool = false

    @State var meal: Meal?

    // New: distinguish explicit edit mode (opened from gallery) from auto-created meals for photos
    let explicitEditMode: Bool

    // MARK: - Wizard undo state
    @State var wizardUndoSnapshot: WizardSnapshot?
    @State var wizardCanUndo: Bool = false

    // MARK: - DEBUG-only wizard log buffer
    #if DEBUG
    @State private var wizardDebugLog: [String] = []
    func appendWizardLog(_ message: String) {
        let ts = Date()
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        let line = "[\(df.string(from: ts))] \(message)"
        wizardDebugLog.append(line)
        // Keep log bounded
        if wizardDebugLog.count > 200 {
            wizardDebugLog.removeFirst(wizardDebugLog.count - 200)
        }
    }
    #endif

    init(meal: Meal? = nil) {
        self._meal = State(initialValue: meal)
        // If the caller provided a meal, we’re explicitly editing.
        self.explicitEditMode = (meal != nil)
    }

    // Keep this for other logic if needed, but UI visibility will use explicitEditMode
    var isEditing: Bool { meal != nil }

    // MARK: - Wizard status (short, top-left)
    private var wizardStatusText: String {
        let l = LocalizationManager(languageCode: appLanguageCode)
        guard aiFeaturesEnabled, !galleryItems.isEmpty else { return "" }

        // While analyzing, show progress or generic message
        if isAnalyzing {
            if let progress = wizardProgress, !progress.isEmpty {
                return progress
            }
            return l.localized("wizard_analyzing")
        }

        // Show errors immediately if present
        if let err = analyzeError, !err.isEmpty {
            return err
        }

        // After wizard completes: prefer product name, else barcode, else applied tag
        let product = meal?.productName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if wizardCanUndo {
            if let product, !product.isEmpty {
                return product
            }
            if let code = lastDetectedBarcode, !code.isEmpty {
                let fmt = l.localized("wizard_barcode_format") // e.g., "Barcode: %@"
                return String(format: fmt, code)
            }
            if let tag = meal?.photoGuesserType, !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let fmt = l.localized("wizard_applied_format") // e.g., "Applied: %@"
                return String(format: fmt, tag)
            }
            return l.localized("wizard_applied")
        }

        // If not in undo state but we still have a product name after completion, show it
        if let product, !product.isEmpty {
            return product
        }

        // Fallback to transient barcode if available
        if let code = lastDetectedBarcode, !code.isEmpty {
            let fmt = l.localized("wizard_barcode_format")
            return String(format: fmt, code)
        }

        // Otherwise pass through any remaining progress text, or nothing
        if let progress = wizardProgress, !progress.isEmpty {
            return progress
        }
        return ""
    }

    private var wizardStatusIsError: Bool {
        return aiFeaturesEnabled && (analyzeError != nil)
    }

    var body: some View {
        // Keep local constants lightly typed to help the solver
        let l: LocalizationManager = LocalizationManager(languageCode: appLanguageCode)
        let fullHeight: CGFloat = UIScreen.main.bounds.height * 0.45
        let collapsedHeight: CGFloat = fullHeight * 0.5

        return mainContent(l: l, fullHeight: fullHeight, collapsedHeight: collapsedHeight)
    }

    // Split the large body into a smaller builder
    @ViewBuilder
    func mainContent(l: LocalizationManager, fullHeight: CGFloat, collapsedHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            GalleryHeader(
                items: galleryItems,
                selectedIndex: $selectedIndex,
                isExpanded: $isImageExpanded,
                fullHeight: fullHeight,
                collapsedHeight: collapsedHeight,
                isBusy: $isAnalyzing.wrappedValue,
                onAnalyzeTap: {
                    Task { await analyzePhotoWithSnapshot() }
                },
                onCameraTap: {
                    showingCamera = true
                },
                onPhotosTap: {
                    showingPhotoPicker = true
                },
                // New: pass undo state/handler
                isUndoAvailable: wizardCanUndo,
                onUndoTap: {
                    undoWizard()
                },
                trailingAccessoryButton: personSelectorAccessoryIfEligible(),
                // Gate wizard visibility
                aiEnabled: aiFeaturesEnabled,
                // New: short status text overlay (top-left)
                statusText: wizardStatusText,
                statusIsError: wizardStatusIsError
            )

            formContent(l: l)
                .modifier(CompactSectionSpacing())
        }
        // Toolbar: Settings + Delete (editing) + Save (trailing). No explicit Cancel; use system Back.
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityIdentifier("toolbar_settings")

                if isEditing {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityIdentifier("toolbar_delete")
                }
                Button(l.localized("save")) {
                    save()
                }
                .disabled(!(isValid || forceEnableSave))
                .accessibilityIdentifier("toolbar_save")
            }
            // Keyboard toolbar: Done button to dismiss number/decimal pads
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(l.localized("keyboard_done")) {
                    focused = nil
                }
                .accessibilityIdentifier("keyboard_done")
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(session)
        }
        .sheet(isPresented: $showingCamera) {
            CameraCaptureView { result in
                switch result {
                case .success(let payload):
                    Task { await handleCapturedPhoto(data: payload.data, suggestedExt: payload.suggestedExt) }
                case .failure(let error):
                    cameraErrorMessage = error.localizedDescription
                    limitErrorMessage = cameraErrorMessage
                    showingLimitAlert = cameraErrorMessage != nil
                case .none:
                    break
                }
                showingCamera = false
            }
        }
        .sheet(isPresented: $showingPhotoPicker) {
            PhotoLibraryPickerView { result in
                switch result {
                case .success(let payload):
                    Task { await handleCapturedPhoto(data: payload.data, suggestedExt: payload.suggestedExt) }
                case .failure(let error):
                    limitErrorMessage = error.localizedDescription
                    showingLimitAlert = true
                case .none:
                    break
                }
                showingPhotoPicker = false
            }
        }
        .alert(isPresented: $showingLimitAlert) {
            Alert(
                title: Text(l.localized("alert_limit_reached_title")),
                message: Text(limitErrorMessage ?? l.localized("alert_limit_reached_message")),
                dismissButton: .default(Text(l.localized("ok")))
            )
        }
        .alert(l.localized("camera_access_needed_title"), isPresented: $showingCameraPermissionAlert) {
            Button(l.localized("cancel"), role: .cancel) { }
            Button(l.localized("open_settings")) {
                if let url = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(url)
                }
            }
        } message: {
            Text(cameraPermissionMessage ?? l.localized("camera_access_needed_message"))
        }
        .confirmationDialog(
            LocalizationManager(languageCode: appLanguageCode).localized("confirm_delete_title"),
            isPresented: $showingDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                deleteMeal()
            } label: {
                Text(LocalizationManager(languageCode: appLanguageCode).localized("delete"))
            }
            Button(LocalizationManager(languageCode: appLanguageCode).localized("cancel"), role: .cancel) { }
        } message: {
            Text(LocalizationManager(languageCode: appLanguageCode).localized("confirm_delete_message"))
        }
        .onChange(of: focused, perform: { newFocus in
            if let leaving = lastFocused, leaving != newFocus {
                handleFocusLeaveIfNeeded(leaving: leaving)
            }
            lastFocused = newFocus
        })
        .onAppear { onAppearSetup(l: l); initializeSelectedPersonIfNeeded() }
        .onDisappear { isHomeVisible = false }
        // Person picker sheet
        .actionSheet(isPresented: $showingPersonPicker) {
            ActionSheet(
                title: Text(l.localized("select_person_title")),
                buttons: personActionSheetButtons()
            )
        }
    }

    // Build the trailing accessory button if user is eligible to assign person
    private func personSelectorAccessoryIfEligible() -> AnyView? {
        let l = LocalizationManager(languageCode: appLanguageCode)
        let tier = Entitlements.tier(for: session)
        guard session.isLoggedIn && tier == .paid && !people.isEmpty && !galleryItems.isEmpty else {
            return nil
        }
        let title = l.localized("select_person_title")
        return AnyView(
            PersonPickerButton(title: title) {
                showingPersonPicker = true
            }
        )
    }

    // MARK: - Missing helpers implemented below

    @ViewBuilder
    private func formContent(l: LocalizationManager) -> some View {
        Form {
            // Calories
            Section {
                MetricField(
                    titleKey: "calories",
                    text: numericBindingInt($calories),
                    isGuess: $caloriesIsGuess,
                    keyboard: .numberPad,
                    manager: l,
                    unitSuffix: (energyUnit == .calories ? l.localized("unit_kcal_suffix") : l.localized("unit_kj_suffix")),
                    validator: { ValidationThresholds.calories.severity(for: $0) },
                    focusedField: $focused,
                    thisField: .calories,
                    onSubmit: { focused = nil }
                )
            }

            // Carbohydrates
            Section {
                VStack(spacing: 0) {
                    MetricField(
                        titleKey: "carbohydrates",
                        text: numericBindingDecimal($carbohydrates),
                        isGuess: $carbohydratesIsGuess,
                        keyboard: .decimalPad,
                        manager: l,
                        unitSuffix: l.localized("unit_g_suffix"),
                        doubleValidator: { ValidationThresholds.grams.severityDouble($0) },
                        leadingAccessory: {
                            AnyView(
                                Group {
                                    if carbsHelperVisible {
                                        let fmt = l.localized("helper_sum_parens_format")
                                        Text(String(format: fmt, carbsHelperText))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            )
                        },
                        highlight: carbsMismatch ? (carbsBlink ? .successBlink(active: true) : .error) : (carbsRedBlink ? .error : .none),
                        focusedField: $focused,
                        thisField: .carbsTotal,
                        onSubmit: {
                            focused = nil
                            handleHelperOnTopChangeForCarbs()
                        }
                    )

                    ToggleDetailsButton(
                        isExpanded: $expandedCarbs,
                        titleCollapsed: l.localized("show_details"),
                        titleExpanded: l.localized("hide_details")
                    )

                    if expandedCarbs {
                        CarbsSubFields(
                            manager: l,
                            sugarsText: $sugars, sugarsIsGuess: $sugarsIsGuess,
                            starchText: $starch, starchIsGuess: $starchIsGuess,
                            fibreText: $fibre, fibreIsGuess: $fibreIsGuess,
                            focusedField: $focused
                        )
                        .onChange(of: sugars) { _ in sugarsTouched = true; handleTopFromCarbSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: starch) { _ in starchTouched = true; handleTopFromCarbSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: fibre) { _ in fibreTouched = true; handleTopFromCarbSubs(); recomputeConsistencyAndBlinkIfFixed() }
                    }
                }
            }

            // Protein
            Section {
                VStack(spacing: 0) {
                    MetricField(
                        titleKey: "protein",
                        text: numericBindingDecimal($protein),
                        isGuess: $proteinIsGuess,
                        keyboard: .decimalPad,
                        manager: l,
                        unitSuffix: l.localized("unit_g_suffix"),
                        doubleValidator: { ValidationThresholds.grams.severityDouble($0) },
                        leadingAccessory: {
                            AnyView(
                                Group {
                                    if proteinHelperVisible {
                                        let fmt = l.localized("helper_sum_parens_format")
                                        Text(String(format: fmt, proteinHelperText))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            )
                        },
                        highlight: proteinMismatch ? (proteinBlink ? .successBlink(active: true) : .error) : (proteinRedBlink ? .error : .none),
                        focusedField: $focused,
                        thisField: .proteinTotal,
                        onSubmit: {
                            focused = nil
                            handleHelperOnTopChangeForProtein()
                        }
                    )

                    ToggleDetailsButton(
                        isExpanded: $expandedProtein,
                        titleCollapsed: l.localized("show_details"),
                        titleExpanded: l.localized("hide_details")
                    )

                    if expandedProtein {
                        ProteinSubFields(
                            manager: l,
                            animalText: $animalProtein, animalIsGuess: $animalProteinIsGuess,
                            plantText: $plantProtein, plantIsGuess: $plantProteinIsGuess,
                            supplementsText: $proteinSupplements, supplementsIsGuess: $proteinSupplementsIsGuess,
                            a2Text: $a2BetaCasein, a2IsGuess: $a2BetaCaseinIsGuess,
                            a1Text: $a1BetaCasein, a1IsGuess: $a1BetaCaseinIsGuess,
                            focusedField: $focused
                        )
                        .onChange(of: animalProtein) { _ in animalTouched = true; handleTopFromProteinSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: plantProtein) { _ in plantTouched = true; handleTopFromProteinSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: proteinSupplements) { _ in supplementsTouched = true; handleTopFromProteinSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: a2BetaCasein) { _ in handleTopFromProteinSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: a1BetaCasein) { _ in handleTopFromProteinSubs(); recomputeConsistencyAndBlinkIfFixed() }
                    }
                }
            }

            // Fat
            Section {
                VStack(spacing: 0) {
                    MetricField(
                        titleKey: "fat",
                        text: numericBindingDecimal($fat),
                        isGuess: $fatIsGuess,
                        keyboard: .decimalPad,
                        manager: l,
                        unitSuffix: l.localized("unit_g_suffix"),
                        doubleValidator: { ValidationThresholds.grams.severityDouble($0) },
                        leadingAccessory: {
                            AnyView(
                                Group {
                                    if fatHelperVisible {
                                        let fmt = l.localized("helper_sum_parens_format")
                                        Text(String(format: fmt, fatHelperText))
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            )
                        },
                        highlight: fatMismatch ? (fatBlink ? .successBlink(active: true) : .error) : (fatRedBlink ? .error : .none),
                        focusedField: $focused,
                        thisField: .fatTotal,
                        onSubmit: {
                            focused = nil
                            handleHelperOnTopChangeForFat()
                        }
                    )

                    ToggleDetailsButton(
                        isExpanded: $expandedFat,
                        titleCollapsed: l.localized("show_details"),
                        titleExpanded: l.localized("hide_details")
                    )

                    if expandedFat {
                        FatSubFields(
                            manager: l,
                            monoText: $monounsaturatedFat, monoIsGuess: $monounsaturatedFatIsGuess,
                            polyText: $polyunsaturatedFat, polyIsGuess: $polyunsaturatedFatIsGuess,
                            satText: $saturatedFat, satIsGuess: $saturatedFatIsGuess,
                            transText: $transFat, transIsGuess: $transFatIsGuess,
                            omega3Text: $omega3, omega3IsGuess: $omega3IsGuess,
                            omega6Text: $omega6, omega6IsGuess: $omega6IsGuess,
                            focusedField: $focused
                        )
                        .onChange(of: monounsaturatedFat) { _ in monoTouched = true; handleTopFromFatSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: polyunsaturatedFat) { _ in polyTouched = true; handleTopFromFatSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: saturatedFat) { _ in satTouched = true; handleTopFromFatSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: transFat) { _ in transTouched = true; handleTopFromFatSubs(); recomputeConsistencyAndBlinkIfFixed() }
                        .onChange(of: omega3) { _ in omega3Touched = true }
                        .onChange(of: omega6) { _ in omega6Touched = true }
                    }
                }
            }

            // Sodium
            Section {
                if sodiumUnit == .milligrams {
                    MetricField(
                        titleKey: "sodium",
                        text: numericBindingInt($sodium),
                        isGuess: $sodiumIsGuess,
                        keyboard: .numberPad,
                        manager: l,
                        unitSuffix: l.localized("unit_mg_suffix"),
                        validator: { ValidationThresholds.sodiumMg.severity(for: $0) },
                        focusedField: $focused,
                        thisField: .sodium,
                        onSubmit: { focused = nil }
                    )
                } else {
                    MetricField(
                        titleKey: "sodium",
                        text: numericBindingDecimal($sodium),
                        isGuess: $sodiumIsGuess,
                        keyboard: .decimalPad,
                        manager: l,
                        unitSuffix: l.localized("unit_g_suffix"),
                        doubleValidator: { ValidationThresholds.sodiumG.severityDouble($0) },
                        focusedField: $focused,
                        thisField: .sodium,
                        onSubmit: { focused = nil }
                    )
                }
            }

            // Stimulants group (optional)
            if showStimulants {
                Section(header: Text(l.localized("stimulants_section_title"))) {
                    MetricField(titleKey: "alcohol", text: numericBindingDecimal($alcohol), isGuess: $alcoholIsGuess, keyboard: .decimalPad, manager: l, unitSuffix: l.localized("unit_g_suffix"), doubleValidator: { ValidationThresholds.grams.severityDouble($0) }, focusedField: $focused, thisField: .generic("alcohol"), onSubmit: { focused = nil })
                    MetricField(titleKey: "nicotine", text: numericBindingInt($nicotine), isGuess: $nicotineIsGuess, keyboard: .numberPad, manager: l, unitSuffix: l.localized("unit_mg_suffix"), validator: { ValidationThresholds.vitaminMineralMg.severity(for: $0) }, focusedField: $focused, thisField: .generic("nicotine"), onSubmit: { focused = nil })
                    MetricField(titleKey: "theobromine", text: numericBindingInt($theobromine), isGuess: $theobromineIsGuess, keyboard: .numberPad, manager: l, unitSuffix: l.localized("unit_mg_suffix"), validator: { ValidationThresholds.vitaminMineralMg.severity(for: $0) }, focusedField: $focused, thisField: .generic("theobromine"), onSubmit: { focused = nil })
                    MetricField(titleKey: "caffeine", text: numericBindingInt($caffeine), isGuess: $caffeineIsGuess, keyboard: .numberPad, manager: l, unitSuffix: l.localized("unit_mg_suffix"), validator: { ValidationThresholds.vitaminMineralMg.severity(for: $0) }, focusedField: $focused, thisField: .generic("caffeine"), onSubmit: { focused = nil })
                    MetricField(titleKey: "taurine", text: numericBindingInt($taurine), isGuess: $taurineIsGuess, keyboard: .numberPad, manager: l, unitSuffix: l.localized("unit_mg_suffix"), validator: { ValidationThresholds.vitaminMineralMg.severity(for: $0) }, focusedField: $focused, thisField: .generic("taurine"), onSubmit: { focused = nil })
                }
            }

            // Creatine (optional, its own section)
            if showCreatine {
                Section(header: Text(l.localized("creatine_section_title"))) {
                    MetricField(titleKey: "creatine", text: numericBindingInt($creatine), isGuess: $creatineIsGuess, keyboard: .numberPad, manager: l, unitSuffix: l.localized("unit_mg_suffix"), validator: { ValidationThresholds.vitaminMineralMg.severity(for: $0) }, focusedField: $focused, thisField: .generic("creatine"), onSubmit: { focused = nil })
                }
            }

            // Vitamins (optional)
            if showVitamins {
                Section(header: Text(l.localized("vitamins_section_title"))) {
                    VitaminsGroupView(
                        manager: l,
                        unitSuffix: vitaminsUnit.displaySuffix(manager: l),
                        vitaminsUnit: vitaminsUnit,
                        aText: $vitaminA, aIsGuess: $vitaminAIsGuess,
                        bText: $vitaminB, bIsGuess: $vitaminBIsGuess,
                        cText: $vitaminC, cIsGuess: $vitaminCIsGuess,
                        dText: $vitaminD, dIsGuess: $vitaminDIsGuess,
                        eText: $vitaminE, eIsGuess: $vitaminEIsGuess,
                        kText: $vitaminK, kIsGuess: $vitaminKIsGuess,
                        focusedField: $focused
                    )
                }
            }

            // Minerals (optional)
            if showMinerals {
                Section(header: Text(l.localized("minerals_section_title"))) {
                    MineralsGroupView(
                        manager: l,
                        unitSuffix: vitaminsUnit.displaySuffix(manager: l),
                        vitaminsUnit: vitaminsUnit,
                        calciumText: $calcium, calciumIsGuess: $calciumIsGuess,
                        ironText: $iron, ironIsGuess: $ironIsGuess,
                        potassiumText: $potassium, potassiumIsGuess: $potassiumIsGuess,
                        zincText: $zinc, zincIsGuess: $zincIsGuess,
                        magnesiumText: $magnesium, magnesiumIsGuess: $magnesiumIsGuess,
                        phosphorusText: $phosphorus, phosphorusIsGuess: $phosphorusIsGuess,
                        iodineText: $iodine, iodineIsGuess: $iodineIsGuess,
                        focusedField: $focused
                    )
                }
            }

            // Analysis error feedback
            if let analyzeError, aiFeaturesEnabled {
                Section {
                    Text(analyzeError)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .onChange(of: carbohydrates) { _ in recomputeConsistencyAndBlinkIfFixed() }
        .onChange(of: protein) { _ in recomputeConsistencyAndBlinkIfFixed() }
        .onChange(of: fat) { _ in recomputeConsistencyAndBlinkIfFixed() }
    }

    private func personActionSheetButtons() -> [ActionSheet.Button] {
        var buttons: [ActionSheet.Button] = []
        // Only allow selection in eligible conditions
        let tier = Entitlements.tier(for: session)
        guard session.isLoggedIn && tier == .paid && !people.isEmpty else {
            buttons.append(.cancel())
            return buttons
        }
        for person in people {
            buttons.append(.default(Text(person.name)) {
                selectedPerson = person
            })
        }
        buttons.append(.cancel())
        return buttons
    }

    private func initializeSelectedPersonIfNeeded() {
        // Auto-select default person for Pro users when photos exist (to match accessory gating)
        let tier = Entitlements.tier(for: session)
        guard session.isLoggedIn && tier == .paid else { return }
        if selectedPerson == nil {
            if let def = people.first(where: { $0.isDefault }) {
                selectedPerson = def
            } else {
                selectedPerson = people.first
            }
        }
    }

    // MARK: - Save

    private func save() {
        // Only allow save if valid or forced by wizard
        guard isValid || forceEnableSave else { return }

        let m: Meal = meal ?? Meal(context: context)

        // Helper to regenerate a proper localized auto title with the in-app language
        func localizedAutoTitle(for date: Date) -> String {
            return Meal.autoTitle(for: date, languageCode: appLanguageCode)
        }

        // Normalize any legacy/bad placeholder titles that might be present in mealDescription
        func isBadPlaceholder(_ s: String) -> Bool {
            let trimmed = s.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed == "auto_title_meal - pattern" || trimmed == "auto_title_snack - pattern"
        }

        // If new, setup basic fields
        if meal == nil {
            m.id = UUID()
            m.date = Date()
            if mealDescription.isEmpty || isBadPlaceholder(mealDescription) {
                m.title = localizedAutoTitle(for: m.date)
            } else {
                m.title = mealDescription
            }
        } else {
            // Update title if user changed description; otherwise ensure we have a localized auto title
            if !mealDescription.isEmpty && !isBadPlaceholder(mealDescription) {
                m.title = mealDescription
            } else if m.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isBadPlaceholder(m.title) {
                m.title = localizedAutoTitle(for: m.date)
            }
        }

        // Helper parsers
        func d(_ s: String) -> Double { Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0 }
        func i(_ s: String) -> Double { Double(Int(s) ?? 0) }

        // Calories (stored as kcal)
        m.calories = Double(Int(calories) ?? 0)

        // Grams-based doubles
        m.carbohydrates = d(carbohydrates)
        m.protein = d(protein)
        m.fat = d(fat)

        // Sodium stored in mg
        if sodiumUnit == .grams {
            m.sodium = d(sodium) * 1000.0
        } else {
            m.sodium = i(sodium)
        }

        // Stimulants/Supplements
        m.alcohol = d(alcohol) // grams
        m.nicotine = i(nicotine) // mg
        m.theobromine = i(theobromine) // mg
        m.caffeine = i(caffeine) // mg
        m.taurine = i(taurine) // mg
        m.creatine = i(creatine) // mg [NEW]

        // Sub-macros (grams)
        m.starch = d(starch)
        m.sugars = d(sugars)
        m.fibre = d(fibre)

        // Fat breakdown (grams)
        m.monounsaturatedFat = d(monounsaturatedFat)
        m.polyunsaturatedFat = d(polyunsaturatedFat)
        m.saturatedFat = d(saturatedFat)
        m.transFat = d(transFat)
        m.omega3 = d(omega3)
        m.omega6 = d(omega6)

        // Protein breakdown (grams)
        m.animalProtein = d(animalProtein)
        m.plantProtein = d(plantProtein)
        m.proteinSupplements = d(proteinSupplements)
        // New: A2 beta-casein
        m.a2BetaCasein = d(a2BetaCasein)
        // Note: a1BetaCasein is collected in UI but not persisted; the Meal model has no a1BetaCasein attribute.

        // Vitamins/Minerals stored in mg; UI may be mg or µg
        // mg mode: parse Double; µg mode: parse Int then convert to mg
        func parseVitaminMineralToStorageMG(_ s: String) -> Double {
            switch vitaminsUnit {
            case .milligrams:
                let ui = Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
                return vitaminsUnit.toStorageMG(ui)
            case .micrograms:
                let uiInt = Double(Int(s) ?? 0)
                return vitaminsUnit.toStorageMG(uiInt)
            }
        }
        m.vitaminA = parseVitaminMineralToStorageMG(vitaminA)
        m.vitaminB = parseVitaminMineralToStorageMG(vitaminB)
        m.vitaminC = parseVitaminMineralToStorageMG(vitaminC)
        m.vitaminD = parseVitaminMineralToStorageMG(vitaminD)
        m.vitaminE = parseVitaminMineralToStorageMG(vitaminE)
        m.vitaminK = parseVitaminMineralToStorageMG(vitaminK)

        m.calcium = parseVitaminMineralToStorageMG(calcium)
        m.iron = parseVitaminMineralToStorageMG(iron)
        m.potassium = parseVitaminMineralToStorageMG(potassium)
        m.zinc = parseVitaminMineralToStorageMG(zinc)
        m.magnesium = parseVitaminMineralToStorageMG(magnesium)
        // New: Iodine (mg)
        m.iodine = parseVitaminMineralToStorageMG(iodine)
        // New: Phosphorus (mg)
        m.phosphorus = parseVitaminMineralToStorageMG(phosphorus)

        // Guess flags
        m.caloriesIsGuess = caloriesIsGuess
        m.carbohydratesIsGuess = carbohydratesIsGuess
        m.proteinIsGuess = proteinIsGuess
        m.sodiumIsGuess = sodiumIsGuess
        m.fatIsGuess = fatIsGuess

        m.alcoholIsGuess = alcoholIsGuess
        m.nicotineIsGuess = nicotineIsGuess
        m.theobromineIsGuess = theobromineIsGuess
        m.caffeineIsGuess = caffeineIsGuess
        m.taurineIsGuess = taurineIsGuess
        m.creatineIsGuess = creatineIsGuess // [NEW]

        m.starchIsGuess = starchIsGuess
        m.sugarsIsGuess = sugarsIsGuess
        m.fibreIsGuess = fibreIsGuess

        m.monounsaturatedFatIsGuess = monounsaturatedFatIsGuess
        m.polyunsaturatedFatIsGuess = polyunsaturatedFatIsGuess
        m.saturatedFatIsGuess = saturatedFatIsGuess
        m.transFatIsGuess = transFatIsGuess
        m.omega3IsGuess = omega3IsGuess
        m.omega6IsGuess = omega6IsGuess

        m.animalProteinIsGuess = animalProteinIsGuess
        m.plantProteinIsGuess = plantProteinIsGuess
        m.proteinSupplementsIsGuess = proteinSupplementsIsGuess
        // New: A2 beta-casein flag
        m.a2BetaCaseinIsGuess = a2BetaCaseinIsGuess
        // Note: a1BetaCaseinIsGuess is collected in UI but not persisted; the Meal model has no a1BetaCaseinIsGuess attribute.

        m.vitaminAIsGuess = vitaminAIsGuess
        m.vitaminBIsGuess = vitaminBIsGuess
        m.vitaminCIsGuess = vitaminCIsGuess
        m.vitaminDIsGuess = vitaminDIsGuess
        m.vitaminEIsGuess = vitaminEIsGuess
        m.vitaminKIsGuess = vitaminKIsGuess

        m.calciumIsGuess = calciumIsGuess
        m.ironIsGuess = ironIsGuess
        m.potassiumIsGuess = potassiumIsGuess
        m.zincIsGuess = zincIsGuess
        m.magnesiumIsGuess = magnesiumIsGuess
        // New: Iodine flag
        m.iodineIsGuess = iodineIsGuess
        // New: Phosphorus flag
        m.phosphorusIsGuess = phosphorusIsGuess

        // Associate person if eligible and selected (model shows Person.meal to-many without inverse)
        if let person = selectedPerson {
            person.addToMeal(m)
        }

        do {
            try context.save()
            // Keep reference if it was new
            if meal == nil { meal = m }
            dismiss()
        } catch {
            #if DEBUG
            print("Failed to save meal: \(error)")
            #endif
        }
    }

    // ... rest of file remains unchanged ...
}

// MARK: - Numeric input sanitizers used by MetricField bindings

private extension MealFormView {
    // Allow only digits and a single decimal separator.
    // Normalize comma to dot and collapse multiple dots to one.
    func numericBindingDecimal(_ source: Binding<String>) -> Binding<String> {
        Binding<String>(
            get: {
                source.wrappedValue
            },
            set: { newValue in
                var s = newValue

                // Normalize comma to dot
                s = s.replacingOccurrences(of: ",", with: ".")

                // Keep digits and dots only
                s = s.filter { ("0"..."9").contains($0) || $0 == "." }

                // Collapse multiple dots to a single one (keep first)
                if let firstDot = s.firstIndex(of: ".") {
                    let after = s.index(after: firstDot)
                    let tail = s[after...].replacingOccurrences(of: ".", with: "")
                    s = String(s[..<after]) + tail
                }

                // Optional: prevent leading zeros like "00" (keep "0." cases intact)
                if s.hasPrefix("00") {
                    // reduce to single leading zero
                    while s.hasPrefix("00") { s.removeFirst() }
                    if s.isEmpty { s = "0" }
                }

                source.wrappedValue = s
            }
        )
    }

    // Allow only digits (non-negative integers).
    func numericBindingInt(_ source: Binding<String>) -> Binding<String> {
        Binding<String>(
            get: {
                source.wrappedValue
            },
            set: { newValue in
                let filtered = newValue.filter { ("0"..."9").contains($0) }
                source.wrappedValue = filtered
            }
        )
    }
}

// MARK: - Subtotal helpers and focus handling (fix missing functions)

private extension MealFormView {
    func parseDoubleSafe(_ s: String) -> Double {
        Double(s.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    func formatGrams(_ value: Double) -> String {
        if value.isNaN || value.isInfinite { return "0" }
        let v = (value * 100).rounded() / 100 // 2dp
        let rounded = v.rounded()
        if abs(v - rounded) < 0.0001 {
            return String(Int(rounded))
        } else {
            var s = String(format: "%.2f", v)
            while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) {
                if s.hasSuffix("0") { s.removeLast() }
                if s.hasSuffix(".") { s.removeLast(); break }
            }
            return s
        }
    }

    func sumCarbSubs() -> Double {
        parseDoubleSafe(sugars) + parseDoubleSafe(starch) + parseDoubleSafe(fibre)
    }

    func sumProteinSubs() -> Double {
        // Include A1 and A2 to align with mismatch logic in DomainLogic
        parseDoubleSafe(animalProtein) + parseDoubleSafe(plantProtein) + parseDoubleSafe(proteinSupplements) + parseDoubleSafe(a2BetaCasein) + parseDoubleSafe(a1BetaCasein)
    }

    func sumFatSubs() -> Double {
        parseDoubleSafe(monounsaturatedFat) + parseDoubleSafe(polyunsaturatedFat) + parseDoubleSafe(saturatedFat) + parseDoubleSafe(transFat)
    }

    // Auto-fill top-level only if user hasn’t overridden since our last auto
    func shouldAutoFillTop(currentTop: String, lastAuto: Int?) -> Bool {
        if currentTop.isEmpty && lastAuto == nil { return true }
        if let lastAuto {
            let currentVal = parseDoubleSafe(currentTop)
            if abs(currentVal - Double(lastAuto)) < 0.001 { return true }
        }
        return false
    }

    func handleTopFromCarbSubs() {
        let sum = sumCarbSubs()
        if shouldAutoFillTop(currentTop: carbohydrates, lastAuto: carbsLastAutoSum) {
            carbohydrates = formatGrams(sum)
            carbsLastAutoSum = Int(sum.rounded())
        }
    }

    func handleTopFromProteinSubs() {
        let sum = sumProteinSubs()
        if shouldAutoFillTop(currentTop: protein, lastAuto: proteinLastAutoSum) {
            protein = formatGrams(sum)
            proteinLastAutoSum = Int(sum.rounded())
        }
    }

    func handleTopFromFatSubs() {
        let sum = sumFatSubs()
        if shouldAutoFillTop(currentTop: fat, lastAuto: fatLastAutoSum) {
            fat = formatGrams(sum)
            fatLastAutoSum = Int(sum.rounded())
        }
    }

    func handleHelperOnTopChangeForCarbs() {
        let sum = sumCarbSubs()
        carbsHelperText = formatGrams(sum)
        carbsHelperVisible = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            carbsHelperVisible = false
        }
    }

    func handleHelperOnTopChangeForProtein() {
        let sum = sumProteinSubs()
        proteinHelperText = formatGrams(sum)
        proteinHelperVisible = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            proteinHelperVisible = false
        }
    }

    func handleHelperOnTopChangeForFat() {
        let sum = sumFatSubs()
        fatHelperText = formatGrams(sum)
        fatHelperVisible = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            fatHelperVisible = false
        }
    }

    func handleFocusLeaveIfNeeded(leaving: FocusedField) {
        switch leaving {
        case .carbsTotal:
            handleHelperOnTopChangeForCarbs()
            if carbohydrates.isEmpty && sumCarbSubs() > 0 {
                triggerRedBlink(for: .carbsTotal)
            }
        case .proteinTotal:
            handleHelperOnTopChangeForProtein()
            if protein.isEmpty && sumProteinSubs() > 0 {
                triggerRedBlink(for: .proteinTotal)
            }
        case .fatTotal:
            handleHelperOnTopChangeForFat()
            if fat.isEmpty && sumFatSubs() > 0 {
                triggerRedBlink(for: .fatTotal)
            }
        default:
            break
        }
        // Let consistency logic in DomainLogic react
        recomputeConsistencyAndBlinkIfFixed()
    }

    func triggerRedBlink(for field: FocusedField) {
        switch field {
        case .carbsTotal:
            carbsRedBlink = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                carbsRedBlink = false
            }
        case .proteinTotal:
            proteinRedBlink = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                proteinRedBlink = false
            }
        case .fatTotal:
            fatRedBlink = true
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 600_000_000)
                fatRedBlink = false
            }
        default:
            break
        }
    }
}

extension MealFormView {
    // MARK: - Validation

    var isValid: Bool {
        guard let cal = Int(calories), cal > 0 else { return false }

        func isEmptyOrPositiveDouble(_ s: String) -> Bool {
            guard !s.isEmpty else { return true }
            let v = Double(s.replacingOccurrences(of: ",", with: ".")) ?? -1
            return v > 0
        }
        func isEmptyOrPositiveInt(_ s: String) -> Bool {
            guard !s.isEmpty else { return true }
            return (Int(s) ?? -1) > 0
        }

        // grams-based
        let gramsFields = [carbohydrates, protein, fat, sugars, starch, fibre, monounsaturatedFat, polyunsaturatedFat, saturatedFat, transFat, omega3, omega6, alcohol, animalProtein, plantProtein, proteinSupplements, a2BetaCasein, a1BetaCasein]
        guard gramsFields.allSatisfy(isEmptyOrPositiveDouble) else { return false }

        // sodium depends on unit
        if sodiumUnit == .grams {
            guard isEmptyOrPositiveDouble(sodium) else { return false }
        } else {
            guard isEmptyOrPositiveInt(sodium) else { return false }
        }

        // Stimulants (mg-only, integer UI) — creatine removed here
        let stimulantsIntFields = [nicotine, theobromine, caffeine, taurine]
        guard stimulantsIntFields.allSatisfy(isEmptyOrPositiveInt) else { return false }

        // Creatine (mg-only, integer UI)
        guard isEmptyOrPositiveInt(creatine) else { return false }

        // Vitamins/minerals validation depends on vitaminsUnit
        if vitaminsUnit == .milligrams {
            // allow decimals in mg mode
            let vitaminMineralDoubleFields = [vitaminA, vitaminB, vitaminC, vitaminD, vitaminE, vitaminK, calcium, iron, potassium, zinc, magnesium, iodine, phosphorus]
            guard vitaminMineralDoubleFields.allSatisfy(isEmptyOrPositiveDouble) else { return false }
        } else {
            // µg mode: integers only
            let vitaminMineralIntFields = [vitaminA, vitaminB, vitaminC, vitaminD, vitaminE, vitaminK, calcium, iron, potassium, zinc, magnesium, iodine, phosphorus]
            guard vitaminMineralIntFields.allSatisfy(isEmptyOrPositiveInt) else { return false }
        }

        return true
    }
}

