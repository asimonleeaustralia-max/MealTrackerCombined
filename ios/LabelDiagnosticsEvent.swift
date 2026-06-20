//
//  LabelDiagnosticsEvent.swift
//  MealTracker
//
//  DEBUG-only structured events for label recognition diagnostics:
//  image prep, rotations, barcode attempts, OCR, parsing, apply-to-form, and upsert.
//

import Foundation

#if DEBUG

enum LabelDiagStage: String, Codable, Sendable {
    case analyzeStart
    case imagePrepared

    case rotationAttempt            // metadata: rotation index (0,90,180,270)
    case barcodeDecoded             // metadata: code
    case barcodeUnreadable
    case barcodeNone

    case ocrStartFast
    case ocrStartAccurate
    case ocrFinished                // metadata: textLength

    case parseResult                // metadata: parsedFieldCount

    case applyToForm                // metadata: fieldsFilled (comma-separated)

    case ocrUpsertAttempt           // metadata: key
    case ocrUpsertSuccess
    case ocrUpsertFailure

    case analyzeComplete
    case analyzeError
}

struct LabelDiagnosticsEvent: Codable, Sendable, Identifiable {
    let id: UUID
    let timestamp: Date
    let stage: LabelDiagStage

    // Optional metadata fields used by different stages
    let rotationDegrees: Int?
    let code: String?
    let textLength: Int?
    let parsedFieldCount: Int?
    let fieldsFilled: [String]?
    let upsertKey: String?

    // Optional freeform message
    let message: String?

    init(stage: LabelDiagStage,
         rotationDegrees: Int? = nil,
         code: String? = nil,
         textLength: Int? = nil,
         parsedFieldCount: Int? = nil,
         fieldsFilled: [String]? = nil,
         upsertKey: String? = nil,
         message: String? = nil) {
        self.id = UUID()
        self.timestamp = Date()
        self.stage = stage
        self.rotationDegrees = rotationDegrees
        self.code = code
        self.textLength = textLength
        self.parsedFieldCount = parsedFieldCount
        self.fieldsFilled = fieldsFilled
        self.upsertKey = upsertKey
        self.message = message
    }
}

#endif
