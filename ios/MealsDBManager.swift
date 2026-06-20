//
//  MealsDBManager.swift
//  MealTracker
//
//  Manages a local Meals.duckdb database stored in Application Support.
//  - On first launch: copies Meals.duckdb from the app bundle if present,
//    otherwise creates an empty DB and initializes the meals schema.
//  - Exposes a serialized connection API for safe use with Swift Concurrency.
//

import Foundation

#if canImport(DuckDB)
import DuckDB

actor MealsDBManager {

    static let shared = MealsDBManager()

    private var database: Database?
    private var connection: Connection?

    // Public entry point to run work with a live connection (serialized in this actor).
    func withConnection<T>(_ body: (Connection) throws -> T) throws -> T {
        if connection == nil {
            try openIfNeeded()
        }
        guard let conn = connection else {
            // Localized error key for connection open failure
            let message = NSLocalizedString("duckdb_connection_open_failed", comment: "Shown when the app cannot open the Meals.duckdb connection")
            throw NSError(domain: "MealsDBManager", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
        }
        return try body(conn)
    }

    // MARK: - Public helpers for file info

    // Returns the URL to Meals.duckdb (creates parent directories if needed).
    func databaseFileURL() throws -> URL {
        try databaseURL()
    }

    // True if Meals.duckdb exists on disk.
    func databaseFileExists() -> Bool {
        if let url = try? databaseURL() {
            return FileManager.default.fileExists(atPath: url.path)
        }
        return false
    }

    // Returns the byte size of Meals.duckdb if it exists; 0 otherwise.
    func databaseFileSizeBytes() -> Int64 {
        guard let url = try? databaseURL() else { return 0 }
        let vals = try? url.resourceValues(forKeys: [.fileSizeKey])
        if let bytes = vals?.fileSize { return Int64(bytes) }
        return 0
    }

    // New: Close any open handles and delete the Meals.duckdb file if it exists.
    func deleteDatabaseFileIfExists() {
        // Drop references so DuckDB closes the file when these are deinited.
        connection = nil
        database = nil

        guard let url = try? databaseURL() else { return }
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Setup

    private func openIfNeeded() throws {
        if connection != nil { return }

        let dbURL = try databaseURL()
        // If no file at destination and a bundled DB exists, copy it first
        if !FileManager.default.fileExists(atPath: dbURL.path) {
            if let bundled = Bundle.main.url(forResource: "Meals", withExtension: "duckdb") {
                try copyBundledDB(from: bundled, to: dbURL)
            } else {
                // Create empty DB and initialize schema
                try createEmptyDB(at: dbURL)
                try initializeSchemaIfNeeded()
            }
        }

        // Open database
        let db = try Database(path: dbURL.path)
        let conn = try db.connect()
        self.database = db
        self.connection = conn

        // Ensure schema exists (in case we copied an older DB missing columns)
        try initializeSchemaIfNeeded()
    }

    private func databaseURL() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = base.appendingPathComponent("Databases", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir.appendingPathComponent("Meals.duckdb", isDirectory: false)
    }

    private func copyBundledDB(from src: URL, to dst: URL) throws {
        // Ensure parent exists
        let parent = dst.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parent.path) {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        try FileManager.default.copyItem(at: src, to: dst)
        // Exclude from iCloud backup
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mod = dst
        try? mod.setResourceValues(values)
    }

    private func createEmptyDB(at url: URL) throws {
        // Opening a non-existent path creates the file
        let db = try Database(path: url.path)
        let conn = try db.connect()
        self.database = db
        self.connection = conn
        // Exclude from iCloud backup
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mod = url
        try? mod.setResourceValues(values)
    }

    // Create meals table and indexes if not present.
    // Includes ALL metrics from Meal.swift plus title, description, portion_grams.
    private func initializeSchemaIfNeeded() throws {
        try withConnection { conn in
            let createTableSQL = """
            CREATE TABLE IF NOT EXISTS meals (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                title TEXT NOT NULL,
                description TEXT,
                portion_grams DOUBLE NOT NULL,

                calories DOUBLE,
                carbohydrates DOUBLE,
                protein DOUBLE,
                sodium DOUBLE,
                fat DOUBLE,

                latitude DOUBLE,
                longitude DOUBLE,

                alcohol DOUBLE,
                nicotine DOUBLE,
                theobromine DOUBLE,
                caffeine DOUBLE,
                taurine DOUBLE,

                starch DOUBLE,
                sugars DOUBLE,
                fibre DOUBLE,

                monounsaturatedFat DOUBLE,
                polyunsaturatedFat DOUBLE,
                saturatedFat DOUBLE,
                transFat DOUBLE,
                omega3 DOUBLE,
                omega6 DOUBLE,

                animalProtein DOUBLE,
                plantProtein DOUBLE,
                proteinSupplements DOUBLE,

                vitaminA DOUBLE,
                vitaminB DOUBLE,
                vitaminC DOUBLE,
                vitaminD DOUBLE,
                vitaminE DOUBLE,
                vitaminK DOUBLE,

                calcium DOUBLE,
                iron DOUBLE,
                potassium DOUBLE,
                zinc DOUBLE,
                magnesium DOUBLE
            );
            """
            _ = try conn.query(createTableSQL)

            let createIdxTitle = """
            CREATE INDEX IF NOT EXISTS idx_meals_title ON meals(title);
            """
            _ = try conn.query(createIdxTitle)

            // Optional: lightweight index on portion size for quick filtering
            let createIdxPortion = """
            CREATE INDEX IF NOT EXISTS idx_meals_portion ON meals(portion_grams);
            """
            _ = try conn.query(createIdxPortion)
        }
    }
}

#else

// Fallback stub so targets without the DuckDB package still build.
actor MealsDBManager {
    static let shared = MealsDBManager()

    struct Connection {}

    func withConnection<T>(_ body: (Connection) throws -> T) throws -> T {
        let message = NSLocalizedString("duckdb_unavailable_target_error", comment: "Shown when DuckDB is not available in this build target")
        throw NSError(domain: "MealsDBManager", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    // Stubs for file info
    func databaseFileURL() throws -> URL {
        let message = NSLocalizedString("duckdb_unavailable_target_error", comment: "Shown when DuckDB is not available in this build target")
        throw NSError(domain: "MealsDBManager", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
    }
    func databaseFileExists() -> Bool { false }
    func databaseFileSizeBytes() -> Int64 { 0 }

    // Stub delete for non-DuckDB targets
    func deleteDatabaseFileIfExists() { }
}

#endif
