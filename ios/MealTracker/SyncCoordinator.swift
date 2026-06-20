//
//  SyncCoordinator.swift
//  MealTracker
//
//  Orchestrates two-way sync of meals and people between the local Core Data store and
//  the meal-tracker-web backend, using a simple last-write-wins, incremental-pull model:
//
//    • PUSH  – local meals whose `lastSyncGUID` is nil (new or locally edited) are PUT to
//              the server; queued local deletions are sent as DELETEs.
//    • PULL  – `GET /api/sync/changes?since=cursor` returns everything changed since the
//              last cursor; rows are upserted locally and tombstones (deleted_at) remove
//              the local copy. `server_time` becomes the next cursor.
//
//  The set of synced fields is defined entirely by `MealFieldManifest`, generated from the
//  Core Data model, so every food metric stays in sync with the web app automatically.
//

import Foundation
import CoreData
import Combine

@MainActor
final class SyncCoordinator: ObservableObject {
    static let shared = SyncCoordinator()

    @Published private(set) var isSyncing = false
    @Published private(set) var lastSyncDate: Date?
    @Published var lastError: String?

    private var container: NSPersistentContainer?
    private let api = MealTrackerAPI.shared
    private var debounceTask: Task<Void, Never>?

    private let cursorKey = "mealSyncCursorISO8601"
    private let lastSyncKey = "mealLastSyncDateISO8601"
    private let pendingDeletesKey = "pendingMealDeleteIDs"
    private let personSignaturesKey = "syncedPersonSignatures"

    private init() {}

    // MARK: - Setup

    func configure(container: NSPersistentContainer) {
        self.container = container
        if let s = UserDefaults.standard.string(forKey: lastSyncKey) {
            lastSyncDate = CloudDate.parse(s)
        }
    }

    // MARK: - Triggers

