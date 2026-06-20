//
//  MealFormComponents.swift
//  MealTracker
//
//  Created by Simon Lee on 17/11/2025.
//

import SwiftUI
import UIKit
import Foundation
import CoreData

// MARK: - Gallery models and views

enum GalleryItem: Identifiable, Equatable {
    case persistent(photo: MealPhoto, url: URL, version: String)
    case inMemory(id: UUID, image: UIImage, data: Data, devIndex: Int, version: String)

    var id: String {
        switch self {
        case .persistent(let p, _, let version):
            return p.objectID.uriRepresentation().absoluteString + "#\(version)"
        case .inMemory(let id, _, _, let idx, let version):
            return id.uuidString + "_\(idx)#\(version)"
        }
    }

    var thumbnailImage: UIImage? {
        switch self {
        case .persistent(_, let url, _):
            if let data = try? Data(contentsOf: url) {
                return UIImage(data: data)
            }
            return nil
        case .inMemory(_, let img, _, _, _):
            return img
        }
    }
}

struct GalleryHeader: View {
    let items: [GalleryItem]
    @Binding var selectedIndex: Int
    @Binding var isExpanded: Bool
    let fullHeight: CGFloat
    let collapsedHeight: CGFloat
    let isBusy: Bool
    let onAnalyzeTap: () -> Void
    let onCameraTap: () -> Void
    let onPhotosTap: () -> Void

    // New: undo support
    var isUndoAvailable: Bool = false
    var onUndoTap: (() -> Void)? = nil

    // New: optional trailing accessory button (e.g., person selector) to render next to the wand
    var trailingAccessoryButton: AnyView? = nil

    // New: gate AI controls (wizard/undo) behind settings
    var aiEnabled: Bool = false

    // New: short status overlay at top-left
    var statusText: String? = nil
    var statusIsError: Bool = false

    // Thumbnail sizing and spacing (10% smaller than 64; tighter spacing)
    private let thumbSize: CGFloat = 58
    private let thumbSpacing: CGFloat = 6
    private let horizontalPadding: CGFloat = 8
    private let bottomPadding: CGFloat = 2

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                ZStack(alignment: .topLeading) {
                    if items.isEmpty {
                        HeaderImageView(image: nil)
                            .frame(maxWidth: .infinity)
                            .frame(height: isExpanded ? fullHeight : collapsedHeight)
                            .clipped()
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                    isExpanded.toggle()
                                }
                            }
                    } else {
                        TabView(selection: $selectedIndex) {
                            ForEach(items.indices, id: \.self) { idx in
                                let image = items[idx].thumbnailImage
                                HeaderImageView(image: image)
                                    .tag(idx)
                            }
                        }
                        .tabViewStyle(.page(indexDisplayMode: .automatic))
                        .frame(maxWidth: .infinity)
                        .frame(height: isExpanded ? fullHeight : collapsedHeight)
                        .clipped()
                        .contentShape(Rectangle())
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                                isExpanded.toggle()
                            }
                        }
                    }

                    // Top-left status overlay
                    if aiEnabled, let text = statusText, !text.isEmpty {
                        Text(text)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .foregroundStyle(statusIsError ? Color.white : Color.primary)
                            .background(
                                Capsule()
                                    .fill(statusIsError ? Color.red.opacity(0.85) : Color(.systemBackground).opacity(0.7))
                            )
                            .padding(10)
                            .accessibilityLabel(text)
                    }
                }

                HStack(spacing: 10) {
                    CameraButton { onCameraTap() }
                    PhotosButton { onPhotosTap() }
                    if !items.isEmpty, aiEnabled {
                        AnalyzeButton(
                            isBusy: isBusy,
                            isUndoAvailable: isUndoAvailable,
                            action: {
                                if isUndoAvailable {
                                    onUndoTap?()
                                } else {
                                    onAnalyzeTap()
                                }
                            }
                        )
                        if let trailing = trailingAccessoryButton {
                            trailing
                        }
                    }
                }
                .padding(12)
            }

            if !items.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: thumbSpacing) {
                        ForEach(items.indices, id: \.self) { idx in
                            let img = items[idx].thumbnailImage
                            ZStack {
                                if let ui = img {
                                    Image(uiImage: ui)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: thumbSize, height: thumbSize)
                                        .clipped()
                                        .cornerRadius(6)
                                } else {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.1))
                                        .frame(width: thumbSize, height: thumbSize)
                                        .cornerRadius(6)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .foregroundStyle(.secondary)
                                        )
                                }
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(selectedIndex == idx ? Color.accentColor : Color.clear, lineWidth: 2)
                            }
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedIndex = idx
                                }
                            }
                        }
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.bottom, bottomPadding)
                }
            }
        }
    }
}

