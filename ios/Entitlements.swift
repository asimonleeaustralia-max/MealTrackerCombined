import Foundation
import CoreData

enum AccessTier: String {
    case free
    case paid

    var displayName: String {
        switch self {
        case .free: return NSLocalizedString("tier.free", comment: "Free")
        case .paid: return NSLocalizedString("tier.paid", comment: "Pro")
        }
    }
}

struct Entitlements {
    // Limits
    static let freeMaxPhotosPerMeal: Int = 10
    static let freeMaxMealsPerDay: Int = 10

    // A practical "unlimited" cap to avoid special cases in UI (very high).
    static let paidMaxPhotosPerMeal: Int = 9999
    static let paidMaxMealsPerDay: Int = 9999

    static func tier(for session: SessionManager) -> AccessTier {
        session.isLoggedIn ? .paid : .free
    }

    static func maxPhotosPerMeal(for tier: AccessTier) -> Int {
        switch tier {
        case .free: return freeMaxPhotosPerMeal
        case .paid: return paidMaxPhotosPerMeal
        }
    }

    static func maxMealsPerDay(for tier: AccessTier) -> Int {
        switch tier {
        case .free: return freeMaxMealsPerDay
        case .paid: return paidMaxMealsPerDay
        }
    }

    // MARK: - Counting meals for "today"

    static func startOfToday() -> Date {
        Calendar.current.startOfDay(for: Date())
    }

    static func endOfToday() -> Date {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        return cal.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? Date()
    }

    static func mealsRecordedToday(in context: NSManagedObjectContext) -> Int {
        let request = NSFetchRequest<NSNumber>(entityName: "Meal")
        request.resultType = .countResultType
        request.predicate = NSPredicate(format: "date >= %@ AND date <= %@", startOfToday() as NSDate, endOfToday() as NSDate)
        do {
            let result = try context.fetch(request)
            return result.first?.intValue ?? 0
        } catch {
            return 0
        }
    }

    static func mealsRemainingToday(for tier: AccessTier, in context: NSManagedObjectContext) -> Int? {
        let maxPerDay = maxMealsPerDay(for: tier)
        if maxPerDay >= 9000 { return nil } // treat as unlimited
        let used = mealsRecordedToday(in: context)
        return max(0, maxPerDay - used)
    }
}
