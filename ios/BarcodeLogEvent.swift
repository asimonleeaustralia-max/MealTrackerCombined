//
//  BarcodeLogEvent.swift
//  MealTracker
//
//  DEBUG-only structured events for barcode logging: source payloads, conversions, and upsert snapshots.
//

import Foundation

#if DEBUG

enum BarcodeLogStage: String, Codable, Sendable {
    case scanDetected
    case normalizeCode
    case localLookupHit
    case localLookupMiss
    case offFetchV2
    case offFetchV1
    case offDecodeError
    case offMapStart
    case offConversion
    case offMapResult
    case upsertAttempt
    case upsertSuccess
    case upsertFailure
}

struct BarcodeLogEvent: Codable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let stage: BarcodeLogStage

    // Codes
    let codeRaw: String?
    let codeNormalized: String?

    // Optional source payload (JSON-encodable dictionary or model fragment)
    let sourceJSON: String?

    // Human-readable conversion steps performed during OFF -> Entry mapping
    let conversions: [String]?

    // Final entry snapshot to be upserted
    let entry: LocalBarcodeDB.Entry?

    // Error text if any
    let error: String?

    init(stage: BarcodeLogStage,
         codeRaw: String? = nil,
         codeNormalized: String? = nil,
         sourceJSON: String? = nil,
         conversions: [String]? = nil,
         entry: LocalBarcodeDB.Entry? = nil,
         error: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.stage = stage
        self.codeRaw = codeRaw
        self.codeNormalized = codeNormalized
        self.sourceJSON = sourceJSON
        self.conversions = conversions
        self.entry = entry
        self.error = error
    }
}

// Pretty-print helpers
enum BarcodeLogPretty {
    static func jsonString<T: Encodable>(_ value: T) -> String? {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(value) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    static func compactJSON<T: Encodable>(_ value: T) -> String? {
        let enc = JSONEncoder()
        enc.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        enc.dateEncodingStrategy = .iso8601
        if let data = try? enc.encode(value) {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }

    static func prettyEntry(_ entry: LocalBarcodeDB.Entry) -> String? {
        jsonString(entry)
    }
}

#endif
