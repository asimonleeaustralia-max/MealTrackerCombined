//
//  TheMealDBClient.swift
//  MealTracker
//
//  Minimal client to fetch meals from TheMealDB and map into MealsRepository.MealRow.
//

import Foundation

enum TheMealDBClient {

    // Public API: fetch all meals (best-effort across categories) and map to MealRow
    static func fetchAllMeals(logger: ((String) -> Void)? = nil, maxItems: Int? = nil) async throws -> [MealsRepository.MealRow] {
        var rows: [MealsRepository.MealRow] = []

        let categories = try await listCategories(logger: logger)
        logger?("TheMealDB: found \(categories.count) categories")

        var seenIDs = Set<String>()
        var budget = maxItems ?? Int.max

        for cat in categories {
            if budget <= 0 { break }
            let summaries = try await listMeals(inCategory: cat, logger: logger)
            logger?("TheMealDB: \(cat) -> \(summaries.count) meals")
            for s in summaries {
                if budget <= 0 { break }
                guard !seenIDs.contains(s.idMeal) else { continue }
                seenIDs.insert(s.idMeal)
                do {
                    if let detail = try await lookupMealDetail(id: s.idMeal, logger: logger) {
                        if let row = map(detail: detail) {
                            rows.append(row)
                            budget -= 1
                        }
                    }
                } catch {
                    logger?("TheMealDB: failed detail for id \(s.idMeal): \(prettyError(error))")
                }
            }
        }

        return rows
    }

    // MARK: - Models

    private struct CategoriesResponse: Decodable {
        let categories: [Category]?
    }

    private struct Category: Decodable {
        let strCategory: String?
    }

    private struct ListResponse: Decodable {
        let meals: [MealSummary]?
    }

    private struct MealSummary: Decodable {
        let idMeal: String
        let strMeal: String
    }

    private struct DetailResponse: Decodable {
        let meals: [MealDetail]?
    }

    // We only decode what we need for mapping
    private struct MealDetail: Decodable {
        let idMeal: String
        let strMeal: String?
        let strCategory: String?
        let strArea: String?
        let strInstructions: String?
        let strTags: String?
    }

    // MARK: - Networking

    private static func listCategories(logger: ((String) -> Void)? = nil) async throws -> [String] {
        let url = URL(string: "https://www.themealdb.com/api/json/v1/1/list.php?c=list")!
        let data = try await fetchJSONData(from: url, logger: logger)
        do {
            let decoded = try JSONDecoder().decode(CategoriesResponse.self, from: data)
            let cats = (decoded.categories ?? []).compactMap { $0.strCategory?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            return cats
        } catch {
            logger?("TheMealDB: decode categories failed: \(prettyError(error))")
            throw error
        }
    }

    private static func listMeals(inCategory category: String, logger: ((String) -> Void)? = nil) async throws -> [MealSummary] {
        guard let enc = category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.themealdb.com/api/json/v1/1/filter.php?c=\(enc)") else {
            return []
        }
        let data = try await fetchJSONData(from: url, logger: logger)
        do {
            let decoded = try JSONDecoder().decode(ListResponse.self, from: data)
            return decoded.meals ?? []
        } catch {
            logger?("TheMealDB: decode list for category \(category) failed: \(prettyError(error))")
            throw error
        }
    }

    private static func lookupMealDetail(id: String, logger: ((String) -> Void)? = nil) async throws -> MealDetail? {
        guard let url = URL(string: "https://www.themealdb.com/api/json/v1/1/lookup.php?i=\(id)") else {
            return nil
        }
        let data = try await fetchJSONData(from: url, logger: logger)
        do {
            let decoded = try JSONDecoder().decode(DetailResponse.self, from: data)
            return decoded.meals?.first
        } catch {
            logger?("TheMealDB: decode detail \(id) failed: \(prettyError(error))")
            throw error
        }
    }

    // MARK: - Mapping

    private static func map(detail: MealDetail) -> MealsRepository.MealRow? {
        // idMeal is a string; convert to Int64 if possible, otherwise hash
        let id64: Int64 = Int64(detail.idMeal) ?? Int64(abs(detail.idMeal.hashValue))

        let title = (detail.strMeal?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Meal"
        let descParts = [
            detail.strCategory,
            detail.strArea,
            detail.strTags,
            detail.strInstructions
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let description = descParts.isEmpty ? nil : descParts.joined(separator: " • ")

        // Portion grams unknown from API; use a conservative default
        let portionGrams = 100.0

        return MealsRepository.MealRow(
            id: id64,
            title: title,
            description: description,
            portionGrams: portionGrams,
            calories: nil,
            carbohydrates: nil,
            protein: nil,
            sodium: nil,
            fat: nil,
            latitude: nil,
            longitude: nil,
            alcohol: nil,
            nicotine: nil,
            theobromine: nil,
            caffeine: nil,
            taurine: nil,
            starch: nil,
            sugars: nil,
            fibre: nil,
            monounsaturatedFat: nil,
            polyunsaturatedFat: nil,
            saturatedFat: nil,
            transFat: nil,
            omega3: nil,
            omega6: nil,
            animalProtein: nil,
            plantProtein: nil,
            proteinSupplements: nil,
            vitaminA: nil,
            vitaminB: nil,
            vitaminC: nil,
            vitaminD: nil,
            vitaminE: nil,
            vitaminK: nil,
            calcium: nil,
            iron: nil,
            potassium: nil,
            zinc: nil,
            magnesium: nil
        )
    }

    // MARK: - Helpers

    private static func fetchJSONData(from url: URL, logger: ((String) -> Void)? = nil) async throws -> Data {
        let (data, resp) = try await URLSession.shared.data(from: url)
        guard let http = resp as? HTTPURLResponse, 200..<300 ~= http.statusCode else {
            throw URLError(.badServerResponse)
        }
        // Some public endpoints can return empty objects; guard against 0-byte
        guard !data.isEmpty else {
            let err = NSError(domain: "TheMealDBClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty response body from \(url.absoluteString)"])
            logger?("TheMealDB: \(err.localizedDescription)")
            throw err
        }
        // Optional: sanity check Content-Type starts with application/json
        if let ct = http.value(forHTTPHeaderField: "Content-Type"), !ct.lowercased().contains("application/json") {
            logger?("TheMealDB: Unexpected Content-Type '\(ct)' from \(url.absoluteString)")
        }
        return data
    }

    private static func prettyError(_ error: Error) -> String {
        if let decErr = error as? DecodingError {
            switch decErr {
            case .keyNotFound(let key, let ctx):
                return "Missing key '\(key.stringValue)' at \(ctx.codingPath.map { $0.stringValue }.joined(separator: "."))"
            case .valueNotFound(let type, let ctx):
                return "Missing \(type) at \(ctx.codingPath.map { $0.stringValue }.joined(separator: "."))"
            case .typeMismatch(let type, let ctx):
                return "Type mismatch \(type) at \(ctx.codingPath.map { $0.stringValue }.joined(separator: "."))"
            case .dataCorrupted(let ctx):
                return "Data corrupted at \(ctx.codingPath.map { $0.stringValue }.joined(separator: "."))"
            @unknown default:
                return "\(error.localizedDescription)"
            }
        }
        return error.localizedDescription
    }
}

