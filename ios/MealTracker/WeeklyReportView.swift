//
//  WeeklyReportView.swift
//  MealTracker
//
//  Created by Simon Lee on 11/1/2026.
//


//
//  WeeklyReportView.swift
//  MealTracker
//
//  Created by Simon Lee on 11/01/2026.
//

import SwiftUI
import CoreData

// Conditionally import Charts for iOS 16+
#if canImport(Charts)
import Charts
#endif

struct WeeklyReportView: View {
    @Environment(\.managedObjectContext) private var context
    @AppStorage("energyUnit") private var energyUnit: EnergyUnit = .calories
    @AppStorage("showVitamins") private var showVitamins: Bool = false
    @AppStorage("vitaminsUnit") private var vitaminsUnit: VitaminsUnit = .milligrams
    @AppStorage("showStimulants") private var showStimulants: Bool = false
    @AppStorage("appLanguageCode") private var appLanguageCode: String = LocalizationManager.defaultLanguageCode

    // Week navigation: 0 = this week, -1 = previous, +1 = next (future)
    @State private var weekOffset: Int = 0

    // Collapsible groups state
    @State private var mineralsExpanded: Bool = false
    @State private var vitaminsExpanded: Bool = false
    @State private var stimulantsExpanded: Bool = false

    // Compute week range (Mon 00:00:00 ... Sun 23:59:59) for given offset
    private var weekRange: (start: Date, end: Date) {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let today = Date()
        let startOfDay = cal.startOfDay(for: today)
        let weekday = cal.component(.weekday, from: startOfDay)
        let daysFromMonday = (weekday + 5) % 7 // maps Mon->0, Tue->1, ... Sun->6
        let thisMonday = cal.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
        // Apply offset in weeks
        let monday = cal.date(byAdding: .day, value: weekOffset * 7, to: thisMonday) ?? thisMonday
        let sunday = cal.date(byAdding: .day, value: 6, to: monday) ?? monday
        // End of Sunday: 23:59:59
        let end = cal.date(byAdding: DateComponents(day: 1, second: -1), to: cal.startOfDay(for: sunday)) ?? sunday
        return (monday, end)
    }

    // Fetch meals in week range
    @FetchRequest private var meals: FetchedResults<Meal>

