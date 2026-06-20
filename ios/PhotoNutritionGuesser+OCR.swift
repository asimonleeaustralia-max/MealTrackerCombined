//
//  PhotoNutritionGuesser+OCR.swift
//  MealTracker
//
//  Vision-based OCR utilities split from PhotoNutritionGuesser.
//  Strict row grouping: any token not on the same y-band starts a new line.
//

import Foundation
import Vision
import UIKit

extension PhotoNutritionGuesser {

    // MARK: - OCR (strict row-aware)

    static func recognizeTextDualPass(in image: UIImage, languageCode: String?) async -> String? {
        async let tFastOpt = recognizeTextRows(in: image, languageCode: languageCode, level: .fast)
        let tFast = await tFastOpt

        if let tf = tFast, tf.count > 10 {
            let tAcc = await recognizeTextRows(in: image, languageCode: languageCode, level: .accurate)
            if let tAcc, tAcc.count > tf.count { return tAcc }
            return tf
        }
        return await recognizeTextRows(in: image, languageCode: languageCode, level: .accurate)
    }

    private static func recognizeTextRows(in image: UIImage, languageCode: String?, level: VNRequestTextRecognitionLevel) async -> String? {
        guard let cgImage = image.cgImage else { return nil }

        struct Token {
            let text: String
            let bbox: CGRect   // normalized (Vision coordinates: origin bottom-left)
            let height: CGFloat
            let yCenter: CGFloat
            let xMin: CGFloat
        }

        // 1) Run Vision and collect tokens with geometry
        let tokens: [Token]? = await withCheckedContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let _ = error {
                    continuation.resume(returning: nil)
                    return
                }
                guard let observations = request.results as? [VNRecognizedTextObservation], !observations.isEmpty else {
                    continuation.resume(returning: nil)
                    return
                }

                var out: [Token] = []
                out.reserveCapacity(observations.count)

                for obs in observations {
                    guard let best = obs.topCandidates(1).first else { continue }
                    let box = obs.boundingBox
                    let h = box.height
                    let yC = box.midY
                    let x0 = box.minX

                    let lines = best.string.components(separatedBy: CharacterSet.newlines).filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    if lines.isEmpty { continue }
                    if lines.count == 1 {
                        out.append(Token(text: lines[0].trimmingCharacters(in: .whitespacesAndNewlines), bbox: box, height: h, yCenter: yC, xMin: x0))
                    } else {
                        // Spread internal lines slightly in y to preserve order deterministically
                        let step = h / CGFloat(max(1, lines.count))
                        for (i, line) in lines.enumerated() {
                            let t = line.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !t.isEmpty else { continue }
                            let yOffset = (CGFloat(i) - CGFloat(lines.count - 1) / 2.0) * step * 0.6
                            out.append(Token(text: t, bbox: box, height: h, yCenter: yC + yOffset, xMin: x0))
                        }
                    }
                }

                continuation.resume(returning: out)
            }

            request.recognitionLevel = level
            request.usesLanguageCorrection = true
            request.recognitionLanguages = recognitionLanguagesFor(level: level, preferredCode: languageCode)

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try handler.perform([request])
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }

        guard var toks = tokens, !toks.isEmpty else { return nil }

        // 2) STRICT grouping: sort top->bottom, then build rows sequentially.
        // A token fits the current row only if its yCenter is within a tight tolerance of the row's median y.
        toks.sort { $0.yCenter > $1.yCenter }

        var rows: [[Token]] = []

        for token in toks {
            if rows.isEmpty {
                rows.append([token])
                continue
            }

            // Check only the last row; if not a tight y match, start a new row.
            if var lastRow = rows.last {
                // Compute median y and median height for the last row
                let ys = lastRow.map { $0.yCenter }.sorted()
                let hs = lastRow.map { $0.height }.sorted()
                let medianY = ys[ys.count / 2]
                let medianH = hs[hs.count / 2]

                // Tight tolerance: a small fraction of the row height; “new line is a new line”
                // Using 0.25*height keeps only very close horizontal bands together.
                let tol = max(medianH, token.height) * 0.25

                if abs(token.yCenter - medianY) <= tol {
                    lastRow.append(token)
                    rows[rows.count - 1] = lastRow
                } else {
                    rows.append([token])
                }
            } else {
                rows.append([token])
            }
        }

        // 3) For each row, sort tokens left-to-right and join text with minimal glue
        func joinRow(_ row: [Token]) -> String {
            let sorted = row.sorted { a, b in
                if abs(a.xMin - b.xMin) > 0.002 { return a.xMin < b.xMin }
                return a.yCenter > b.yCenter
            }

            var pieces: [String] = []
            var lastToken: Token? = nil

            func startsWithLetter(_ s: String) -> Bool {
                guard let ch = s.first else { return false }
                return ch.isLetter
            }
            func endsWithNumberOrDot(_ s: String) -> Bool {
                guard let ch = s.last else { return false }
                return ch.isNumber || ch == "."
            }

            for t in sorted {
                let text = t.text.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { continue }

                if let prev = lastToken {
                    let gap = t.bbox.minX - prev.bbox.maxX
                    let hAvg = (t.height + prev.height) * 0.5

                    // Only glue for number/decimal -> unit/suffix when gap is tiny.
                    var shouldGlue = false
                    if gap < (hAvg * 0.18) {
                        let lastPiece = pieces.last ?? prev.text
                        if endsWithNumberOrDot(lastPiece) && !startsWithLetter(text) {
                            shouldGlue = true
                        }
                    }

                    if shouldGlue {
                        let last = pieces.removeLast()
                        pieces.append(last + text)
                    } else {
                        pieces.append(text)
                    }
                } else {
                    pieces.append(text)
                }
                lastToken = t
            }

            let joined = pieces.joined(separator: " ").replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            return joined.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let lines = rows
            .map { joinRow($0) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else { return nil }
        return lines.joined(separator: "\n")
    }

    private static func recognitionLanguagesFor(level: VNRequestTextRecognitionLevel, preferredCode: String?) -> [String] {
        let normalizedPreferred = normalizedLanguageCode(preferredCode)

        if normalizedPreferred == nil && level == .accurate {
            return ["en", "en-US", "en-AU"]
        }

        let supported: [String] = {
            let revision: Int
            if #available(iOS 15.0, *) {
                revision = VNRecognizeTextRequest.currentRevision
            } else {
                revision = VNRecognizeTextRequestRevision1
            }
            return (try? VNRecognizeTextRequest.supportedRecognitionLanguages(for: level, revision: revision)) ?? []
        }()

        func unique(_ array: [String]) -> [String] {
            var seen = Set<String>()
            var result: [String] = []
            for code in array {
                if !seen.contains(code) {
                    seen.insert(code)
                    result.append(code)
                }
            }
            return result
        }

        var languages = unique(supported)

        if let pref = normalizedPreferred {
            if let idx = languages.firstIndex(of: pref) {
                languages.remove(at: idx)
            }
            languages.insert(pref, at: 0)
        }

        if !languages.contains("en-AU") { languages.append("en-AU") }
        if !languages.contains("en") { languages.append("en") }

        return languages
    }

    private static func normalizedLanguageCode(_ code: String?) -> String? {
        guard var c = code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), !c.isEmpty else { return nil }
        c = c.replacingOccurrences(of: "_", with: "-")
        return c
    }
}
