//
//  BarcodeLogStore.swift
//  MealTracker
//
//  DEBUG-only structured log for barcode events, with a legacy string projection for simple views.
//

import Foundation
import Combine

#if DEBUG
actor BarcodeLogStore {
    static let shared = BarcodeLogStore()

    // Structured events
    private var events: [BarcodeLogEvent] = []
    private let capacity: Int = 1000

    // Publisher for UI (structured)
    private let eventsSubject = PassthroughSubject<[BarcodeLogEvent], Never>()
    // Legacy publisher for string lines (derived)
    private let linesSubject = PassthroughSubject<[String], Never>()

    // Public publishers (erased)
    nonisolated var eventsPublisher: AnyPublisher<[BarcodeLogEvent], Never> { eventsSubject.eraseToAnyPublisher() }
    nonisolated var publisher: AnyPublisher<[String], Never> { linesSubject.eraseToAnyPublisher() }

    // Append a structured event
    func appendEvent(_ event: BarcodeLogEvent) {
        events.append(event)
        if events.count > capacity {
            events.removeFirst(events.count - capacity)
        }
        eventsSubject.send(events)
        linesSubject.send(events.map { Self.line(for: $0) })
    }

    // Convenience to append a simple message (kept for existing call sites)
    func append(_ message: String) {
        let evt = BarcodeLogEvent(stage: .offConversion, // neutral stage for freeform
                                  codeRaw: nil,
                                  codeNormalized: nil,
                                  sourceJSON: nil,
                                  conversions: [message],
                                  entry: nil,
                                  error: nil)
        appendEvent(evt)
    }

    // Snapshot helpers
    func snapshot() -> [String] {
        events.map { Self.line(for: $0) }
    }

    func snapshotEvents() -> [BarcodeLogEvent] {
        events
    }

    func clear() {
        events.removeAll(keepingCapacity: true)
        eventsSubject.send(events)
        linesSubject.send([])
    }

    func lineCount() -> Int {
        events.count
    }

    // MARK: - Formatting

    private static func line(for e: BarcodeLogEvent) -> String {
        let df = DateFormatter()
        df.dateFormat = "HH:mm:ss.SSS"
        var parts: [String] = []
        parts.append("[\(df.string(from: e.timestamp))]")
        parts.append(e.stage.rawValue)
        if let c = e.codeNormalized, !c.isEmpty {
            parts.append("code=\(c)")
        } else if let c = e.codeRaw, !c.isEmpty {
            parts.append("raw=\(c)")
        }
        if let err = e.error, !err.isEmpty {
            parts.append("error=\(err)")
        }
        return parts.joined(separator: " ")
    }
}
#endif
