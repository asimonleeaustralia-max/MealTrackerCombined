//
//  FeaturePrintClassifier.swift
//  MealTracker
//
//  No-training, on-device image matching using Vision FeaturePrints.
//  Loads a small reference gallery from FoodReferenceIndex.json in the main bundle,
//  computes feature vectors on first use, and matches input images by cosine similarity.
//

import Foundation
import Vision
import UIKit

struct FeaturePrintClassifier {

    struct ReferenceItem: Codable, Equatable {
        let label: String
        let image: String // filename in bundle
    }

    struct MatchResult {
        let label: String
        let confidence: Double // 0...1, derived from cosine similarity
    }

    // In-memory cache of reference feature vectors
    private static var cachedRefs: [(item: ReferenceItem, feature: VNFeaturePrintObservation)]?
    private static var lastLoadError: String?

    // Public classify API. Returns nil if no references found or embedding fails.
    static func classify(image uiImage: UIImage) async -> MatchResult? {
        guard let refs = await loadReferences() else {
            return nil
        }
        guard let probe = await embed(image: uiImage) else {
            return nil
        }

        // Find best match by cosine similarity
        var bestLabel: String?
        var bestScore: Double = -1.0

        for ref in refs {
            if let score = cosineSimilarity(probe, ref.feature) {
                if score > bestScore {
                    bestScore = score
                    bestLabel = ref.item.label
                }
            }
        }

        guard let label = bestLabel else { return nil }

        // Map cosine similarity [-1, 1] to a 0...1 confidence proxy
        // Clamp negatives to 0 for safety.
        let confidence = max(0.0, min(1.0, (bestScore + 1.0) / 2.0))
        return MatchResult(label: label, confidence: confidence)
    }

    // MARK: - Reference loading/embedding

    private static func loadReferences() async -> [(item: ReferenceItem, feature: VNFeaturePrintObservation)]? {
        if let cached = cachedRefs { return cached }
        let items: [ReferenceItem]
        do {
            guard let url = Bundle.main.url(forResource: "FoodReferenceIndex", withExtension: "json") else {
                lastLoadError = "FoodReferenceIndex.json not found in bundle."
                return nil
            }
            let data = try Data(contentsOf: url)
            items = try JSONDecoder().decode([ReferenceItem].self, from: data)
            if items.isEmpty {
                lastLoadError = "FoodReferenceIndex.json is empty."
                return nil
            }
        } catch {
            lastLoadError = "Failed to load/parse FoodReferenceIndex.json: \(error)"
            return nil
        }

        var out: [(ReferenceItem, VNFeaturePrintObservation)] = []
        for item in items {
            guard let img = loadBundleImage(named: item.image),
                  let feat = await embed(image: img) else {
                continue
            }
            out.append((item, feat))
        }

        guard !out.isEmpty else {
            lastLoadError = "No reference images could be embedded."
            return nil
        }
        cachedRefs = out
        return out
    }

    private static func loadBundleImage(named name: String) -> UIImage? {
        // Try exact filename first (with extension)
        if let url = Bundle.main.url(forResource: name, withExtension: nil),
           let data = try? Data(contentsOf: url),
           let ui = UIImage(data: data) {
            return ui
        }
        // If name has no extension, try common image types
        let base = (name as NSString).deletingPathExtension
        for ext in ["jpg", "jpeg", "png", "heic"] {
            if let url = Bundle.main.url(forResource: base, withExtension: ext),
               let data = try? Data(contentsOf: url),
               let ui = UIImage(data: data) {
                return ui
            }
        }
        return nil
    }

    private static func embed(image: UIImage) async -> VNFeaturePrintObservation? {
        guard let cg = image.cgImage else { return nil }
        return await withCheckedContinuation { continuation in
            let request = VNGenerateImageFeaturePrintRequest { request, error in
                if let _ = error {
                    continuation.resume(returning: nil)
                    return
                }
                let obs = request.results?.first as? VNFeaturePrintObservation
                continuation.resume(returning: obs)
            }
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    // MARK: - Similarity

    private static func cosineSimilarity(_ a: VNFeaturePrintObservation, _ b: VNFeaturePrintObservation) -> Double? {
        var distance: Float = 0
        do {
            try a.computeDistance(&distance, to: b)
            // Vision returns "distance" for L2; FeaturePrint also supports distance as "1 - cosineSimilarity" in some docs.
            // Empirically, computeDistance on FeaturePrint gives L2-ish. We'll transform a distance into a monotonic similarity.
            // Simple transform: similarity = 1 / (1 + distance). Then rescale to approx 0..1 in classify().
            let sim = 1.0 / (1.0 + Double(distance))
            return sim
        } catch {
            return nil
        }
    }
}

