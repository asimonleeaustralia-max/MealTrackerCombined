// NewMealIntent.swift
import AppIntents
import SwiftUI

@available(iOS 16.0, *)
struct NewMealIntent: AppIntent {
    static var title: LocalizedStringResource = "intent_new_meal_title" // Localize later
    static var description = IntentDescription("intent_new_meal_description") // Localize later

    // Display in Shortcuts app
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // Gate by the Settings toggle
        let enabled = UserDefaults.standard.bool(forKey: "openToNewMealOnLaunch")
        guard enabled else {
            // Return a friendly error if user runs an already-added shortcut while disabled
            let message = NSLocalizedString("intent_new_meal_disabled_error", comment: "")
            throw NSError(domain: "MealTracker.NewMealIntent", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }

        // Signal the app to present a fresh MealFormView.
        UserDefaults.standard.set("newMeal", forKey: "launchAction")
        return .result()
    }
}
