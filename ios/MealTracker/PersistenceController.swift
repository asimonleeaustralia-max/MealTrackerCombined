//
//  PersistenceController.swift
//  MealTracker
//
//  Created by Simon Lee on 17/11/2025.
//

import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        let container = NSPersistentContainer(name: "MealTracker")

        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("No persistent store description found.")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
        }

        // Enable lightweight migration attempts
        description.shouldMigrateStoreAutomatically = true
        description.shouldInferMappingModelAutomatically = true

        // Preflight compatibility (on-disk only) and nuke in Debug if incompatible
        if !inMemory, let storeURL = description.url {
            do {
                let metadata = try NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType,
                                                                                           at: storeURL,
                                                                                           options: description.options)
                let compatible = container.managedObjectModel
                    .isConfiguration(withName: description.configuration, compatibleWithStoreMetadata: metadata)
                #if DEBUG
                if !compatible {
                    try container.persistentStoreCoordinator.destroyPersistentStore(at: storeURL,
                                                                                    ofType: NSSQLiteStoreType,
                                                                                    options: description.options)
                }
                #endif
            } catch {
                // If metadata can't be read, continue; we'll also handle failure in load below.
            }
        }

        // Important: avoid capturing self in the escaping closure during init.
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                #if DEBUG
                // Development fallback: destroy incompatible store and retry once
                if let url = storeDescription.url {
                    do {
                        try container.persistentStoreCoordinator.destroyPersistentStore(at: url,
                                                                                        ofType: NSSQLiteStoreType,
                                                                                        options: storeDescription.options)
                        container.loadPersistentStores { _, retryError in
                            if let retryError = retryError {
                                let nserr = retryError as NSError
                                fatalError("Unresolved error after destroying store: \(nserr), \(nserr.userInfo)")
                            }
                            // After successful retry load, ensure default Person exists.
                            ensureDefaultPersonExistsAndIsUnique(on: container.viewContext)
                        }
                        return
                    } catch {
                        let nserr = error as NSError
                        fatalError("Unresolved error \(nserr), \(nserr.userInfo)")
                    }
                }
                #endif
                fatalError("Unresolved error \(error), \((error as NSError).userInfo)")
            }

            // After successful load, ensure default Person exists/unique.
            ensureDefaultPersonExistsAndIsUnique(on: container.viewContext)
        }

        // Recommended context settings
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        container.viewContext.automaticallyMergesChangesFromParent = true

        // Assign to property last
        self.container = container
    }
}

// MARK: - Seeding and enforcement of default Person

private func ensureDefaultPersonExistsAndIsUnique(on context: NSManagedObjectContext) {
    context.perform {
        // Fetch all Person rows (both active and removed) to reconcile state
        let fetch = NSFetchRequest<NSManagedObject>(entityName: "Person")
        fetch.includesPendingChanges = true
        fetch.includesSubentities = false

        let persons: [NSManagedObject]
        do {
            persons = try context.fetch(fetch)
        } catch {
            // If fetch fails, do nothing to avoid crashing; try again next launch.
            return
        }

        var didChange = false

        // Partition into active (non-removed) and removed
        let active = persons.filter { ($0.value(forKey: "isRemoved") as? Bool) != true }
        let removed = persons.filter { ($0.value(forKey: "isRemoved") as? Bool) == true }

        // Ensure removed persons are never marked as default
        for obj in removed {
            if (obj.value(forKey: "isDefault") as? Bool) == true {
                obj.setValue(false, forKey: "isDefault")
                didChange = true
            }
        }

        if active.isEmpty {
            // Seed a new default Person if none active exist
            guard let entity = NSEntityDescription.entity(forEntityName: "Person", in: context) else {
                return
            }
            let obj = NSManagedObject(entity: entity, insertInto: context)
            obj.setValue(UUID(), forKey: "id")
            // Localizable default name (fallback to "Me" if key missing)
            let defaultName = NSLocalizedString("default_person_name_me", comment: "Default person name for device owner")
            obj.setValue(defaultName == "default_person_name_me" ? "Me" : defaultName, forKey: "name")
            obj.setValue(true, forKey: "isDefault")
            obj.setValue(false, forKey: "isRemoved")
            didChange = true
        } else {
            // Enforce exactly one default among active persons
            let defaultsActive = active.filter { ($0.value(forKey: "isDefault") as? Bool) == true }
            if defaultsActive.isEmpty {
                if let first = active.first {
                    first.setValue(true, forKey: "isDefault")
                    didChange = true
                }
            } else if defaultsActive.count > 1 {
                for obj in defaultsActive.dropFirst() {
                    obj.setValue(false, forKey: "isDefault")
                    didChange = true
                }
            }
        }

        if didChange && context.hasChanges {
            _ = try? context.save()
        }
    }
}

