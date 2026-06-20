import SwiftUI

struct LocalizationManager {
    let languageCode: String

    static var defaultLanguageCode: String {
        // Use first preferred localization available in the bundle
        if #available(iOS 16, *) {
            return Bundle.main.preferredLocalizations.first
                ?? Locale.current.language.languageCode?.identifier
                ?? "en"
        } else {
            // Fallback on earlier versions
            // Locale.current.languageCode is available before iOS 16
            return Bundle.main.preferredLocalizations.first
                ?? Locale.current.languageCode
                ?? "en"
        }
    }

    func bundle() -> Bundle {
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let b = Bundle(path: path) else {
            return Bundle.main
        }
        return b
    }

    func localized(_ key: String) -> String {
        NSLocalizedString(key, tableName: nil, bundle: bundle(), value: key, comment: "")
    }

    // Returns the autonym (name in its own language/script), preserving script/region when present.
    static func displayName(for code: String) -> String {
        let id = normalizeIdentifier(code)

        // 1) Try autonym using a locale constructed with the identifier itself.
        let autonymLocale = Locale(identifier: id)

        // Prefer forIdentifier to keep script/region distinctions (e.g., "中文（繁體）", "Português (Brasil)").
        if let name = autonymLocale.localizedString(forIdentifier: id), !name.isEmpty {
            return name
        }

        // 2) Fallback: language-only name in its own locale.
        if let langCode = languageSubtag(id),
           let name = autonymLocale.localizedString(forLanguageCode: langCode), !name.isEmpty {
            return name
        }

        // 3) Fallback to current locale (may show localized into current UI language).
        if let name = Locale.current.localizedString(forIdentifier: id), !name.isEmpty {
            return name
        }
        if let langCode = languageSubtag(id),
           let name = Locale.current.localizedString(forLanguageCode: langCode), !name.isEmpty {
            return name
        }

        // 4) Last resort: raw code.
        return code
    }

    // Normalize identifiers like "pt_BR" -> "pt-BR", fix legacy aliases, lowercase language, keep script/region.
    private static func normalizeIdentifier(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty { return raw }
        s = s.replacingOccurrences(of: "_", with: "-")

        // Legacy aliases -> modern codes
        // iw -> he (Hebrew), in -> id (Indonesian), ji -> yi (Yiddish)
        let lower = s.lowercased()
        var parts = lower.split(separator: "-").map(String.init)
        if !parts.isEmpty {
            switch parts[0] {
            case "iw": parts[0] = "he"
            case "in": parts[0] = "id"
            case "ji": parts[0] = "yi"
            default: break
            }
        }

        // Re-compose with proper casing: language lower, script TitleCase, region upper.
        // e.g., zh-hant-TW -> zh-Hant-TW
        var out: [String] = []
        if let lang = parts.first { out.append(lang.lowercased()) }
        if parts.count >= 2 {
            let second = parts[1]
            if second.count == 4 { // script
                out.append(second.prefix(1).uppercased() + second.dropFirst().lowercased())
                if parts.count >= 3 {
                    let third = parts[2]
                    if third.count == 2 || third.count == 3 {
                        out.append(third.uppercased())
                    } else {
                        out.append(third)
                    }
                }
                if parts.count > 3 {
                    out.append(contentsOf: parts.dropFirst(3))
                }
            } else {
                // region or variant
                if second.count == 2 || second.count == 3 {
                    out.append(second.uppercased())
                } else {
                    out.append(second)
                }
                if parts.count > 2 {
                    out.append(contentsOf: parts.dropFirst(2))
                }
            }
        }
        return out.joined(separator: "-")
    }

    private static func languageSubtag(_ id: String) -> String? {
        let comps = id.split(separator: "-")
        guard let first = comps.first else { return nil }
        return String(first)
    }
}

struct LocalizedText: View {
    let key: String
    let manager: LocalizationManager

    init(_ key: String, manager: LocalizationManager) {
        self.key = key
        self.manager = manager
    }

    var body: some View {
        Text(manager.localized(key))
    }
}
