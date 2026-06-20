//
//  FoodClassPriors.swift
//  MealTracker
//
//  Priors for food classes (no training). Maps a predicted label and a portion proxy
//  to a GuessResult (kcal, carbs, protein, fat).
//

import Foundation
import UIKit

struct FoodClassPriors {

    struct Priors {
        // Typical kcal for a single serving of the class or per-plate baseline
        let baseKcal: Int
        // Macro split proportions (sum ~1.0)
        let carb: Double
        let protein: Double
        let fat: Double
        // Optional hard caps/mins to keep outputs plausible
        let minKcal: Int?
        let maxKcal: Int?
        // Portion scaling aggressiveness for this class (multiplies area-based scale)
        let portionScaleGain: Double
    }

    // Public labels you can use in FoodReferenceIndex.json
    // You can extend this dictionary without code changes.
    static let priors: [String: Priors] = [
        // Desserts / bakery
        "cupcake": Priors(baseKcal: 450, carb: 0.55, protein: 0.07, fat: 0.38, minKcal: 280, maxKcal: 560, portionScaleGain: 0.6),
        "donut": Priors(baseKcal: 320, carb: 0.60, protein: 0.06, fat: 0.34, minKcal: 220, maxKcal: 520, portionScaleGain: 0.6),
        "brownie_bar": Priors(baseKcal: 300, carb: 0.55, protein: 0.06, fat: 0.39, minKcal: 200, maxKcal: 520, portionScaleGain: 0.6),
        "cookie": Priors(baseKcal: 220, carb: 0.64, protein: 0.05, fat: 0.31, minKcal: 120, maxKcal: 400, portionScaleGain: 0.5),
        "cheesecake_slice": Priors(baseKcal: 480, carb: 0.46, protein: 0.09, fat: 0.45, minKcal: 320, maxKcal: 650, portionScaleGain: 0.7),
        "ice_cream_scoop": Priors(baseKcal: 180, carb: 0.30, protein: 0.06, fat: 0.64, minKcal: 120, maxKcal: 360, portionScaleGain: 0.5),
        "pancake_waffle_stack": Priors(baseKcal: 420, carb: 0.56, protein: 0.10, fat: 0.34, minKcal: 280, maxKcal: 700, portionScaleGain: 0.8),

        // Fried plate components
        "fries": Priors(baseKcal: 350, carb: 0.58, protein: 0.05, fat: 0.37, minKcal: 200, maxKcal: 900, portionScaleGain: 1.2),
        "battered_fish_fillet": Priors(baseKcal: 320, carb: 0.25, protein: 0.25, fat: 0.50, minKcal: 200, maxKcal: 800, portionScaleGain: 1.0),
        "fried_chicken_piece": Priors(baseKcal: 320, carb: 0.12, protein: 0.38, fat: 0.50, minKcal: 200, maxKcal: 850, portionScaleGain: 1.0),
        "onion_rings": Priors(baseKcal: 300, carb: 0.50, protein: 0.06, fat: 0.44, minKcal: 180, maxKcal: 700, portionScaleGain: 1.0),

        // Pasta / noodles / rice
        "pasta_tomato": Priors(baseKcal: 420, carb: 0.68, protein: 0.14, fat: 0.18, minKcal: 280, maxKcal: 900, portionScaleGain: 0.9),
        "pasta_cream": Priors(baseKcal: 600, carb: 0.52, protein: 0.12, fat: 0.36, minKcal: 380, maxKcal: 1200, portionScaleGain: 0.9),
        "pasta_pesto": Priors(baseKcal: 560, carb: 0.48, protein: 0.12, fat: 0.40, minKcal: 360, maxKcal: 1100, portionScaleGain: 0.9),
        "stir_fry_noodles": Priors(baseKcal: 520, carb: 0.58, protein: 0.18, fat: 0.24, minKcal: 320, maxKcal: 1100, portionScaleGain: 0.9),
        "ramen_noodle_soup": Priors(baseKcal: 480, carb: 0.60, protein: 0.18, fat: 0.22, minKcal: 300, maxKcal: 1000, portionScaleGain: 0.8),
        "curry_with_rice": Priors(baseKcal: 650, carb: 0.58, protein: 0.16, fat: 0.26, minKcal: 420, maxKcal: 1400, portionScaleGain: 1.0),
        "sushi_rolls": Priors(baseKcal: 360, carb: 0.68, protein: 0.20, fat: 0.12, minKcal: 220, maxKcal: 800, portionScaleGain: 0.8),

        // Sandwich / wrap / burger
        "burger": Priors(baseKcal: 520, carb: 0.35, protein: 0.23, fat: 0.42, minKcal: 380, maxKcal: 1100, portionScaleGain: 1.0),
        "sandwich_sub": Priors(baseKcal: 420, carb: 0.48, protein: 0.22, fat: 0.30, minKcal: 300, maxKcal: 900, portionScaleGain: 0.9),
        "wrap": Priors(baseKcal: 420, carb: 0.48, protein: 0.22, fat: 0.30, minKcal: 300, maxKcal: 900, portionScaleGain: 0.9),
        "hot_dog": Priors(baseKcal: 320, carb: 0.38, protein: 0.18, fat: 0.44, minKcal: 220, maxKcal: 800, portionScaleGain: 0.9),

        // Salad / soup
        "leafy_salad": Priors(baseKcal: 160, carb: 0.40, protein: 0.15, fat: 0.45, minKcal: 100, maxKcal: 450, portionScaleGain: 0.7),
        "salad_with_protein": Priors(baseKcal: 320, carb: 0.30, protein: 0.35, fat: 0.35, minKcal: 180, maxKcal: 700, portionScaleGain: 0.8),
        "creamy_salad": Priors(baseKcal: 280, carb: 0.20, protein: 0.16, fat: 0.64, minKcal: 160, maxKcal: 720, portionScaleGain: 0.8),
        "clear_soup_broth": Priors(baseKcal: 120, carb: 0.40, protein: 0.25, fat: 0.35, minKcal: 60, maxKcal: 360, portionScaleGain: 0.6),
        "creamy_soup": Priors(baseKcal: 260, carb: 0.28, protein: 0.18, fat: 0.54, minKcal: 140, maxKcal: 700, portionScaleGain: 0.7),

        // Breakfast
        "cereal_bowl_milk": Priors(baseKcal: 280, carb: 0.64, protein: 0.12, fat: 0.24, minKcal: 180, maxKcal: 520, portionScaleGain: 0.8),
        "oatmeal_porridge": Priors(baseKcal: 260, carb: 0.66, protein: 0.14, fat: 0.20, minKcal: 160, maxKcal: 520, portionScaleGain: 0.7),
        "toast_bread": Priors(baseKcal: 180, carb: 0.72, protein: 0.12, fat: 0.16, minKcal: 100, maxKcal: 420, portionScaleGain: 0.6),
        "eggs_scrambled": Priors(baseKcal: 220, carb: 0.05, protein: 0.40, fat: 0.55, minKcal: 140, maxKcal: 520, portionScaleGain: 0.7),
        "omelette": Priors(baseKcal: 280, carb: 0.06, protein: 0.42, fat: 0.52, minKcal: 180, maxKcal: 620, portionScaleGain: 0.7),
        "bacon_strips": Priors(baseKcal: 300, carb: 0.03, protein: 0.30, fat: 0.67, minKcal: 180, maxKcal: 800, portionScaleGain: 0.9),
        "sausage_links": Priors(baseKcal: 320, carb: 0.04, protein: 0.26, fat: 0.70, minKcal: 200, maxKcal: 850, portionScaleGain: 0.9),

        // Fruit / veg / snacks
        "mixed_fruit_bowl": Priors(baseKcal: 180, carb: 0.92, protein: 0.05, fat: 0.03, minKcal: 100, maxKcal: 420, portionScaleGain: 0.6),
        "banana": Priors(baseKcal: 100, carb: 0.93, protein: 0.04, fat: 0.03, minKcal: 70, maxKcal: 200, portionScaleGain: 0.5),
        "nuts_mixed": Priors(baseKcal: 180, carb: 0.18, protein: 0.14, fat: 0.68, minKcal: 120, maxKcal: 900, portionScaleGain: 1.0),
        "chocolate_bar": Priors(baseKcal: 240, carb: 0.53, protein: 0.06, fat: 0.41, minKcal: 160, maxKcal: 700, portionScaleGain: 0.8),
        "chips_crisps_bag": Priors(baseKcal: 260, carb: 0.52, protein: 0.06, fat: 0.42, minKcal: 160, maxKcal: 700, portionScaleGain: 0.8),

        // Pizza
        "pizza_slice_cheese": Priors(baseKcal: 280, carb: 0.45, protein: 0.16, fat: 0.39, minKcal: 200, maxKcal: 600, portionScaleGain: 0.8),
        "pizza_slice_pepperoni": Priors(baseKcal: 320, carb: 0.42, protein: 0.17, fat: 0.41, minKcal: 220, maxKcal: 700, portionScaleGain: 0.9),
        "pizza_slice_veg": Priors(baseKcal: 260, carb: 0.48, protein: 0.14, fat: 0.38, minKcal: 180, maxKcal: 600, portionScaleGain: 0.8),

        // Beverages
        "black_coffee": Priors(baseKcal: 5, carb: 0.00, protein: 0.00, fat: 0.00, minKcal: 0, maxKcal: 30, portionScaleGain: 0.3),
        "latte_cappuccino": Priors(baseKcal: 180, carb: 0.40, protein: 0.30, fat: 0.30, minKcal: 60, maxKcal: 380, portionScaleGain: 0.7),
        "soda_regular": Priors(baseKcal: 150, carb: 1.00, protein: 0.00, fat: 0.00, minKcal: 80, maxKcal: 400, portionScaleGain: 0.7),
        "soda_diet": Priors(baseKcal: 5, carb: 0.00, protein: 0.00, fat: 0.00, minKcal: 0, maxKcal: 30, portionScaleGain: 0.3),
        "smoothie_fruit": Priors(baseKcal: 180, carb: 0.92, protein: 0.05, fat: 0.03, minKcal: 100, maxKcal: 450, portionScaleGain: 0.7),

        // Protein plates
        "grilled_steak": Priors(baseKcal: 300, carb: 0.00, protein: 0.60, fat: 0.40, minKcal: 220, maxKcal: 900, portionScaleGain: 1.0),
        "grilled_chicken_breast": Priors(baseKcal: 250, carb: 0.05, protein: 0.75, fat: 0.20, minKcal: 180, maxKcal: 700, portionScaleGain: 0.9),
        "roasted_chicken_leg": Priors(baseKcal: 300, carb: 0.02, protein: 0.58, fat: 0.40, minKcal: 200, maxKcal: 800, portionScaleGain: 1.0),
        "grilled_salmon": Priors(baseKcal: 300, carb: 0.00, protein: 0.50, fat: 0.50, minKcal: 200, maxKcal: 800, portionScaleGain: 1.0),
        "tofu_stir_fry": Priors(baseKcal: 320, carb: 0.25, protein: 0.35, fat: 0.40, minKcal: 200, maxKcal: 900, portionScaleGain: 0.9)
    ]

