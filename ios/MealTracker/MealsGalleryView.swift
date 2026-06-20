//
//  MealsGalleryView.swift
//  MealTracker
//
//  Created by Simon Lee on 25/11/2025.
//

import SwiftUI
import CoreData
import UIKit

struct MealsGalleryView: View {
    @Environment(\.managedObjectContext) private var context

    @FetchRequest(
        fetchRequest: Meal.fetchAllMealsRequest()
    ) private var meals: FetchedResults<Meal>

    // Layout constants
    private let outerHorizontalPadding: CGFloat = 16   // outer gutter on both sides
    private let interItemSpacing: CGFloat = 12         // spacing between the two columns and between rows
    private let tileInnerHorizontalPadding: CGFloat = 4 // subtle inner padding inside each tile

    // Two equal columns (we’ll still compute exact column width via GeometryReader)
    private var columns: [GridItem] {
        [
            GridItem(.flexible(), spacing: interItemSpacing, alignment: .top),
            GridItem(.flexible(), spacing: interItemSpacing, alignment: .top)
        ]
    }

    @State private var showingAdd = false
    @State private var showingWeeklyReport = false

    var body: some View {
        Group {
            if meals.isEmpty {
                EmptyStateView(onAdd: { showingAdd = true })
                    .padding()
            } else {
                GeometryReader { proxy in
                    // Compute the exact width each column gets
                    let totalWidth = proxy.size.width
                    let available = totalWidth - (outerHorizontalPadding * 2) - interItemSpacing
                    let columnWidth = max(0, available / 2)

                    ScrollView {
                        LazyVGrid(columns: columns, alignment: .center, spacing: interItemSpacing) {
                            // Filter out deleted objects to avoid rendering after deletion
                            ForEach(meals.filter { !$0.isDeleted }, id: \.objectID) { meal in
                                NavigationLink(destination: MealFormView(meal: meal)) {
                                    MealTile(meal: meal, fixedWidth: columnWidth)
                                        .padding(.horizontal, tileInnerHorizontalPadding)
                                        .frame(width: columnWidth) // hard cap to half the screen minus gutters/spacing
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, outerHorizontalPadding) // equal gutters on both sides
                        .padding(.vertical, 12)
                    }
                }
                .background(Color(.systemBackground))
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Weekly report button on the left
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    showingWeeklyReport = true
                } label: {
                    Image(systemName: "chart.bar.doc.horizontal")
                }
                .accessibilityLabel(Text(LocalizedStringKey("weekly_report")))
            }
            // Add button on the right
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAdd = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel(Text(LocalizedStringKey("add_meal")))
            }
        }
        .sheet(isPresented: $showingAdd) {
            NavigationView {
                MealFormView()
            }
        }
        .sheet(isPresented: $showingWeeklyReport) {
            NavigationView {
                WeeklyReportView()
                    .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

// MARK: - Minimal supporting views to fix missing symbols

private struct EmptyStateView: View {
    var onAdd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "photo.on.rectangle")
                .font(.system(size: 48, weight: .regular))
                .foregroundStyle(.secondary)

            Text(LocalizedStringKey("no_meals_yet"))
                .font(.title3)
                .fontWeight(.semibold)

            Text(LocalizedStringKey("add_first_meal_message"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                onAdd()
            } label: {
                Label(LocalizedStringKey("add_meal"), systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.secondary.opacity(0.08))
        )
    }
}

private struct MealTile: View {
    // Observe changes to the managed object so the tile re-renders when edited
    @ObservedObject var meal: Meal
    let fixedWidth: CGFloat

    // Respect user energy unit setting for display
    @AppStorage("energyUnit") private var energyUnit: EnergyUnit = .calories
    // Use in-app language override for title regeneration
    @AppStorage("appLanguageCode") private var appLanguageCode: String = LocalizationManager.defaultLanguageCode

    // Sorted photos: earliest first (to match "first picture as hero image")
    private var sortedPhotos: [MealPhoto] {
        guard let set = meal.value(forKey: "photos") as? Set<MealPhoto>, !set.isEmpty else {
            return []
        }
        return set.sorted { (a, b) in
            let da = a.createdAt ?? .distantPast
            let db = b.createdAt ?? .distantPast
            return da < db
        }
    }

    private var heroPhoto: MealPhoto? { sortedPhotos.first }

    private var thumbnailPhotos: [MealPhoto] {
        guard sortedPhotos.count > 1 else { return [] }
        return Array(sortedPhotos.dropFirst())
    }

    // Load a UIImage for a MealPhoto using upload URL first, then original
    private func loadImage(for photo: MealPhoto) -> UIImage? {
        if let url = PhotoService.urlForUpload(photo),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            return img
        }
        if let url = PhotoService.urlForOriginal(photo),
           let data = try? Data(contentsOf: url),
           let img = UIImage(data: data) {
            return img
        }
        return nil
    }

    // Localization manager for short labels (falls back to keys if not present)
    private var localizationManager: LocalizationManager {
        LocalizationManager(languageCode: LocalizationManager.defaultLanguageCode)
    }

    // Visual constants
    private let heroHeight: CGFloat = 160 // single fixed height for all tiles
    private let heroCornerRadius: CGFloat = 10
    private let portraitZoom: CGFloat = 1.15 // extra zoom for portrait sources to strengthen center crop

    // Preload hero image once
    private var heroUIImage: UIImage? {
        guard let hero = heroPhoto else { return nil }
        return loadImage(for: hero)
    }

    // Orientation check
    private var isPortraitHero: Bool {
        guard let img = heroUIImage else { return false }
        return img.size.height > img.size.width
    }

    // Energy display computed from stored kcal
    private var energyDisplayValue: Int {
        switch energyUnit {
        case .calories:
            return Int(meal.calories.rounded())
        case .kilojoules:
            return Int((meal.calories * 4.184).rounded())
        }
    }

    private var energyDisplaySuffix: String {
        switch energyUnit {
        case .calories: return NSLocalizedString("unit_kcal_suffix", comment: "")
        case .kilojoules: return NSLocalizedString("unit_kj_suffix", comment: "")
        }
    }

    // Consider a meal “saved” if its objectID is not temporary and it has a context.
    private var isSaved: Bool {
        guard let ctx = meal.managedObjectContext else { return false }
        // A non-temporary objectID indicates it has been saved at least once.
        return !meal.objectID.isTemporaryID && ctx.registeredObject(for: meal.objectID) != nil
    }

    // Replace bad literal keys saved as titles from older builds with a proper auto title
    private var sanitizedBaseTitle: String {
        let raw = meal.title.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw == "auto_title_meal - pattern" || raw == "auto_title_snack - pattern" || raw.isEmpty {
            // Use current in-app language-aware auto title
            return Meal.autoTitle(for: meal.date, languageCode: appLanguageCode)
        }
        return raw
    }

    // Combined title: base title (sanitized) plus product name if present
    private var combinedTitle: String {
        let base = sanitizedBaseTitle
        let prod = meal.productName?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let prod, !prod.isEmpty {
            if base.isEmpty {
                return prod
            }
            let needsDot = !(base.hasSuffix(".") || base.hasSuffix("!") || base.hasSuffix("?"))
            return needsDot ? "\(base). \(prod)" : "\(base) \(prod)"
        }
        return base
    }

    var body: some View {
        // Defensive: avoid touching properties if the object is deleted or contextless
        if meal.isDeleted || meal.managedObjectContext == nil {
            // Minimal placeholder with same outer sizing so grid layout remains stable
            Color.clear
                .frame(width: fixedWidth, height: heroHeight)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color(.secondarySystemBackground))
                )
                .contentShape(RoundedRectangle(cornerRadius: 12))
        } else {
            VStack(alignment: .leading, spacing: 8) {
                // Hero with inline thumbnails overlay
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let img = heroUIImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()               // fill the fixed box
                                .frame(width: fixedWidth, height: heroHeight)
                                .clipped()                    // crop overflow
                                .scaleEffect(isPortraitHero ? portraitZoom : 1.0, anchor: .center)
                        } else {
                            ZStack {
                                Rectangle()
                                    .fill(Color.secondary.opacity(0.10))
                                Image(systemName: "photo")
                                    .font(.system(size: 28, weight: .regular))
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: fixedWidth, height: heroHeight)
                            .clipped()
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: heroCornerRadius))

                    // Thumbnails overlay (up to 3)
                    if !thumbnailPhotos.isEmpty {
                        let thumbs = Array(thumbnailPhotos.prefix(3))
                        HStack(spacing: 6) {
                            ForEach(Array(thumbs.enumerated()), id: \.offset) { _, p in
                                ZStack {
                                    if let img = loadImage(for: p) {
                                        Image(uiImage: img)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Rectangle()
                                            .fill(Color.secondary.opacity(0.15))
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .foregroundStyle(.secondary)
                                            )
                                    }
                                }
                                .frame(width: 34, height: 34)
                                .clipped()
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.white.opacity(0.9), lineWidth: 1)
                                )
                                .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                            }

