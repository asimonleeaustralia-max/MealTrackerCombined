//
//  TheCocktailDBClient.swift
//  MealTracker
//
//  Minimal client to fetch drinks from TheCocktailDB and map into MealsRepository.MealRow.
//

import Foundation

enum TheCocktailDBClient {

    static func fetchAllDrinks(logger: ((String) -> Void)? = nil, maxItems: Int? = nil) async throws -> [MealsRepository.MealRow] {
        var rows: [MealsRepository.MealRow] = []

        let categories = try await listCategories(logger: logger)
        logger?("TheCocktailDB: found \(categories.count) categories")

        var seenIDs = Set<String>()
        var budget = maxItems ?? Int.max

        for cat in categories {
            if budget <= 0 { break }
            let summaries = try await listDrinks(inCategory: cat, logger: logger)
            logger?("TheCocktailDB: \(cat) -> \(summaries.count) drinks")
            for s in summaries {
                if budget <= 0 { break }
                guard !seenIDs.contains(s.idDrink) else { continue }
                seenIDs.insert(s.idDrink)
                do {
                    if let detail = try await lookupDrinkDetail(id: s.idDrink, logger: logger) {
                        if let row = map(detail: detail) {
                            rows.append(row)
                            budget -= 1
                        }
                    }
                } catch {
                    logger?("TheCocktailDB: failed detail for id \(s.idDrink): \(prettyError(error))")
                }
            }
        }

        return rows
    }

    // MARK: - Models

    private struct CategoriesResponse: Decodable {
        let drinks: [Category]?
    }

    private struct Category: Decodable {
        let strCategory: String?
    }

    private struct ListResponse: Decodable {
        let drinks: [DrinkSummary]?
    }

    private struct DrinkSummary: Decodable {
        let idDrink: String
        let strDrink: String
    }

    private struct DetailResponse: Decodable {
        let drinks: [DrinkDetail]?
    }

    // Only decode fields we need
    private struct DrinkDetail: Decodable {
        let idDrink: String
        let strDrink: String?
        let strCategory: String?
        let strAlcoholic: String?
        let strInstructions: String?
    }

    // MARK: - Networking

    private static func listCategories(logger: ((String) -> Void)? = nil) async throws -> [String] {
        let url = URL(string: "https://www.thecocktaildb.com/api/json/v1/1/list.php?c=list")!
        let data = try await fetchJSONData(from: url, logger: logger)
        do {
            let decoded = try JSONDecoder().decode(CategoriesResponse.self, from: data)
            let cats = (decoded.drinks ?? []).compactMap { $0.strCategory?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            return cats
        } catch {
            logger?("TheCocktailDB: decode categories failed: \(prettyError(error))")
            throw error
        }
    }

    private static func listDrinks(inCategory category: String, logger: ((String) -> Void)? = nil) async throws -> [DrinkSummary] {
        guard let enc = category.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://www.thecocktaildb.com/api/json/v1/1/filter.php?c=\(enc)") else {
            return []
        }
        let data = try await fetchJSONData(from: url, logger: logger)
        do {
            let decoded = try JSONDecoder().decode(ListResponse.self, from: data)
            return decoded.drinks ?? []
        } catch {
            logger?("TheCocktailDB: decode list for category \(category) failed: \(prettyError(error))")
            throw error
        }
    }

    private static func lookupDrinkDetail(id: String, logger: ((String) -> Void)? = nil) async throws -> DrinkDetail? {
        guard let url = URL(string: "https://www.thecocktaildb.com/api/json/v1/1/lookup.php?i=\(id)") else {
            return nil
        }
        let data = try await fetchJSONData(from: url, logger: logger)
        do {
            let decoded = try JSONDecoder().decode(DetailResponse.self, from: data)
            return decoded.drinks?.first
        } catch {
            logger?("TheCocktailDB: decode detail \(id) failed: \(prettyError(error))")
            throw error
        }
    }

    // MARK: - Mapping

    private static func map(detail: DrinkDetail) -> MealsRepository.MealRow? {
        let id64: Int64 = Int64(detail.idDrink) ?? Int64(abs(detail.idDrink.hashValue))
        let title = (detail.strDrink?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Drink"

        let descParts = [
            detail.strCategory,
            detail.strAlcoholic,
            detail.strInstructions
        ].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        let description = descParts.isEmpty ? nil : descParts.joined(separator: " • ")

        let portionGrams = 240.0

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
        guard !data.isEmpty else {
            let err = NSError(domain: "TheCocktailDBClient", code: -1, userInfo: [NSLocalizedDescriptionKey: "Empty response body from \(url.absoluteString)"])
            logger?("TheCocktailDB: \(err.localizedDescription)")
            throw err
        }
        if let ct = http.value(forHTTPHeaderField: "Content-Type"), !ct.lowercased().contains("application/json") {
            logger?("TheCocktailDB: Unexpected Content-Type '\(ct)' from \(url.absoluteString)")
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