    /// Debounced sync request — safe to call after every local change.
    func requestSync() {
        guard TokenStore.hasSession else { return }
        debounceTask?.cancel()
        debounceTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s debounce
            if Task.isCancelled { return }
            await self?.syncNow()
        }
    }

    /// Record a local meal deletion to propagate to the cloud on the next sync.
    func enqueueMealDelete(_ id: UUID) {
        var ids = Set(UserDefaults.standard.stringArray(forKey: pendingDeletesKey) ?? [])
        ids.insert(id.uuidString)
        UserDefaults.standard.set(Array(ids), forKey: pendingDeletesKey)
        requestSync()
    }

    // MARK: - Full sync

    func syncNow() async {
        guard let container, TokenStore.hasSession, !isSyncing else { return }
        isSyncing = true
        lastError = nil
        defer { isSyncing = false }

        let ctx = container.newBackgroundContext()
        ctx.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        do {
            try await pushPendingDeletes()
            try await pushPeople(ctx)
            try await pushDirtyMeals(ctx)
            try await pullChanges(ctx)

            let now = Date()
            lastSyncDate = now
            UserDefaults.standard.set(CloudDate.string(from: now), forKey: lastSyncKey)
        } catch {
            lastError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    // MARK: - Push: deletes

    private func pushPendingDeletes() async throws {
        var ids = Set(UserDefaults.standard.stringArray(forKey: pendingDeletesKey) ?? [])
        guard !ids.isEmpty else { return }
        for idString in ids {
            guard let uuid = UUID(uuidString: idString) else { ids.remove(idString); continue }
            do {
                try await api.deleteMeal(id: uuid)
                ids.remove(idString)
            } catch APIError.http(status: 404, _) {
                ids.remove(idString) // already gone server-side
            }
        }
        UserDefaults.standard.set(Array(ids), forKey: pendingDeletesKey)
    }

    // MARK: - Push: people

    private struct PersonSnapshot { let id: UUID; let name: String; let isDefault: Bool; let isRemoved: Bool }

    private func pushPeople(_ ctx: NSManagedObjectContext) async throws {
        let snapshots: [PersonSnapshot] = try await ctx.perform {
            let request = NSFetchRequest<NSManagedObject>(entityName: "Person")
            request.predicate = NSPredicate(format: "isRemoved == NO")
            let rows = try ctx.fetch(request)
            return rows.compactMap { row -> PersonSnapshot? in
                guard let id = row.value(forKey: "id") as? UUID else { return nil }
                return PersonSnapshot(
                    id: id,
                    name: (row.value(forKey: "name") as? String) ?? "Me",
                    isDefault: (row.value(forKey: "isDefault") as? Bool) ?? false,
                    isRemoved: (row.value(forKey: "isRemoved") as? Bool) ?? false
                )
            }
        }

        var signatures = UserDefaults.standard.dictionary(forKey: personSignaturesKey) as? [String: String] ?? [:]
        // Push default person first so it wins any default-person reconciliation server-side.
        for p in snapshots.sorted(by: { $0.isDefault && !$1.isDefault }) {
            let signature = "\(p.name)|\(p.isDefault)|\(p.isRemoved)"
            if signatures[p.id.uuidString] == signature { continue }
            let dto = PersonDTO(id: p.id.uuidString, name: p.name,
                                isDefault: p.isDefault, isRemoved: p.isRemoved, deletedAt: nil)
            _ = try await api.putPerson(dto)
            signatures[p.id.uuidString] = signature
        }
        UserDefaults.standard.set(signatures, forKey: personSignaturesKey)
    }

    // MARK: - Push: dirty meals

    private func pushDirtyMeals(_ ctx: NSManagedObjectContext) async throws {
        // Snapshot dirty meals (lastSyncGUID == nil) as value-type request bodies.
        let bodies: [(id: UUID, body: [String: Any])] = try await ctx.perform {
            let request = NSFetchRequest<Meal>(entityName: "Meal")
            request.predicate = NSPredicate(format: "lastSyncGUID == nil")

            // Build a meal -> personID map from the Person.meal relationship.
            let peopleReq = NSFetchRequest<NSManagedObject>(entityName: "Person")
            let people = (try? ctx.fetch(peopleReq)) ?? []
            func personID(for meal: Meal) -> UUID? {
                for person in people {
                    if let set = person.value(forKey: "meal") as? Set<Meal>, set.contains(meal) {
                        return person.value(forKey: "id") as? UUID
                    }
                }
                return nil
            }

            let meals = try ctx.fetch(request)
            return meals.map { meal in
                (id: meal.id, body: MealCodec.requestBody(for: meal, personID: personID(for: meal)))
            }
        }

        for item in bodies {
            let saved = try await api.putMeal(id: item.id, body: item.body)
            let guid = saved["last_sync_guid"] as? String
            try await ctx.perform {
                let request = NSFetchRequest<Meal>(entityName: "Meal")
                request.predicate = NSPredicate(format: "id == %@", item.id as NSUUID)
                request.fetchLimit = 1
                if let meal = try ctx.fetch(request).first {
                    meal.lastSyncGUID = guid   // mark clean so we don't echo it back
                    try ctx.save()
                }
            }
        }
    }

    // MARK: - Pull

    private func pullChanges(_ ctx: NSManagedObjectContext) async throws {
        let since = UserDefaults.standard.string(forKey: cursorKey)
            .flatMap(CloudDate.parse) ?? Date(timeIntervalSince1970: 0)

        let changes = try await api.syncChanges(since: since)

        try await ctx.perform {
            // People first so meal person_id references resolve.
            for dto in changes.people {
                guard let idString = dto.id, let id = UUID(uuidString: idString) else { continue }
                let person = Self.fetchOrCreatePerson(id: id, in: ctx)
                person.setValue(dto.name, forKey: "name")
                person.setValue(dto.isDefault, forKey: "isDefault")
                person.setValue(dto.isRemoved, forKey: "isRemoved")
            }

            for mealJSON in changes.meals {
                guard let id = MealCodec.id(of: mealJSON) else { continue }

                if MealCodec.isTombstone(mealJSON) {
                    if let meal = Self.fetchMeal(id: id, in: ctx) { ctx.delete(meal) }
                    continue
                }

                let meal = Self.fetchOrCreateMeal(id: id, in: ctx)
                let guid = MealCodec.apply(mealJSON, to: meal)
                meal.lastSyncGUID = guid // freshly pulled rows are clean

                if let personID = MealCodec.personID(of: mealJSON),
                   let person = Self.fetchPerson(id: personID, in: ctx) {
                    // `meal` is a to-many relationship on Person (no inverse); mutate via KVC.
                    person.mutableSetValue(forKey: "meal").add(meal)
                }
            }

            if ctx.hasChanges { try ctx.save() }
        }

        UserDefaults.standard.set(CloudDate.string(from: changes.serverTime), forKey: cursorKey)
    }

    // MARK: - Core Data lookup helpers

    private static func fetchMeal(id: UUID, in ctx: NSManagedObjectContext) -> Meal? {
        let request = NSFetchRequest<Meal>(entityName: "Meal")
        request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        request.fetchLimit = 1
        return try? ctx.fetch(request).first
    }

    private static func fetchOrCreateMeal(id: UUID, in ctx: NSManagedObjectContext) -> Meal {
        if let existing = fetchMeal(id: id, in: ctx) { return existing }
        let meal = Meal(context: ctx)
        meal.id = id
        return meal
    }

    private static func fetchPerson(id: UUID, in ctx: NSManagedObjectContext) -> NSManagedObject? {
        let request = NSFetchRequest<NSManagedObject>(entityName: "Person")
        request.predicate = NSPredicate(format: "id == %@", id as NSUUID)
        request.fetchLimit = 1
        return try? ctx.fetch(request).first
    }

    private static func fetchOrCreatePerson(id: UUID, in ctx: NSManagedObjectContext) -> NSManagedObject {
        if let existing = fetchPerson(id: id, in: ctx) { return existing }
        let person = NSEntityDescription.insertNewObject(forEntityName: "Person", into: ctx)
        person.setValue(id, forKey: "id")
        return person
    }

    // MARK: - Reset (called on logout)

    func resetSyncState() {
        debounceTask?.cancel()
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: cursorKey)
        defaults.removeObject(forKey: lastSyncKey)
        defaults.removeObject(forKey: pendingDeletesKey)
        defaults.removeObject(forKey: personSignaturesKey)
        lastSyncDate = nil
        lastError = nil
    }
}
