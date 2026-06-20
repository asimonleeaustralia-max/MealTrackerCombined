//
//  PhotoStore.swift
//  MealTracker
//
//  Manages file locations for original and resized upload images.
//

import Foundation

struct PhotoStore {
    enum Kind: String {
        case original = "original"
        case upload = "upload"
    }

    // Base directory inside Documents to make backup/inspection easy.
    // You can change to Application Support if you prefer.
    static func baseDirectory() throws -> URL {
        let docs = try FileManager.default.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = docs.appendingPathComponent("MealPhotos", isDirectory: true)
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static func fileURL(fileName: String) throws -> URL {
        try baseDirectory().appendingPathComponent(fileName, isDirectory: false)
    }

    static func makeFileName(id: UUID, kind: Kind, ext: String) -> String {
        "\(id.uuidString)_\(kind.rawValue).\(ext)"
    }

    static func removeFilesIfExist(original: String?, upload: String?) {
        let fm = FileManager.default
        func remove(_ name: String?) {
            guard let name, let url = try? fileURL(fileName: name) else { return }
            _ = try? fm.removeItem(at: url)
        }
        remove(original)
        remove(upload)
    }

    static func fileSizeBytes(at url: URL) -> Int64 {
        (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) } ?? 0
    }
}

