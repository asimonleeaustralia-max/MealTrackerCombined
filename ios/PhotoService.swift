//
//  PhotoService.swift
//  MealTracker
//
//  High-level API to attach photos to meals, save originals at camera quality,
//  and produce 1080p medium-compression JPEGs for upload.
//

import UIKit
import CoreData

enum PhotoServiceError: Error, LocalizedError {
    case invalidImage
    case writeFailed
    case coreDataSaveFailed(Error)
    case freeTierPhotoLimitReached(max: Int)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return NSLocalizedString("invalid_image_error", comment: "")
        case .writeFailed:
            return NSLocalizedString("write_failed_error", comment: "")
        case .coreDataSaveFailed(let err):
            let prefix = NSLocalizedString("coredata_save_failed_error_prefix", comment: "")
            return "\(prefix) \(err.localizedDescription)"
        case .freeTierPhotoLimitReached(let max):
            // Use %d in Localizable; String(format:) to inject the number
            let fmt = NSLocalizedString("free_tier_photo_limit_reached", comment: "")
            return String(format: fmt, max)
        }
    }
}

struct PhotoService {

    // Add a photo to a meal.
    // - Stores the original JPEG/HEIC bytes as-is (camera quality) without recompression.
    // - Creates an upload-sized JPEG (max long edge 1080 px, quality ~0.72).
    // - Persists a MealPhoto object and writes both files to disk.
    @MainActor
    static func addPhoto(from originalImageData: Data,
                         suggestedUTTypeExtension: String? = nil, // e.g., "heic" or "jpg"
                         to meal: Meal,
                         in context: NSManagedObjectContext,
                         session: SessionManager? = nil) throws -> MealPhoto {

        // Determine at runtime how Core Data sees the 'meal' relationship on MealPhoto
        let mealRelIsToMany: Bool = {
            guard let entity = NSEntityDescription.entity(forEntityName: "MealPhoto", in: context) else { return false }
            return entity.relationshipsByName["meal"]?.isToMany ?? false
        }()

        // Enforce free-tier photo cap (if session provided; otherwise skip)
        if let session {
            let tier = Entitlements.tier(for: session)
            let maxAllowed = Entitlements.maxPhotosPerMeal(for: tier)
            if maxAllowed < 9000 {
                // Count existing photos for this meal using a predicate that matches the runtime cardinality
                let request = NSFetchRequest<NSFetchRequestResult>(entityName: "MealPhoto")
                if mealRelIsToMany {
                    request.predicate = NSPredicate(format: "ANY meal == %@", meal)
                } else {
                    request.predicate = NSPredicate(format: "meal == %@", meal)
                }
                request.includesSubentities = false
                request.includesPendingChanges = true
                request.resultType = .countResultType

                let existingCount = (try? context.count(for: request)) ?? 0
                if existingCount >= maxAllowed {
                    throw PhotoServiceError.freeTierPhotoLimitReached(max: maxAllowed)
                }
            }
        }

        // Load original image to read dimensions (don’t recompress)
        guard let image = UIImage(data: originalImageData) else {
            throw PhotoServiceError.invalidImage
        }

        let id = UUID()
        let createdAt = Date()

        // File extensions
        let originalExt: String = {
            if let ext = suggestedUTTypeExtension?.lowercased(), ["jpg", "jpeg", "heic", "png"].contains(ext) {
                return ext == "jpeg" ? "jpg" : ext
            }
            if originalImageData.isJPEG { return "jpg" }
            if originalImageData.isHEIC { return "heic" }
            if originalImageData.isPNG { return "png" }
            return "jpg"
        }()

        let uploadExt = "jpg"

        // File names
        let originalName = PhotoStore.makeFileName(id: id, kind: .original, ext: originalExt)
        let uploadName = PhotoStore.makeFileName(id: id, kind: .upload, ext: uploadExt)

        let originalURL = try PhotoStore.fileURL(fileName: originalName)
        let uploadURL = try PhotoStore.fileURL(fileName: uploadName)

        // Write original as-is
        try originalImageData.write(to: originalURL, options: .atomic)

        // Prepare upload image (1080p long-edge, medium compression)
        guard let resized = ImageResizer.resizeToLongEdge(1080, image: image, jpegQuality: 0.72) else {
            try? FileManager.default.removeItem(at: originalURL)
            throw PhotoServiceError.invalidImage
        }
        try resized.jpegData.write(to: uploadURL, options: .atomic)

        // Compute metadata
        let sha256 = ImageResizer.sha256Hex(of: originalImageData)
        let byteSizeOriginal = PhotoStore.fileSizeBytes(at: originalURL)
        let byteSizeUpload = PhotoStore.fileSizeBytes(at: uploadURL)

        // Persist MealPhoto
        let photo = MealPhoto(context: context)
        photo.id = id
        photo.createdAt = createdAt
        photo.width = Int32(image.sizeInPixels.width)
        photo.height = Int32(image.sizeInPixels.height)
        photo.fileNameOriginal = originalName
        photo.fileNameUpload = uploadName
        photo.byteSizeOriginal = byteSizeOriginal
        photo.byteSizeUpload = byteSizeUpload
        photo.sha256 = sha256

        // Assign relationship according to runtime cardinality
        if mealRelIsToMany {
            photo.mutableSetValue(forKey: "meal").add(meal)
            #if DEBUG
            print("PhotoService: WARNING — runtime model says MealPhoto.meal is To-Many. Please fix the Core Data model to To-One.")
            #endif
        } else {
            photo.meal = meal
        }

        do {
            try context.save()
        } catch {
            PhotoStore.removeFilesIfExist(original: originalName, upload: uploadName)
            throw PhotoServiceError.coreDataSaveFailed(error)
        }

        return photo
    }

    // Remove a photo: delete files and Core Data object
    @MainActor
    static func removePhoto(_ photo: MealPhoto, in context: NSManagedObjectContext) {
        PhotoStore.removeFilesIfExist(original: photo.fileNameOriginal, upload: photo.fileNameUpload)
        context.delete(photo)
        try? context.save()
    }

    // Access files for upload or display
    static func urlForOriginal(_ photo: MealPhoto) -> URL? {
        guard let name = photo.fileNameOriginal else { return nil }
        return try? PhotoStore.fileURL(fileName: name)
    }

    static func urlForUpload(_ photo: MealPhoto) -> URL? {
        guard let name = photo.fileNameUpload else { return nil }
        return try? PhotoStore.fileURL(fileName: name)
    }
}

private extension Data {
    var isJPEG: Bool { starts(with: [0xFF, 0xD8]) }
    var isPNG: Bool { starts(with: [0x89, 0x50, 0x4E, 0x47]) }
    var isHEIC: Bool {
        guard count >= 12 else { return false }
        let header = self.prefix(12)
        return header.dropFirst(4).prefix(4) == Data("ftyp".utf8) &&
               (header.suffix(4) == Data("heic".utf8) || header.suffix(4) == Data("heif".utf8))
    }
}

private extension UIImage {
    var sizeInPixels: CGSize {
        let scale = max(1.0, self.scale)
        return CGSize(width: size.width * scale, height: size.height * scale)
    }
}