struct HeaderImageView: View {
    let image: UIImage?

    var body: some View {
        Group {
            if let ui = image {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .background(Color.black.opacity(0.05))
                    .accessibilityLabel(Text(LocalizedStringKey("a11y_meal_photo")))
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.secondary.opacity(0.08))
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .accessibilityLabel(Text(LocalizedStringKey("a11y_no_photo")))
            }
        }
        .contentShape(Rectangle())
    }
}

struct AnalyzeButton: View {
    let isBusy: Bool
    // New: controls mirrored “undo” state
    let isUndoAvailable: Bool
    let action: () -> Void

    @State private var rotation: Angle = .degrees(0)

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 44, height: 44)

                // Wand icon, mirrored when undo is available
                let wand = Image(systemName: "wand.and.stars")
                    .foregroundColor(.white)
                    .imageScale(.medium)

                if isBusy {
                    wand
                        .rotationEffect(rotation)
                        .scaleEffect(x: isUndoAvailable ? -1 : 1, y: 1) // mirror horizontally in undo mode
                        .animation(isBusy ? .linear(duration: 1.0).repeatForever(autoreverses: false) : .default, value: rotation)
                        .onAppear { rotation = .degrees(360) }
                        .onChange(of: isBusy) { busy in
                            if busy { rotation = .degrees(360) } else { rotation = .degrees(0) }
                        }
                } else {
                    wand
                        .rotationEffect(.degrees(0))
                        .scaleEffect(x: isUndoAvailable ? -1 : 1, y: 1) // mirror horizontally in undo mode
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey(isUndoAvailable ? "a11y_undo_ai_changes" : (isBusy ? "a11y_analyzing_photo" : "a11y_analyze_photo"))))
    }
}

struct CameraButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 44, height: 44)
                Image(systemName: "camera")
                    .foregroundColor(.white)
                    .imageScale(.medium)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey("a11y_capture_photo")))
    }
}

struct PhotosButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 44, height: 44)
                Image(systemName: "photo.on.rectangle")
                    .foregroundColor(.white)
                    .imageScale(.medium)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(LocalizedStringKey("a11y_choose_from_photos")))
    }
}

// New: compact circular person button styled to match other header controls
struct PersonPickerButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: 44, height: 44)
                Image(systemName: "person.crop.circle")
                    .foregroundColor(.white)
                    .imageScale(.medium)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

// MARK: - Supporting views and helpers

struct CompactChevronToggle: View {
    @Binding var isExpanded: Bool
    let labelCollapsed: String
    let labelExpanded: String

    var body: some View {
        Button(action: { isExpanded.toggle() }) {
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                .font(.caption)
                .imageScale(.small)
                .foregroundColor(.accentColor)
                .frame(width: 20, height: 20, alignment: .center)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isExpanded ? labelExpanded : labelCollapsed)
    }
}

enum ValidationSeverity {
    case none
    case unusual
    case stupid
}

struct ValidationThresholds {
    static let calories = ValidationThresholds(unusual: 3000, stupid: 10000)
    static let grams = ValidationThresholds(unusual: 300, stupid: 2000)
    static let sodiumMg = ValidationThresholds(unusual: 5000, stupid: 20000)
    static let sodiumG = ValidationThresholds(unusual: 5, stupid: 20)
    static let vitaminMineralMg = ValidationThresholds(unusual: 500, stupid: 2000)
    static let mineralMg = ValidationThresholds(unusual: 1000, stupid: 5000)

    let unusual: Int
    let stupid: Int

    func severity(for value: Int) -> ValidationSeverity {
        if value >= stupid { return .stupid }
        if value >= unusual { return .unusual }
        return .none
    }

