import Foundation

enum EnergyUnit: String, CaseIterable, Codable, Equatable, Hashable {
    case calories
    case kilojoules

    // Used in MealFormView: energyUnit.displaySuffix(manager:)
    func displaySuffix(manager: LocalizationManager) -> String {
        switch self {
        case .calories:
            return manager.localized("unit_kcal_suffix")
        case .kilojoules:
            return manager.localized("unit_kj_suffix")
        }
    }
}

// MeasurementSystem removed; app defaults to metric everywhere.

enum SodiumUnit: String, CaseIterable, Codable, Equatable, Hashable {
    case milligrams
    case grams

    var displaySuffix: String {
        switch self {
        case .milligrams: return NSLocalizedString("unit_mg_suffix", comment: "")
        case .grams: return NSLocalizedString("unit_g_suffix", comment: "")
        }
    }

    // Optional helpers if you later need conversions
    func toMilligrams(from value: Double) -> Double {
        switch self {
        case .milligrams: return value
        case .grams: return value * 1000.0
        }
    }

    func fromMilligrams(_ mg: Double) -> Double {
        switch self {
        case .milligrams: return mg
        case .grams: return mg / 1000.0
        }
    }
}

enum VitaminsUnit: String, CaseIterable, Codable, Equatable, Hashable {
    case milligrams
    case micrograms

    var displaySuffix: String {
        switch self {
        case .milligrams: return NSLocalizedString("unit_mg_suffix", comment: "")
        case .micrograms: return NSLocalizedString("unit_ug_suffix", comment: "")
        }
    }

    // New: localized via in-app language manager
    func displaySuffix(manager: LocalizationManager) -> String {
        switch self {
        case .milligrams:
            return manager.localized("unit_mg_suffix")
        case .micrograms:
            return manager.localized("unit_ug_suffix")
        }
    }

    // Storage is in milligrams as per Meal model comments
    func toStorageMG(_ uiValue: Double) -> Double {
        switch self {
        case .milligrams:
            return uiValue
        case .micrograms:
            return uiValue / 1000.0
        }
    }

    func fromStorageMG(_ mgValue: Double) -> Double {
        switch self {
        case .milligrams:
            return mgValue
        case .micrograms:
            return mgValue * 1000.0
        }
    }
}

enum Handedness: String, CaseIterable, Codable, Equatable, Hashable {
    case right
    case left
}