                            // If there are more thumbnails than shown, show a "+N" badge
                            if thumbnailPhotos.count > thumbs.count {
                                let remaining = thumbnailPhotos.count - thumbs.count
                                Text("+\(remaining)")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial, in: Capsule())
                                    .overlay(
                                        Capsule().stroke(Color.white.opacity(0.9), lineWidth: 1)
                                    )
                                    .shadow(color: Color.black.opacity(0.15), radius: 2, x: 0, y: 1)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(
                            Capsule()
                                .fill(Color.black.opacity(0.15))
                                .blur(radius: 8)
                                .opacity(0.001) // visual effect only; main background via material below
                        )
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(8)
                    }
                }

                // Title (with product name appended when available)
                Text(combinedTitle)
                    .font(.headline)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                // Quick stats row
                HStack(spacing: 8) {
                    Label("\(energyDisplayValue)", systemImage: "flame")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(.secondary)

                    Text("\(energyDisplayValue) \(energyDisplaySuffix)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 8)
                }

                // Uniform macro circles
                HStack(spacing: 10) {
                    MacroCircle(
                        value: Int(meal.carbohydrates),
                        unit: NSLocalizedString("unit_g_suffix", comment: ""),
                        shortLabel: shortKey("carbs.short"),
                        color: .blue
                    )
                    MacroCircle(
                        value: Int(meal.protein),
                        unit: NSLocalizedString("unit_g_suffix", comment: ""),
                        shortLabel: shortKey("protein.short"),
                        color: .green
                    )
                    MacroCircle(
                        value: Int(meal.fat),
                        unit: NSLocalizedString("unit_g_suffix", comment: ""),
                        shortLabel: shortKey("fat.short"),
                        color: .orange
                    )
                }
                .padding(.top, 2)

                // Date + Time
                HStack(spacing: 6) {
                    Text(meal.date, style: .date)
                    Text(meal.date, style: .time)
                }
                .font(.caption)
                .foregroundStyle(.tertiary)

                // DEBUG-only: show photoGuesserType after save, only if set (wizard used)
                #if DEBUG
                if isSaved, let tag = meal.photoGuesserType, !tag.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let fmt = NSLocalizedString("debug_guesser_format", comment: "Debug label prefix for guesser type, e.g., 'Guesser: %@'")
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .foregroundStyle(.secondary)
                        Text(String(format: fmt, tag))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
                #endif
            }
            .padding(12)
            .frame(width: fixedWidth, alignment: .center) // ensure the whole tile respects the column width
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.secondarySystemBackground))
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
    }

    private func shortKey(_ key: String) -> String {
        let localized = localizationManager.localized(key)
        switch key {
        case "carbs.short":
            return localized == key ? "Carb" : localized
        case "protein.short":
            return localized == key ? "Prot" : localized
        case "fat.short":
            return localized == key ? "Fat" : localized
        default:
            return localized
        }
    }

    @ViewBuilder
    private func badge(_ title: String, _ value: Double) -> some View {
        HStack(spacing: 4) {
            Text(title)
            Text(value.cleanString)
        }
        .font(.caption)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.15))
        .clipShape(Capsule())
    }
}

// Uniform circular macro indicator
private struct MacroCircle: View {
    let value: Int
    let unit: String
    let shortLabel: String
    let color: Color

    // Visual constants
    private let diameter: CGFloat = 48
    private let lineWidth: CGFloat = 2

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .strokeBorder(color.opacity(0.35), lineWidth: lineWidth)

                Circle()
                    .fill(color.opacity(0.12))

                // Value + unit
                VStack(spacing: 0) {
                    Text("\(value)")
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text(unit)
                        .font(.system(size: 9, weight: .regular, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .foregroundColor(.primary)
                .padding(6)
            }
            .frame(width: diameter, height: diameter)

            Text(shortLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: diameter)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(shortLabel) \(value) \(unit)")
    }
}