    // New: Double-based severity helper (for grams with decimals)
    func severityDouble(_ value: Double) -> ValidationSeverity {
        let unusualD = Double(unusual)
        let stupidD = Double(stupid)
        if value >= stupidD { return .stupid }
        if value >= unusualD { return .unusual }
        return .none
    }
}

struct ToggleDetailsButton: View {
    @Binding var isExpanded: Bool
    let titleCollapsed: String
    let titleExpanded: String

    var body: some View {
        HStack {
            Spacer()
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 6) {
                    Text(isExpanded ? titleExpanded : titleCollapsed)
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                    Image(systemName: (isExpanded ? "chevron.up" : "chevron.down"))
                        .font(.footnote)
                        .foregroundColor(.accentColor)
                        .imageScale(.small)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? titleExpanded : titleCollapsed)
        }
    }
}

enum FieldHighlight {
    case none
    case error
    case successBlink(active: Bool)
}

struct MetricField: View {
    let titleKey: String
    @Binding var text: String
    @Binding var isGuess: Bool
    var keyboard: UIKeyboardType = .numberPad
    let manager: LocalizationManager
    var unitSuffix: String? = nil
    var isPrelocalizedTitle: Bool = false

    // Validators: support both Int (mg/µg) and Double (grams)
    var intValidator: ((Int) -> ValidationSeverity)? = nil
    var doubleValidator: ((Double) -> ValidationSeverity)? = nil

    var leadingAccessory: (() -> AnyView)? = nil
    var trailingAccessory: (() -> AnyView)? = nil

    var highlight: FieldHighlight = .none

    var focusedField: FocusState<MealFormView.FocusedField?>.Binding? = nil
    var thisField: MealFormView.FocusedField? = nil
    var onSubmit: (() -> Void)? = nil

    @AppStorage("handedness") private var handedness: Handedness = .right

    init(
        titleKey: String,
        text: Binding<String>,
        isGuess: Binding<Bool>,
        keyboard: UIKeyboardType = .numberPad,
        manager: LocalizationManager,
        unitSuffix: String? = nil,
        isPrelocalizedTitle: Bool = false,
        validator: ((Int) -> ValidationSeverity)? = nil,
        leadingAccessory: (() -> AnyView)? = nil,
        trailingAccessory: (() -> AnyView)? = nil,
        highlight: FieldHighlight = .none,
        focusedField: FocusState<MealFormView.FocusedField?>.Binding? = nil,
        thisField: MealFormView.FocusedField? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        self.titleKey = titleKey
        self._text = text
        self._isGuess = isGuess
        self.keyboard = keyboard
        self.manager = manager
        self.unitSuffix = unitSuffix
        self.isPrelocalizedTitle = isPrelocalizedTitle
        // Back-compat: if caller used old validator param, assign to intValidator
        self.intValidator = validator
        self.leadingAccessory = leadingAccessory
        self.trailingAccessory = trailingAccessory
        self.highlight = highlight
        self.focusedField = focusedField
        self.thisField = thisField
        self.onSubmit = onSubmit
    }

    // New convenience init for Double validator (grams)
    init(
        titleKey: String,
        text: Binding<String>,
        isGuess: Binding<Bool>,
        keyboard: UIKeyboardType = .decimalPad,
        manager: LocalizationManager,
        unitSuffix: String? = "g",
        doubleValidator: ((Double) -> ValidationSeverity)?,
        leadingAccessory: (() -> AnyView)? = nil,
        trailingAccessory: (() -> AnyView)? = nil,
        highlight: FieldHighlight = .none,
        focusedField: FocusState<MealFormView.FocusedField?>.Binding? = nil,
        thisField: MealFormView.FocusedField? = nil,
        onSubmit: (() -> Void)? = nil
    ) {
        self.titleKey = titleKey
        self._text = text
        self._isGuess = isGuess
        self.keyboard = keyboard
        self.manager = manager
        self.unitSuffix = unitSuffix
        self.isPrelocalizedTitle = false
        self.doubleValidator = doubleValidator
        self.leadingAccessory = leadingAccessory
        self.trailingAccessory = trailingAccessory
        self.highlight = highlight
        self.focusedField = focusedField
        self.thisField = thisField
        self.onSubmit = onSubmit
    }

