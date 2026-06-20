import AppIntents
import Foundation

@available(iOS 16.0, *)
struct MealTrackerAppShortcuts: AppShortcutsProvider {

    static var shortcutTileColor: ShortcutTileColor = .orange

    static var appShortcuts: [AppShortcut] {
        // Always publish the shortcut so it appears in Shortcuts.
        // Runtime gating remains inside NewMealIntent.perform().
        return [
            AppShortcut(
                intent: NewMealIntent(),
                phrases: [
                    "New Meal in \(.applicationName)",
                    "Add meal in \(.applicationName)",
                    "Log meal in \(.applicationName)"
                ],
                shortTitle: LocalizedStringResource("intent_new_meal_title"),
                systemImageName: "plus.circle.fill"
            )
        ]
    }
}