    init() {
        // Initialize fetch for current week (offset 0)
        let (start, end) = WeeklyReportView.computeWeekRange(forOffset: 0)
        let req: NSFetchRequest<Meal> = NSFetchRequest(entityName: "Meal")
        req.predicate = NSPredicate(format: "date >= %@ AND date <= %@", start as NSDate, end as NSDate)
        req.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]
        _meals = FetchRequest(fetchRequest: req)
    }

    // Helper to compute week range without needing self
    private static func computeWeekRange(forOffset offset: Int) -> (start: Date, end: Date) {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        let today = Date()
        let startOfDay = cal.startOfDay(for: today)
        let weekday = cal.component(.weekday, from: startOfDay)
        let daysFromMonday = (weekday + 5) % 7
        let thisMonday = cal.date(byAdding: .day, value: -daysFromMonday, to: startOfDay) ?? startOfDay
        let monday = cal.date(byAdding: .day, value: offset * 7, to: thisMonday) ?? thisMonday
        let sunday = cal.date(byAdding: .day, value: 6, to: monday) ?? monday
        let end = cal.date(byAdding: DateComponents(day: 1, second: -1), to: cal.startOfDay(for: sunday)) ?? sunday
        return (monday, end)
    }

    fileprivate struct DayTotals: Identifiable {
        let id = UUID()
        let date: Date
        let weekdayIndex: Int // 0=Mon ... 6=Sun
        // kcal and macro grams
        let caloriesKcal: Double
        let carbsG: Double
        let proteinG: Double
        let fatG: Double
    }

    private struct WeekTotals {
        var caloriesKcal: Double = 0
        var carbsG: Double = 0
        var proteinG: Double = 0
        var fatG: Double = 0

        // Minerals (mg)
        var sodiumMg: Double = 0
        var calciumMg: Double = 0
        var ironMg: Double = 0
        var potassiumMg: Double = 0
        var zincMg: Double = 0
        var magnesiumMg: Double = 0
        var iodineMg: Double = 0
        var phosphorusMg: Double = 0

        // Vitamins (mg)
        var vitaminAMg: Double = 0
        var vitaminBMg: Double = 0
        var vitaminCMg: Double = 0
        var vitaminDMg: Double = 0
        var vitaminEMg: Double = 0
        var vitaminKMg: Double = 0

        // Stimulants (alcohol g; others mg)
        var alcoholG: Double = 0
        var nicotineMg: Double = 0
        var theobromineMg: Double = 0
        var caffeineMg: Double = 0
        var taurineMg: Double = 0
        var creatineMg: Double = 0
    }

    private var dayTotals: [DayTotals] {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        // Initialize 7 days Mon..Sun
        let start = weekRange.start
        var buckets: [[Meal]] = Array(repeating: [], count: 7)
        for meal in meals where meal.date >= weekRange.start && meal.date <= weekRange.end {
            let comps = cal.dateComponents([.day], from: start, to: cal.startOfDay(for: meal.date))
            let idx = (comps.day ?? 0)
            if idx >= 0 && idx < 7 {
                buckets[idx].append(meal)
            }
        }

        var result: [DayTotals] = []
        for i in 0..<7 {
            let dayDate = cal.date(byAdding: .day, value: i, to: start) ?? start
            let mlist = buckets[i]
            let kcal = mlist.reduce(0.0) { $0 + max(0, mealCaloriesKcal($1)) }
            let carbs = mlist.reduce(0.0) { $0 + max(0, $1.carbohydrates) }
            let protein = mlist.reduce(0.0) { $0 + max(0, $1.protein) }
            let fat = mlist.reduce(0.0) { $0 + max(0, $1.fat) }
            result.append(DayTotals(date: dayDate, weekdayIndex: i, caloriesKcal: kcal, carbsG: carbs, proteinG: protein, fatG: fat))
        }
        return result
    }

    private var weekTotals: WeekTotals {
        var t = WeekTotals()
        for m in meals {
            t.caloriesKcal += max(0, mealCaloriesKcal(m))
            t.carbsG += max(0, m.carbohydrates)
            t.proteinG += max(0, m.protein)
            t.fatG += max(0, m.fat)

            // Minerals
            t.sodiumMg += max(0, m.sodium)
            t.calciumMg += max(0, m.calcium)
            t.ironMg += max(0, m.iron)
            t.potassiumMg += max(0, m.potassium)
            t.zincMg += max(0, m.zinc)
            t.magnesiumMg += max(0, m.magnesium)
            t.iodineMg += max(0, m.iodine)
            t.phosphorusMg += max(0, m.phosphorus)

            // Vitamins (mg)
            t.vitaminAMg += max(0, m.vitaminA)
            t.vitaminBMg += max(0, m.vitaminB)
            t.vitaminCMg += max(0, m.vitaminC)
            t.vitaminDMg += max(0, m.vitaminD)
            t.vitaminEMg += max(0, m.vitaminE)
            t.vitaminKMg += max(0, m.vitaminK)

            // Stimulants
            t.alcoholG += max(0, m.alcohol)
            t.nicotineMg += max(0, m.nicotine)
            t.theobromineMg += max(0, m.theobromine)
            t.caffeineMg += max(0, m.caffeine)
            t.taurineMg += max(0, m.taurine)
            t.creatineMg += max(0, m.creatine)
        }
        return t
    }

    private func mealCaloriesKcal(_ m: Meal) -> Double {
        // Stored as kcal in model. If user prefers kJ for display, conversion happens in UI only.
        return max(0, m.calories)
    }

    private func weekdayShort(_ index: Int) -> String {
        // Prefer localized short names Mon..Sun via DateFormatter
        let df = DateFormatter()
        df.locale = Locale.current
        df.setLocalizedDateFormatFromTemplate("EEE")
        let date = Calendar.current.date(byAdding: .day, value: index, to: weekRange.start) ?? Date()
        let s = df.string(from: date)
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return s
    }

    // Convert macros to kcal for stacking
    private func macroKcal(carbG: Double, proteinG: Double, fatG: Double) -> (carbKcal: Double, proteinKcal: Double, fatKcal: Double) {
        let c = max(0, carbG) * 4.0
        let p = max(0, proteinG) * 4.0
        let f = max(0, fatG) * 9.0
        return (c, p, f)
    }

    private var totalEnergyDisplay: (value: Int, unit: String) {
        let l = LocalizationManager(languageCode: appLanguageCode)
        let kcal = weekTotals.caloriesKcal
        switch energyUnit {
        case .calories:
            return (Int(kcal.rounded()), l.localized("unit_kcal_suffix"))
        case .kilojoules:
            let kj = kcal * 4.184
            return (Int(kj.rounded()), l.localized("unit_kj_suffix"))
        }
    }

    var body: some View {
        let l = LocalizationManager(languageCode: appLanguageCode)

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                headerSection(l: l)

                chartSection(l: l)

                // Always show Vitamins first
                vitaminsGroup(l: l)

                // Then Minerals
                mineralsGroup(l: l)

                // Now always show Stimulants (placed below minerals)
                stimulantsGroup(l: l)

                perDayListSection(l: l)

                // Bottom creatine running total (mg), only if > 0
                bottomCreatineTotal(l: l)
            }
            .padding()
        }
        .navigationTitle(l.localized("weekly_report_title"))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        // Update fetch when the weekOffset changes
        .onChange(of: weekOffset) { _ in
            updateFetchPredicate()
        }
        .onAppear {
            // Ensure predicate is correct on first appear (especially when presented modally)
            updateFetchPredicate()
        }
    }

    private func headerSection(l: LocalizationManager) -> some View {
        // Prepare formatter and strings outside the ViewBuilder
        let formatter: DateFormatter = {
            let f = DateFormatter()
            f.dateStyle = .medium
            f.timeStyle = .none
            return f
        }()
        let rangeText = "\(formatter.string(from: weekRange.start)) – \(formatter.string(from: weekRange.end))"

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Back one week
                Button {
                    weekOffset -= 1
                } label: {
                    Image(systemName: "chevron.left")
                }
                .accessibilityLabel(l.localized("a11y_previous_week"))

                Spacer(minLength: 8)

                VStack(spacing: 2) {
                    Text(l.localized(weekOffset == 0 ? "this_week" : "week"))
                        .font(.title2.weight(.semibold))
                    Text(rangeText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                // Forward one week (disabled for current week)
                Button {
                    weekOffset += 1
                } label: {
                    Image(systemName: "chevron.right")
                }
                .disabled(weekOffset >= 0)
                .accessibilityLabel(l.localized("a11y_next_week"))
            }

            // Numeric calories somewhere
            HStack(spacing: 8) {
                Image(systemName: "flame.fill").foregroundStyle(.orange)
                Text("\(totalEnergyDisplay.value) \(totalEnergyDisplay.unit) \(l.localized("total_suffix"))")
                    .font(.headline)
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func chartSection(l: LocalizationManager) -> some View {
        Group {
            if #available(iOS 16.0, *), _isChartsAvailable {
                ChartsView(dayTotals: dayTotals, l: l)
                    .frame(height: 240)
                    .accessibilityLabel(l.localized("a11y_weekly_calories_chart"))
            } else {
                FallbackBarsView(dayTotals: dayTotals, l: l)
                    .frame(height: 240)
                    .accessibilityLabel(l.localized("a11y_weekly_calories_chart"))
            }
        }
    }

    // MARK: - Collapsible Groups

    private func mineralsGroup(l: LocalizationManager) -> some View {
        DisclosureGroup(isExpanded: $mineralsExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                mineralRow(l.localized("sodium"), weekTotals.sodiumMg, suffix: l.localized("unit_mg_suffix"))
                mineralRow(l.localized("calcium"), weekTotals.calciumMg, suffix: l.localized("unit_mg_suffix"))
                mineralRow(l.localized("iron"), weekTotals.ironMg, suffix: l.localized("unit_mg_suffix"))
                mineralRow(l.localized("potassium"), weekTotals.potassiumMg, suffix: l.localized("unit_mg_suffix"))
                mineralRow(l.localized("zinc"), weekTotals.zincMg, suffix: l.localized("unit_mg_suffix"))
                mineralRow(l.localized("magnesium"), weekTotals.magnesiumMg, suffix: l.localized("unit_mg_suffix"))
                mineralRow(l.localized("iodine"), weekTotals.iodineMg, suffix: l.localized("unit_mg_suffix"))
                mineralRow(l.localized("phosphorus"), weekTotals.phosphorusMg, suffix: l.localized("unit_mg_suffix"))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        } label: {
            Text(l.localized("minerals_weekly_total"))
                .font(.headline)
        }
    }

    private func vitaminsGroup(l: LocalizationManager) -> some View {
        DisclosureGroup(isExpanded: $vitaminsExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                vitaminRow(l.localized("vitamin_a_title"), weekTotals.vitaminAMg, l: l)
                vitaminRow(l.localized("vitamin_b_title"), weekTotals.vitaminBMg, l: l)
                vitaminRow(l.localized("vitamin_c_title"), weekTotals.vitaminCMg, l: l)
                vitaminRow(l.localized("vitamin_d_title"), weekTotals.vitaminDMg, l: l)
                vitaminRow(l.localized("vitamin_e_title"), weekTotals.vitaminEMg, l: l)
                vitaminRow(l.localized("vitamin_k_title"), weekTotals.vitaminKMg, l: l)
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        } label: {
            Text(l.localized("vitamins_weekly_total"))
                .font(.headline)
        }
    }

    private func stimulantsGroup(l: LocalizationManager) -> some View {
        DisclosureGroup(isExpanded: $stimulantsExpanded) {
            VStack(alignment: .leading, spacing: 6) {
                stimulantRow(l.localized("alcohol"), value: weekTotals.alcoholG, suffix: l.localized("unit_g_suffix"))
                stimulantRow(l.localized("nicotine"), value: weekTotals.nicotineMg, suffix: l.localized("unit_mg_suffix"))
                stimulantRow(l.localized("theobromine"), value: weekTotals.theobromineMg, suffix: l.localized("unit_mg_suffix"))
                stimulantRow(l.localized("caffeine"), value: weekTotals.caffeineMg, suffix: l.localized("unit_mg_suffix"))
                stimulantRow(l.localized("taurine"), value: weekTotals.taurineMg, suffix: l.localized("unit_mg_suffix"))
                stimulantRow(l.localized("creatine"), value: weekTotals.creatineMg, suffix: l.localized("unit_mg_suffix"))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.top, 4)
        } label: {
            Text(l.localized("stimulants_weekly_total"))
                .font(.headline)
        }
    }

    private func mineralRow(_ name: String, _ value: Double, suffix: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(numberString(value))
            Text(suffix)
        }
    }

    private func vitaminRow(_ name: String, _ mgValue: Double, l: LocalizationManager) -> some View {
        let display = vitaminsUnitDisplay(fromStorageMg: mgValue, l: l)
        return HStack {
            Text(name)
            Spacer()
            Text(display.value)
            Text(display.unitSuffix)
        }
    }

    private func stimulantRow(_ name: String, value: Double, suffix: String) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(numberString(value))
            Text(suffix)
        }
    }

    private func perDayListSection(l: LocalizationManager) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(l.localized("per_day_header"))
                .font(.headline)

            ForEach(dayTotals) { d in
                let energy = energyForDisplay(kcal: d.caloriesKcal, l: l)
                HStack {
                    Text(weekdayShort(d.weekdayIndex))
                        .frame(width: 44, alignment: .leading)
                    Spacer()
                    Text("\(l.localized("macro_c_short")) \(Int(d.carbsG.rounded()))\(l.localized("unit_g_suffix"))")
                    Text("\(l.localized("macro_p_short")) \(Int(d.proteinG.rounded()))\(l.localized("unit_g_suffix"))")
                    Text("\(l.localized("macro_f_short")) \(Int(d.fatG.rounded()))\(l.localized("unit_g_suffix"))")
                    Divider().frame(height: 14)
                    Text("\(energy.value) \(energy.unit)")
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
                .font(.caption)
            }
        }
    }

    // Bottom creatine total section (mg), shown only if total > 0
    @ViewBuilder
    private func bottomCreatineTotal(l: LocalizationManager) -> some View {
        let totalMg = weekTotals.creatineMg
        if totalMg > 0 {
            Divider()
                .padding(.top, 8)

            HStack {
                Text(l.localized("creatine_total_title"))
                    .font(.headline)
                Spacer()
                Text(numberString(totalMg))
                    .font(.headline.monospacedDigit())
                Text(l.localized("unit_mg_suffix"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(l.localized("creatine_total_title")) \(numberString(totalMg)) \(l.localized("unit_milligrams_long"))")
        }
    }

    private func energyForDisplay(kcal: Double, l: LocalizationManager) -> (value: Int, unit: String) {
        switch energyUnit {
        case .calories:
            return (Int(kcal.rounded()), l.localized("unit_kcal_suffix"))
        case .kilojoules:
            return (Int((kcal * 4.184).rounded()), l.localized("unit_kj_suffix"))
        }
    }

    private func numberString(_ value: Double) -> String {
        let v = (value * 10).rounded() / 10
        if abs(v - v.rounded()) < 0.0001 {
            return String(Int(v.rounded()))
        } else {
            return String(format: "%.1f", v)
        }
    }

    // Vitamins unit-aware display
    private func vitaminsUnitDisplay(fromStorageMg mg: Double, l: LocalizationManager) -> (value: String, unitSuffix: String) {
        switch vitaminsUnit {
        case .milligrams:
            // up to 1 decimal place for readability like other rows
            let v = (mg * 10).rounded() / 10
            let text: String
            if abs(v - v.rounded()) < 0.0001 {
                text = String(Int(v.rounded()))
            } else {
                text = String(format: "%.1f", v)
            }
            return (text, l.localized("unit_mg_suffix"))
        case .micrograms:
            let ug = mg * 1000.0
            let val = Int(ug.rounded())
            return ("\(val)", l.localized("unit_ug_suffix"))
        }
    }

    // Update the fetch request predicate to current weekRange
    private func updateFetchPredicate() {
        let (start, end) = weekRange
        meals.nsPredicate = NSPredicate(format: "date >= %@ AND date <= %@", start as NSDate, end as NSDate)
    }
}

#if canImport(Charts)
@available(iOS 16.0, *)
private struct ChartsView: View {
    let dayTotals: [WeeklyReportView.DayTotals]
    let l: LocalizationManager

    var body: some View {
        // Build a fixed categorical domain for the x-axis so all weekdays appear,
        // even when a day has no entries (zero kcal and zero macros).
        let xDomain = dayTotals.map { weekdayShort($0) }

        Chart {
            ForEach(dayTotals) { d in
                let macros = macroKcal(d)
                let sum = macros.carbKcal + macros.proteinKcal + macros.fatKcal

                if sum > 0 {
                    // Carb
                    BarMark(
                        x: .value(l.localized("chart_axis_day"), weekdayShort(d)),
                        y: .value(l.localized("chart_axis_kcal"), macros.carbKcal)
                    )
                    .foregroundStyle(.blue.opacity(0.6))
                    .position(by: .value(l.localized("chart_series_macro"), l.localized("macro_carb")))
                    // Protein
                    BarMark(
                        x: .value(l.localized("chart_axis_day"), weekdayShort(d)),
                        y: .value(l.localized("chart_axis_kcal"), macros.proteinKcal)
                    )
                    .foregroundStyle(.green.opacity(0.6))
                    .position(by: .value(l.localized("chart_series_macro"), l.localized("macro_protein")))
                    // Fat
                    BarMark(
                        x: .value(l.localized("chart_axis_day"), weekdayShort(d)),
                        y: .value(l.localized("chart_axis_kcal"), macros.fatKcal)
                    )
                    .foregroundStyle(.orange.opacity(0.7))
                    .position(by: .value(l.localized("chart_series_macro"), l.localized("macro_fat")))
                } else if d.caloriesKcal > 0 {
                    // Generic fallback bar when macros are missing but calories exist
                    BarMark(
                        x: .value(l.localized("chart_axis_day"), weekdayShort(d)),
                        y: .value(l.localized("chart_axis_kcal"), d.caloriesKcal)
                    )
                    .foregroundStyle(.gray.opacity(0.5))
                    .position(by: .value(l.localized("chart_series_macro"), caloriesOnlyLabel()))
                } else {
                    // Force category presence with a zero-height, transparent bar
                    // (not strictly required when using chartXScale domain, but harmless).
                    BarMark(
                        x: .value(l.localized("chart_axis_day"), weekdayShort(d)),
                        y: .value(l.localized("chart_axis_kcal"), 0)
                    )
                    .opacity(0.0)
                }
            }
        }
        .chartXScale(domain: xDomain)
        .chartLegend(position: .top, alignment: .leading)
        .chartXAxis {
            AxisMarks(values: xDomain) { _ in
                AxisGridLine().foregroundStyle(.clear)
                AxisTick()
                AxisValueLabel()
            }
        }
        .chartYAxis {
            AxisMarks()
        }
    }

    private func macroKcal(_ d: WeeklyReportView.DayTotals) -> (carbKcal: Double, proteinKcal: Double, fatKcal: Double) {
        let c = max(0, d.carbsG) * 4.0
        let p = max(0, d.proteinG) * 4.0
        let f = max(0, d.fatG) * 9.0
        return (c, p, f)
    }

    private func weekdayShort(_ d: WeeklyReportView.DayTotals) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("EEE")
        return df.string(from: d.date)
            .replacingOccurrences(of: ".", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func caloriesOnlyLabel() -> String {
        // Try localized key; if missing, fall back to "Calories"
        let key = l.localized("calories_only_generic")
        return key == "calories_only_generic" ? "Calories" : key
    }
}
#endif

// iOS 15 fallback: simple stacked-like bars using Hstacks
private struct FallbackBarsView: View {
    let dayTotals: [WeeklyReportView.DayTotals]
    let l: LocalizationManager

    // Determine if any day uses the generic calories-only bar
    private var hasGenericDays: Bool {
        dayTotals.contains { d in
            let macros = macroKcal(d)
            let sum = macros.carbKcal + macros.proteinKcal + macros.fatKcal
            return sum == 0 && d.caloriesKcal > 0
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(dayTotals) { d in
                let macros = macroKcal(d)
                let macrosSum = macros.carbKcal + macros.proteinKcal + macros.fatKcal
                HStack(spacing: 4) {
                    Text(shortDay(d.date))
                        .font(.caption2)
                        .frame(width: 30, alignment: .leading)

                    GeometryReader { geo in
                        let width = geo.size.width
                        HStack(spacing: 1) {
                            if macrosSum > 0 {
                                Rectangle()
                                    .fill(Color.blue.opacity(0.6))
                                    .frame(width: width * (macros.carbKcal / max(1, macrosSum)))
                                Rectangle()
                                    .fill(Color.green.opacity(0.6))
                                    .frame(width: width * (macros.proteinKcal / max(1, macrosSum)))
                                Rectangle()
                                    .fill(Color.orange.opacity(0.7))
                                    .frame(width: width * (macros.fatKcal / max(1, macrosSum)))
                            } else if d.caloriesKcal > 0 {
                                // Generic full-width bar when macros are missing
                                Rectangle()
                                    .fill(Color.gray.opacity(0.5))
                                    .frame(width: width)
                            } else {
                                // No entries: draw an empty bar area to keep row height consistent
                                Color.clear.frame(width: width)
                            }
                        }
                        .cornerRadius(3)
                    }
                    .frame(height: 12)

                    // Show calories for that day (generic covers the case macrosSum == 0)
                    let trailing = macrosSum > 0 ? Int(macrosSum.rounded()) : Int(d.caloriesKcal.rounded())
                    Text("\(trailing)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                }
                .frame(height: 16)
            }

            // Legend
            HStack(spacing: 12) {
                legendSwatch(.blue.opacity(0.6), l.localized("macro_carb"))
                legendSwatch(.green.opacity(0.6), l.localized("macro_protein"))
                legendSwatch(.orange.opacity(0.7), l.localized("macro_fat"))
                if hasGenericDays {
                    legendSwatch(.gray.opacity(0.5), caloriesOnlyLabel())
                }
                Spacer()
            }
            .padding(.top, 6)
        }
    }

    private func macroKcal(_ d: WeeklyReportView.DayTotals) -> (carbKcal: Double, proteinKcal: Double, fatKcal: Double) {
        let c = max(0, d.carbsG) * 4.0
        let p = max(0, d.proteinG) * 4.0
        let f = max(0, d.fatG) * 9.0
        return (c, p, f)
    }

    private func shortDay(_ date: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.setLocalizedDateFormatFromTemplate("EEE")
        return df.string(from: date)
            .replacingOccurrences(of: ".", with: "")
    }

    private func legendSwatch(_ color: Color, _ label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2)
        }
    }

    private func caloriesOnlyLabel() -> String {
        let key = l.localized("calories_only_generic")
        return key == "calories_only_generic" ? "Calories" : key
    }
}

// Helper to detect Charts availability at runtime/compile-time combo
private var _isChartsAvailable: Bool {
    #if canImport(Charts)
    return true
    #else
    return false
    #endif
}