    private var tintColor: Color { isGuess ? .orange : .green }

    private var displayTitle: String {
        if isPrelocalizedTitle { return titleKey }
        let localized = manager.localized(titleKey)
        let spaced = localized.replacingOccurrences(of: "_", with: " ")
        let words = spaced.split(separator: " ")
        let titled = words.map { word -> String in
            var s = String(word)
            if let first = s.first {
                let firstUpper = String(first).uppercased()
                s.replaceSubrange(s.startIndex...s.startIndex, with: firstUpper)
            }
            return s
        }.joined(separator: " ")
        return titled
    }

    private var parsedInt: Int? { Int(text) }
    private var parsedDouble: Double? { Double(text.replacingOccurrences(of: ",", with: ".")) }

    private var severity: ValidationSeverity {
        if let dv = doubleValidator, let v = parsedDouble {
            if v < 0 { return .stupid }
            return dv(v)
        }
        if let iv = intValidator, let v = parsedInt {
            if v < 0 { return .stupid }
            return iv(v)
        }
        return .none
    }

    private var underlineColor: Color {
        switch highlight {
        case .error: return .red
        case .successBlink(let active): return active ? .green : defaultUnderlineColor
        case .none: return defaultUnderlineColor
        }
    }

    private var defaultUnderlineColor: Color {
        switch severity {
        case .none: return .clear
        case .unusual: return .orange
        case .stupid: return .red
        }
    }

    private var underlineHeight: CGFloat {
        switch highlight {
        case .error: return 2
        case .successBlink(let active): return active ? 2 : defaultUnderlineHeight
        case .none: return defaultUnderlineHeight
        }
    }

    private var defaultUnderlineHeight: CGFloat {
        switch severity {
        case .none: return 1
        case .unusual: return 2
        case .stupid: return 2
        }
    }

    private func requestFocus() {
        if let focusedField, let thisField {
            focusedField.wrappedValue = thisField
        }
    }

