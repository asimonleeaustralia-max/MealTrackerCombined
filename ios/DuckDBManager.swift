//
//  DuckDBManager.swift
//  MealTracker
//
//  Manages a local DuckDB database stored in Application Support.
//  - On first launch: copies Barcodes.duckdb from the app bundle if present,
//    otherwise creates an empty DB and initializes schema mirroring LocalBarcodeDB.Entry.
//  - Exposes a serialized connection API for safe use from Swift Concurrency.
//

import Foundation

#if canImport(DuckDB)
import DuckDB

actor DuckDBManager {

    static let shared = DuckDBManager()

    private var database: Database?
    private var connection: Connection?

    // Public entry point to run work with a live connection (serialized in this actor).
    func withConnection<T>(_ body: (Connection) throws -> T) throws -> T {
        if connection == nil {
            try openIfNeeded()
        }
        guard let conn = connection else {
            throw NSError(domain: "DuckDBManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open DuckDB connection"])
        }
        return try body(conn)
    }

    // MARK: - Setup

    private func openIfNeeded() throws {
        if connection != nil { return }

        let dbURL = try databaseURL()

        // If an existing DB is present but on an old schema, delete it (development-friendly migration)
        if FileManager.default.fileExists(atPath: dbURL.path) {
            // Open temporarily to inspect schema
            let tmpDB = try Database(path: dbURL.path)
            let tmpConn = try tmpDB.connect()
            let needsRecreate = try needsSchemaRecreate(conn: tmpConn)
            if needsRecreate {
                // Close temp handles by letting them deinit out of scope and remove file
                try? FileManager.default.removeItem(at: dbURL)
            }
        }

        // If no file at destination and a bundled DB exists, copy it first
        if !FileManager.default.fileExists(atPath: dbURL.path) {
            if let bundled = Bundle.main.url(forResource: "Barcodes", withExtension: "duckdb") {
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

        // Ensure schema exists (in case we copied an older DB)
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
        return dir.appendingPathComponent("Barcodes.duckdb", isDirectory: false)
    }

    private func copyBundledDB(from src: URL, to dst: URL) throws {
        // Ensure parent exists
        let parent = dst.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parent.path) {
            try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        }
        try FileManager.default.copyItem(at: src, to: dst)
    }

    private func createEmptyDB(at url: URL) throws {
        // Opening a non-existent path creates the file
        let db = try Database(path: url.path)
        let conn = try db.connect()
        self.database = db
        self.connection = conn
    }

    // Detect if existing schema uses INTEGER for grams-based columns; if so, trigger recreate
    private func needsSchemaRecreate(conn: Connection) throws -> Bool {
        // Inspect barcodes table columns; if missing or any grams/vitamin/potassium column has wrong type, recreate.
        let pragma = try conn.query("PRAGMA table_info('barcodes');")
        var hasTable = false
        var typeByName: [String: String] = [:]
        while pragma.next() {
            hasTable = true
            let name = (pragma.get("name") as String?)?.lowercased() ?? ""
            let type = (pragma.get("type") as String?)?.uppercased() ?? ""
            if !name.isEmpty {
                typeByName[name] = type
            }
        }
        guard hasTable else { return false } // no table yet, no need to recreate

        // Columns that should be DOUBLE (grams)
        let gramsCols: [String] = [
            "carbohydrates","protein","fat",
            "sugars","starch","fibre",
            "monounsaturatedfat","polyunsaturatedfat","saturatedfat","transfat",
            "animalprotein","plantprotein","proteinsupplements",
            "a2betacasein"
        ]
        for col in gramsCols {
            if let t = typeByName[col], t.contains("INT") {
                return true
            }
        }

        // Vitamins that should now be DOUBLE (mg with decimals preserved)
        let vitaminCols: [String] = ["vitamina","vitaminb","vitaminc","vitamind","vitamine","vitamink"]
        for col in vitaminCols {
            if let t = typeByName[col], t.contains("INT") {
                return true
            }
        }

        // Potassium should now be DOUBLE
        if let t = typeByName["potassium"], t.contains("INT") {
            return true
        }

        return false
    }

    // Create table and index if not present, mirroring LocalBarcodeDB.Entry
    private func initializeSchemaIfNeeded() throws {
        try withConnection { conn in
            let createTableSQL = """
            CREATE TABLE IF NOT EXISTS barcodes (
                code TEXT PRIMARY KEY,
                calories INTEGER,
                carbohydrates DOUBLE,
                protein DOUBLE,
                fat DOUBLE,
                sodiumMg INTEGER,
                sugars DOUBLE,
                starch DOUBLE,
                fibre DOUBLE,
                monounsaturatedFat DOUBLE,
                polyunsaturatedFat DOUBLE,
                saturatedFat DOUBLE,
                transFat DOUBLE,
                animalProtein DOUBLE,
                plantProtein DOUBLE,
                proteinSupplements DOUBLE,
                a2BetaCasein DOUBLE,
                vitaminA DOUBLE,
                vitaminB DOUBLE,
                vitaminC DOUBLE,
                vitaminD DOUBLE,
                vitaminE DOUBLE,
                vitaminK DOUBLE,
                calcium INTEGER,
                iron INTEGER,
                potassium DOUBLE,
                zinc INTEGER,
                magnesium INTEGER
            );
            """
            _ = try conn.query(createTableSQL)

            let createIndexSQL = """
            CREATE INDEX IF NOT EXISTS idx_barcodes_code ON barcodes(code);
            """
            _ = try conn.query(createIndexSQL)
        }
    }
}

#else

// Fallback stub so targets without the DuckDB package still build.
actor DuckDBManager {
    static let shared = DuckDBManager()

    struct Connection {}

    func withConnection<T>(_ body: (Connection) throws -> T) throws -> T {
        throw NSError(domain: "DuckDBManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "DuckDB is not available in this target"])
    }
}

#endif

