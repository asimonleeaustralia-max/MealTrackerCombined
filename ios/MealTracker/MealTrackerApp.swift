//
//  MealTrackerApp.swift
//  MealTracker
//
//  Created by Simon Lee on 17/11/2025.
//

import SwiftUI
import CoreData
import UIKit

@main
struct MealTrackerApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var session = SessionManager()
    @Environment(\.scenePhase) private var scenePhase

    // New: transient launch action flag used by AppIntent routing
    @AppStorage("launchAction") private var launchAction: String?

    // Presentation control
    @State private var presentNewMealSheet: Bool = false

    init() {
        // Register default settings (does not overwrite user-changed values)
        UserDefaults.standard.register(defaults: [
            "aiFeaturesEnabled": true
        ])

        // One-time migration: assign UUIDs to any Meal rows missing an id
        let context = persistenceController.container.viewContext
        context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Meal")
            request.predicate = NSPredicate(format: "id == nil")
            if let rows = try? context.fetch(request), !rows.isEmpty {
                for obj in rows {
                    // Use KVC to avoid reading a non-optional Swift property
                    obj.setValue(UUID(), forKey: "id")
                    if obj.value(forKey: "date") == nil {
                        obj.setValue(Date(), forKey: "date")
                    }
                }
                if context.hasChanges {
                    try? context.save()
                }
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if #available(iOS 16.0, *) {
                    NavigationStack {
                        MealsRootView()
                            .sheet(isPresented: $presentNewMealSheet) {
                                // Always present a fresh new-meal form
                                NavigationView {
                                    MealFormView()
                                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                                        .environmentObject(session)
                                }
                                .accessibilityIdentifier("newMealSheet")
                            }
                            .onAppear {
                                // Respect AppIntent flag if present
                                if launchAction == "newMeal" {
                                    presentNewMealSheet = true
                                    launchAction = nil
                                }
                            }
                            .onChange(of: scenePhase) { phase in
                                if phase == .active {
                                    // Handle coming to foreground via intent
                                    if launchAction == "newMeal" {
                                        presentNewMealSheet = true
                                        launchAction = nil
                                    }
                                } else if phase == .background {
                                    let context = persistenceController.container.viewContext
                                    if context.hasChanges {
                                        try? context.save()
                                    }
                                }
                            }
                    }
                } else {
                    NavigationView {
                        MealsRootView()
                            .sheet(isPresented: $presentNewMealSheet) {
                                // FIX: wrap MealFormView in a NavigationView on iOS 15 as well
                                NavigationView {
                                    MealFormView()
                                        .environment(\.managedObjectContext, persistenceController.container.viewContext)
                                        .environmentObject(session)
                                }
                                .accessibilityIdentifier("newMealSheet")
                            }
                            .onAppear {
                                // Respect AppIntent flag if present
                                if launchAction == "newMeal" {
                                    presentNewMealSheet = true
                                    launchAction = nil
                                }
                            }
                            .onChange(of: scenePhase) { phase in
                                if phase == .active {
                                    if launchAction == "newMeal" {
                                        presentNewMealSheet = true
                                        launchAction = nil
                                    }
                                } else if phase == .background {
                                    let context = persistenceController.container.viewContext
                                    if context.hasChanges {
                                        try? context.save()
                                    }
                                }
                            }
                    }
                }
            }
            .environment(\.managedObjectContext, persistenceController.container.viewContext)
            .environmentObject(session)
            .task {
                // Wire the sync engine to the Core Data stack and restore any saved session.
                SyncCoordinator.shared.configure(container: persistenceController.container)
                await session.restoreSession()
            }
        }
    }
}

// A simple root to keep the main stack clean.
// Updated: show the MealsGalleryView so after saving (and dismissing the sheet) we land on the gallery.
private struct MealsRootView: View {
    var body: some View {
        MealsGalleryView()
    }
}