    @ViewBuilder
    private func headerRow() -> some View {
        if handedness == .left {
            HStack(alignment: .firstTextBaseline) {
                Picker("", selection: $isGuess) {
                    Text(manager.localized("accurate")).tag(false)
                    Text(manager.localized("guess")).tag(true)
                }
                .font(.caption)
                .pickerStyle(.segmented)
                .tint(tintColor)
                .frame(maxWidth: 180)
                .accessibilityLabel(displayTitle + " " + manager.localized("accuracy"))
                .simultaneousGesture(TapGesture().onEnded { requestFocus() })

                Spacer(minLength: 8)

                Text(displayTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } else {
            HStack(alignment: .firstTextBaseline) {
                Text(displayTitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                Picker("", selection: $isGuess) {
                    Text(manager.localized("accurate")).tag(false)
                    Text(manager.localized("guess")).tag(true)
                }
                .font(.caption)
                .pickerStyle(.segmented)
                .tint(tintColor)
                .frame(maxWidth: 180)
                .accessibilityLabel(displayTitle + " " + manager.localized("accuracy"))
                .simultaneousGesture(TapGesture().onEnded { requestFocus() })
            }
        }
    }

    @ViewBuilder
    private func inputRow() -> some View {
        if handedness == .left {
            HStack(spacing: 6) {
                if let trailing = trailingAccessory {
                    trailing()
                }

                if let suffix = unitSuffix {
                    Text(suffix)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                TextField("", text: $text)
                    .keyboardType(keyboard)
                    .multilineTextAlignment(.leading)
                    .submitLabel(.done)
                    .onSubmit { onSubmit?() }
                    .applyFocus(focusedField: focusedField, thisField: thisField)

                if let accessory = leadingAccessory {
                    accessory()
                }
            }
        } else {
            HStack(spacing: 6) {
                if let accessory = leadingAccessory {
                    accessory()
                }

                TextField("", text: $text)
                    .keyboardType(keyboard)
                    .multilineTextAlignment(.leading)
                    .submitLabel(.done)
                    .onSubmit { onSubmit?() }
                    .applyFocus(focusedField: focusedField, thisField: thisField)

                if let suffix = unitSuffix {
                    Text(suffix)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let trailing = trailingAccessory {
                    trailing() // FIX: invoke the closure to produce a View
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerRow()

            VStack(spacing: 2) {
                inputRow()
                    .contentShape(Rectangle())
                    .onTapGesture { requestFocus() }

                Rectangle()
                    .fill(underlineColor)
                    .frame(height: underlineHeight)
                    .animation(.easeInOut(duration: 0.18), value: underlineColor)
                    .animation(.easeInOut(duration: 0.18), value: underlineHeight)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { requestFocus() }
        .padding(.vertical, 2)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(displayTitle)
    }
}

extension View {
    @ViewBuilder
    func applyFocus(focusedField: FocusState<MealFormView.FocusedField?>.Binding?, thisField: MealFormView.FocusedField?) -> some View {
        if let focusedField, let thisField {
            self.focused(focusedField, equals: thisField)
        } else {
            self
        }
    }
}

// Updated: VitaminsGroupView now switches input mode based on vitaminsUnit
struct VitaminsGroupView: View {
    let manager: LocalizationManager
    let unitSuffix: String
    let vitaminsUnit: VitaminsUnit

    @Binding var aText: String
    @Binding var aIsGuess: Bool
    @Binding var bText: String
    @Binding var bIsGuess: Bool
    @Binding var cText: String
    @Binding var cIsGuess: Bool
    @Binding var dText: String
    @Binding var dIsGuess: Bool
    @Binding var eText: String
    @Binding var eIsGuess: Bool
    @Binding var kText: String
    @Binding var kIsGuess: Bool

    // Focus
    var focusedField: FocusState<MealFormView.FocusedField?>.Binding? = nil

    var body: some View {
        VStack(spacing: 0) {
            if vitaminsUnit == .milligrams {
                MetricField(titleKey: "vitamin_a", text: $aText, isGuess: $aIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: unitSuffix, doubleValidator: { ValidationThresholds.vitaminMineralMg.severityDouble($0) }, focusedField: focusedField, thisField: .generic("vitaminA"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "vitamin_b", text: $bText, isGuess: $bIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: unitSuffix, doubleValidator: { ValidationThresholds.vitaminMineralMg.severityDouble($0) }, focusedField: focusedField, thisField: .generic("vitaminB"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "vitamin_c", text: $cText, isGuess: $cIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: unitSuffix, doubleValidator: { ValidationThresholds.vitaminMineralMg.severityDouble($0) }, focusedField: focusedField, thisField: .generic("vitaminC"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "vitamin_d", text: $dText, isGuess: $dIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: unitSuffix, doubleValidator: { ValidationThresholds.vitaminMineralMg.severityDouble($0) }, focusedField: focusedField, thisField: .generic("vitaminD"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "vitamin_e", text: $eText, isGuess: $eIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: unitSuffix, doubleValidator: { ValidationThresholds.vitaminMineralMg.severityDouble($0) }, focusedField: focusedField, thisField: .generic("vitaminE"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "vitamin_k", text: $kText, isGuess: $kIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: unitSuffix, doubleValidator: { ValidationThresholds.vitaminMineralMg.severityDouble($0) }, focusedField: focusedField, thisField: .generic("vitaminK"), onSubmit: { focusedField?.wrappedValue = nil })
            } else {
                MetricField(titleKey: "vitamin_a", text: $aText, isGuess: $aIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .micrograms) }, focusedField: focusedField, thisField: .generic("vitaminA"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "vitamin_b", text: $bText, isGuess: $bIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .micrograms) }, focusedField: focusedField, thisField: .generic("vitaminB"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "vitamin_c", text: $cText, isGuess: $cIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .micrograms) }, focusedField: focusedField, thisField: .generic("vitaminC"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "vitamin_d", text: $dText, isGuess: $dIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .micrograms) }, focusedField: focusedField, thisField: .generic("vitaminD"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "vitamin_e", text: $eText, isGuess: $eIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .micrograms) }, focusedField: focusedField, thisField: .generic("vitaminE"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "vitamin_k", text: $kText, isGuess: $kIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .micrograms) }, focusedField: focusedField, thisField: .generic("vitaminK"), onSubmit: { focusedField?.wrappedValue = nil })
            }
        }
    }
}

extension ValidationThresholds {
    func severityForVitaminsUI(_ uiValue: Int, unit: VitaminsUnit) -> ValidationSeverity {
        let mg: Int
        switch unit {
        case .milligrams: mg = uiValue
        case .micrograms: mg = Int(Double(uiValue) / 1000.0)
        }
        return severity(for: mg)
    }
}

// Updated: MineralsGroupView switches with vitaminsUnit too
struct MineralsGroupView: View {
    let manager: LocalizationManager
    let unitSuffix: String
    let vitaminsUnit: VitaminsUnit

    @Binding var calciumText: String
    @Binding var calciumIsGuess: Bool
    @Binding var ironText: String
    @Binding var ironIsGuess: Bool
    @Binding var potassiumText: String
    @Binding var potassiumIsGuess: Bool
    @Binding var zincText: String
    @Binding var zincIsGuess: Bool
    @Binding var magnesiumText: String
    @Binding var magnesiumIsGuess: Bool
    @Binding var phosphorusText: String
    @Binding var phosphorusIsGuess: Bool
    @Binding var iodineText: String
    @Binding var iodineIsGuess: Bool

    // Focus
    var focusedField: FocusState<MealFormView.FocusedField?>.Binding? = nil

    var body: some View {
        VStack(spacing: 0) {
            if vitaminsUnit == .milligrams {
                // mg mode: allow decimals
                MetricField(titleKey: "calcium", text: $calciumText, isGuess: $calciumIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: unitSuffix, doubleValidator: { ValidationThresholds.vitaminMineralMg.severityDouble($0) }, focusedField: focusedField, thisField: .generic("calcium"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "iron", text: $ironText, isGuess: $ironIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: unitSuffix, doubleValidator: { ValidationThresholds.vitaminMineralMg.severityDouble($0) }, focusedField: focusedField, thisField: .generic("iron"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "potassium", text: $potassiumText, isGuess: $potassiumIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: unitSuffix, doubleValidator: { ValidationThresholds.vitaminMineralMg.severityDouble($0) }, focusedField: focusedField, thisField: .generic("potassium"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "zinc", text: $zincText, isGuess: $zincIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: unitSuffix, doubleValidator: { ValidationThresholds.vitaminMineralMg.severityDouble($0) }, focusedField: focusedField, thisField: .generic("zinc"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "magnesium", text: $magnesiumText, isGuess: $magnesiumIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: unitSuffix, doubleValidator: { ValidationThresholds.vitaminMineralMg.severityDouble($0) }, focusedField: focusedField, thisField: .generic("magnesium"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "phosphorus", text: $phosphorusText, isGuess: $phosphorusIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: unitSuffix, doubleValidator: { ValidationThresholds.vitaminMineralMg.severityDouble($0) }, focusedField: focusedField, thisField: .generic("phosphorus"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "iodine", text: $iodineText, isGuess: $iodineIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: unitSuffix, doubleValidator: { ValidationThresholds.vitaminMineralMg.severityDouble($0) }, focusedField: focusedField, thisField: .generic("iodine"), onSubmit: { focusedField?.wrappedValue = nil })
            } else {
                // µg mode: integers
                MetricField(titleKey: "calcium", text: $calciumText, isGuess: $calciumIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .micrograms) }, focusedField: focusedField, thisField: .generic("calcium"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "iron", text: $ironText, isGuess: $ironIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .micrograms) }, focusedField: focusedField, thisField: .generic("iron"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "potassium", text: $potassiumText, isGuess: $potassiumIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .micrograms) }, focusedField: focusedField, thisField: .generic("potassium"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "zinc", text: $zincText, isGuess: $zincIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .micrograms) }, focusedField: focusedField, thisField: .generic("zinc"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "magnesium", text: $magnesiumText, isGuess: $magnesiumIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .micrograms) }, focusedField: focusedField, thisField: .generic("magnesium"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "phosphorus", text: $phosphorusText, isGuess: $phosphorusIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .micrograms) }, focusedField: focusedField, thisField: .generic("phosphorus"), onSubmit: { focusedField?.wrappedValue = nil })
                MetricField(titleKey: "iodine", text: $iodineText, isGuess: $iodineIsGuess, keyboard: .numberPad, manager: manager, unitSuffix: unitSuffix, validator: { ValidationThresholds.vitaminMineralMg.severityForVitaminsUI($0, unit: .micrograms) }, focusedField: focusedField, thisField: .generic("iodine"), onSubmit: { focusedField?.wrappedValue = nil })
            }
        }
    }
}

struct CarbsSubFields: View {
    let manager: LocalizationManager
    @Binding var sugarsText: String
    @Binding var sugarsIsGuess: Bool
    @Binding var starchText: String
    @Binding var starchIsGuess: Bool
    @Binding var fibreText: String
    @Binding var fibreIsGuess: Bool

    // Focus
    var focusedField: FocusState<MealFormView.FocusedField?>.Binding? = nil

    var body: some View {
        VStack(spacing: 0) {
            MetricField(
                titleKey: "sugars",
                text: $sugarsText,
                isGuess: $sugarsIsGuess,
                keyboard: .decimalPad,
                manager: manager,
                unitSuffix: manager.localized("unit_g_suffix"),
                doubleValidator: { ValidationThresholds.grams.severityDouble($0) },
                focusedField: focusedField,
                thisField: .generic("sugars"),
                onSubmit: { focusedField?.wrappedValue = nil }
            )
            MetricField(
                titleKey: "starch",
                text: $starchText,
                isGuess: $starchIsGuess,
                keyboard: .decimalPad,
                manager: manager,
                unitSuffix: manager.localized("unit_g_suffix"),
                doubleValidator: { ValidationThresholds.grams.severityDouble($0) },
                focusedField: focusedField,
                thisField: .generic("starch"),
                onSubmit: { focusedField?.wrappedValue = nil }
            )
            MetricField(
                titleKey: "fibre",
                text: $fibreText,
                isGuess: $fibreIsGuess,
                keyboard: .decimalPad,
                manager: manager,
                unitSuffix: manager.localized("unit_g_suffix"),
                doubleValidator: { ValidationThresholds.grams.severityDouble($0) },
                focusedField: focusedField,
                thisField: .generic("fibre"),
                onSubmit: { focusedField?.wrappedValue = nil }
            )
        }
    }
}

struct ProteinSubFields: View {
    let manager: LocalizationManager
    @Binding var animalText: String
    @Binding var animalIsGuess: Bool
    @Binding var plantText: String
    @Binding var plantIsGuess: Bool
    @Binding var supplementsText: String
    @Binding var supplementsIsGuess: Bool
    // New: A2 beta-casein
    @Binding var a2Text: String
    @Binding var a2IsGuess: Bool
    // New: A1 beta-casein
    @Binding var a1Text: String
    @Binding var a1IsGuess: Bool

    // Focus
    var focusedField: FocusState<MealFormView.FocusedField?>.Binding? = nil

    var body: some View {
        VStack(spacing: 0) {
            MetricField(titleKey: "animal_protein", text: $animalText, isGuess: $animalIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: manager.localized("unit_g_suffix"), doubleValidator: { ValidationThresholds.grams.severityDouble($0) }, focusedField: focusedField, thisField: .generic("animalProtein"), onSubmit: { focusedField?.wrappedValue = nil })
            MetricField(titleKey: "plant_protein", text: $plantText, isGuess: $plantIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: manager.localized("unit_g_suffix"), doubleValidator: { ValidationThresholds.grams.severityDouble($0) }, focusedField: focusedField, thisField: .generic("plantProtein"), onSubmit: { focusedField?.wrappedValue = nil })
            MetricField(titleKey: "protein_supplements", text: $supplementsText, isGuess: $supplementsIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: manager.localized("unit_g_suffix"), doubleValidator: { ValidationThresholds.grams.severityDouble($0) }, focusedField: focusedField, thisField: .generic("proteinSupplements"), onSubmit: { focusedField?.wrappedValue = nil })
            // New A2 beta-casein (grams)
            MetricField(titleKey: "a2_beta_casein", text: $a2Text, isGuess: $a2IsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: manager.localized("unit_g_suffix"), doubleValidator: { ValidationThresholds.grams.severityDouble($0) }, focusedField: focusedField, thisField: .generic("a2BetaCasein"), onSubmit: { focusedField?.wrappedValue = nil })
            // New A1 beta-casein (grams)
            MetricField(titleKey: "a1_beta_casein", text: $a1Text, isGuess: $a1IsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: manager.localized("unit_g_suffix"), doubleValidator: { ValidationThresholds.grams.severityDouble($0) }, focusedField: focusedField, thisField: .generic("a1BetaCasein"), onSubmit: { focusedField?.wrappedValue = nil })
        }
    }
}

struct FatSubFields: View {
    let manager: LocalizationManager
    @Binding var monoText: String
    @Binding var monoIsGuess: Bool
    @Binding var polyText: String
    @Binding var polyIsGuess: Bool
    @Binding var satText: String
    @Binding var satIsGuess: Bool
    @Binding var transText: String
    @Binding var transIsGuess: Bool
    // New: Omega-3
    @Binding var omega3Text: String
    @Binding var omega3IsGuess: Bool
    // New: Omega-6
    @Binding var omega6Text: String
    @Binding var omega6IsGuess: Bool

    // Focus from parent
    var focusedField: FocusState<MealFormView.FocusedField?>.Binding? = nil

    var body: some View {
        VStack(spacing: 0) {
            MetricField(titleKey: "monounsaturated_fat", text: $monoText, isGuess: $monoIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: manager.localized("unit_g_suffix"), doubleValidator: { ValidationThresholds.grams.severityDouble($0) }, focusedField: focusedField, thisField: .generic("monounsaturatedFat"), onSubmit: { focusedField?.wrappedValue = nil })
            MetricField(titleKey: "polyunsaturated_fat", text: $polyText, isGuess: $polyIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: manager.localized("unit_g_suffix"), doubleValidator: { ValidationThresholds.grams.severityDouble($0) }, focusedField: focusedField, thisField: .generic("polyunsaturatedFat"), onSubmit: { focusedField?.wrappedValue = nil })
            MetricField(titleKey: "saturated_fat", text: $satText, isGuess: $satIsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: manager.localized("unit_g_suffix"), doubleValidator: { ValidationThresholds.grams.severityDouble($0) }, focusedField: focusedField, thisField: .generic("saturatedFat"), onSubmit: { focusedField?.wrappedValue = nil })
            MetricField(
                titleKey: "trans_fat",
                text: $transText,
                isGuess: $transIsGuess,
                keyboard: .decimalPad,
                manager: manager,
                unitSuffix: manager.localized("unit_g_suffix"),
                doubleValidator: { ValidationThresholds.grams.severityDouble($0) },
                focusedField: focusedField,
                thisField: .generic("transFat"),
                onSubmit: { focusedField?.wrappedValue = nil }
            )
            // Omega-3 (grams)
            MetricField(titleKey: "omega3", text: $omega3Text, isGuess: $omega3IsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: manager.localized("unit_g_suffix"), doubleValidator: { ValidationThresholds.grams.severityDouble($0) }, focusedField: focusedField, thisField: .generic("omega3"), onSubmit: { focusedField?.wrappedValue = nil })
            // Omega-6 (grams)
            MetricField(titleKey: "omega6", text: $omega6Text, isGuess: $omega6IsGuess, keyboard: .decimalPad, manager: manager, unitSuffix: manager.localized("unit_g_suffix"), doubleValidator: { ValidationThresholds.grams.severityDouble($0) }, focusedField: focusedField, thisField: .generic("omega6"), onSubmit: { focusedField?.wrappedValue = nil })
        }
    }
}

extension Double {
    var cleanString: String {
        truncatingRemainder(dividingBy: 1) == 0 ? String(Int(self)) : String(self)
    }

    func rounded(toPlaces places: Int) -> Double {
        guard places >= 0 else { return self }
        let factor = pow(10.0, Double(places))
        return (self * factor).rounded() / factor
    }
}

struct CompactSectionSpacing: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .listSectionSpacing(.compact)
        } else {
            content
        }
    }
}

