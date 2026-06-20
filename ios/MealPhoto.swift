//
//  MealPhoto.swift
//  MealTracker
//
//  Created by Simon Lee on 17/11/2025.
//

import Foundation
import CoreData

@objc(MealPhoto)
class MealPhoto: NSManagedObject, Identifiable {
    @NSManaged var id: UUID?
    @NSManaged var createdAt: Date?
    @NSManaged var width: Int32
    @NSManaged var height: Int32
    @NSManaged var fileNameOriginal: String?
    @NSManaged var fileNameUpload: String?
    @NSManaged var byteSizeOriginal: Int64
    @NSManaged var byteSizeUpload: Int64
    @NSManaged var sha256: String?
    @NSManaged var meal: Meal?

    // New optional coordinates (Double Optional in the model)
    @NSManaged var latitude: Double
    @NSManaged var longitude: Double
}
