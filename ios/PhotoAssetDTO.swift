//
//  PhotoAssetDTO.swift
//  MealTracker
//
//  Codable payloads for future upload.
//

import Foundation
import CoreData

struct PhotoMetadataDTO: Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let width: Int
    let height: Int
    let sha256: String
    let byteSizeOriginal: Int64
    let byteSizeUpload: Int64
    let caption: String?
}

struct PhotoAssetDTO: Codable, Equatable {
    // Metadata plus file name hints for the server
    let metadata: PhotoMetadataDTO
    let originalFileName: String
    let uploadFileName: String
}

extension MealPhoto {
    func toDTO() -> PhotoAssetDTO? {
        guard
            let id = self.id,
            let createdAt = self.createdAt,
            let originalFileName = self.fileNameOriginal,
            let uploadFileName = self.fileNameUpload
        else {
            return nil
        }

        // Prefer a typed String property if your Core Data model exposes it.
        // Current generated properties show `sha256: Bool`, so fall back to KVC until the model is fixed.
        let sha256String: String
        if let s = self.value(forKey: "sha256") as? String {
            sha256String = s
        } else {
            // If the model still has Bool, there is no correct String to send; bail out.
            return nil
        }

        let meta = PhotoMetadataDTO(
            id: id,
            createdAt: createdAt,
            width: Int(width),
            height: Int(height),
            sha256: sha256String,
            byteSizeOriginal: byteSizeOriginal,
            byteSizeUpload: byteSizeUpload,
            caption: nil
        )
        return PhotoAssetDTO(
            metadata: meta,
            originalFileName: originalFileName,
            uploadFileName: uploadFileName
        )
    }
}