    // Build a GuessResult from a label and a portion proxy (0...1 area ratio).
    // Uses kcal factors 4/4/9 for macros.
    static func guess(for label: String, areaRatio: Double) -> PhotoNutritionGuesser.GuessResult? {
        guard let p = priors[label] else { return nil }

        // Portion scaling: center at ~0.35 area; scale gain adjusts per class sensitivity.
        // Base: 0.70 + 1.0*(area - 0.35); then multiply by class gain.
        let clampedArea = max(0.10, min(0.90, areaRatio))
        let baseScale = 0.70 + 1.00 * (clampedArea - 0.35)
        let scale = max(0.5, min(1.6, baseScale * (0.6 + 0.4 * p.portionScaleGain)))

        var kcal = Int((Double(p.baseKcal) * scale).rounded())
        if let minK = p.minKcal { kcal = max(kcal, minK) }
        if let maxK = p.maxKcal { kcal = min(kcal, maxK) }

        let carbKcal = Double(kcal) * p.carb
        let proteinKcal = Double(kcal) * p.protein
        let fatKcal = Double(kcal) * p.fat

        let carbG = (carbKcal / 4.0).rounded()
        let proteinG = (proteinKcal / 4.0).rounded()
        let fatG = (fatKcal / 9.0).rounded()

        var g = PhotoNutritionGuesser.GuessResult()
        g.calories = max(0, kcal)
        g.carbohydrates = max(0.0, carbG)
        g.protein = max(0.0, proteinG)
        g.fat = max(0.0, fatG)
        return g
    }
}

