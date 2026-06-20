//
//  LabelDiagnosticsStore.swift
//  MealTracker
//
//  DEBUG-only structured diagnostics store for label recognition.
//  Now persists events to disk (JSON Lines) and reloads them on init.
//

import Foundation
import Combine

#if DEBUG
actor LabelDiagnosticsStore {
    static let shared = LabelDiagnosticsStore()

    // In-memory buffer (bounded)
    private var events: [LabelDiagnosticsEvent] = []
    private let capacity: Int = 1000

    // Publisher for UI
    private let eventsSubject = PassthroughSubject<[LabelDiagnosticsEvent], Never>()
    nonisolated var eventsPublisher: AnyPublisher<[LabelDiagnosticsEvent], Never> { eventsSubject.eraseToAnyPublisher() }

    // File persistence (JSON Lines: one JSON object per line)
    private let fileURL: URL
    private let ioQueue = DispatchQueue(label: "LabelDiagnosticsStore.IO")

    // JSON Encoder/Decoder
    private let encoder: JSONEncoder = {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.sortedKeys] // compact lines
        return enc
    }()

    private let decoder: JSONDecoder = {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        return dec
    }()

    init() {
        // Compute file URL under Application Support
        self.fileURL = LabelDiagnosticsStore.makeEventsFileURL()

        // Ensure directory exists
        ensureDirectoryExists(url: fileURL.deletingLastPathComponent())

        // Load on init (best-effort)
        let loaded = loadFromDisk()
        // Enforce capacity on load (keep most recent)
        if loaded.count > capacity {
            self.events = Array(loaded.suffix(capacity))
        } else {
            self.events = loaded
        }
        // Publish initial snapshot to any late subscribers
        eventsSubject.send(self.events)
    }

    func appendEvent(_ event: LabelDiagnosticsEvent) {
        // In-memory buffer
        events.append(event)
        if events.count > capacity {
            events.removeFirst(events.count - capacity)
        }
        // Publish
        eventsSubject.send(events)
        // Persist append to disk (fire-and-forget)
        appendToDisk(event)
    }

    func snapshotEvents() -> [LabelDiagnosticsEvent] {
        events
    }

    func clear() {
        events.removeAll(keepingCapacity: true)
        eventsSubject.send(events)
        // Truncate file
        truncateFile()
    }

    func lineCount() -> Int {
        events.count
    }
}

// MARK: - File Persistence (JSON Lines)

#if DEBUG
private extension LabelDiagnosticsStore {
    static func makeEventsFileURL() -> URL {
        // ~/Library/Application Support/<bundle-id>/LabelDiagnostics/events.jsonl
        let fm = FileManager.default
        let baseDir: URL
        if let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
            baseDir = appSupport
        } else {
            baseDir = fm.temporaryDirectory
        }

        let bundleID = Bundle.main.bundleIdentifier ?? "MealTracker"
        let dir = baseDir.appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("LabelDiagnostics", isDirectory: true)

        // Avoid UTType dependency; plain path component is fine here.
        return dir.appendingPathComponent("events.jsonl")
    }

    func ensureDirectoryExists(url: URL) {
        let fm = FileManager.default
        if !fm.fileExists(atPath: url.path) {
            try? fm.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        }
    }

    func loadFromDisk() -> [LabelDiagnosticsEvent] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: fileURL.path) else { return [] }

        // Read entire file and decode line-by-line
        guard let data = try? Data(contentsOf: fileURL),
              let text = String(data: data, encoding: .utf8) else {
            return []
        }

        var loaded: [LabelDiagnosticsEvent] = []
        loaded.reserveCapacity(256)

        for line in text.split(whereSeparator: \.isNewline) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, let lineData = trimmed.data(using: .utf8) else { continue }
            if let evt = try? decoder.decode(LabelDiagnosticsEvent.self, from: lineData) {
                loaded.append(evt)
            }
        }
        return loaded
    }

    func appendToDisk(_ event: LabelDiagnosticsEvent) {
        // Serialize once on the actor thread
        guard let data = try? encoder.encode(event),
              var line = String(data: data, encoding: .utf8) else {
            return
        }
        line.append("\n")

        // Dispatch actual I/O off the actor to avoid blocking
        ioQueue.async { [fileURL] in
            if let handle = try? FileHandle(forWritingTo: fileURL) {
                defer { try? handle.close() }
                do {
                    try handle.seekToEnd()
                    if let d = line.data(using: .utf8) {
                        try handle.write(contentsOf: d)
                    }
                } catch {
                    // If append fails (e.g., file removed), try recreate and write fresh
                    try? line.data(using: .utf8)?.write(to: fileURL, options: .atomic)
                }
            } else {
                // File doesn't exist yet; create with this first line
                try? line.data(using: .utf8)?.write(to: fileURL, options: .atomic)
            }
        }
    }

    func truncateFile() {
        ioQueue.async { [fileURL] in
            // Replace with empty file
            try? Data().write(to: fileURL, options: .atomic)
        }
    }
}
#endif
#endif
