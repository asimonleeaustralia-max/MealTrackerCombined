import SwiftUI

struct AboutView: View {
    // Respect in-app language override
    @AppStorage("appLanguageCode") private var appLanguageCode: String = LocalizationManager.defaultLanguageCode

    private var l: LocalizationManager {
        LocalizationManager(languageCode: appLanguageCode)
    }

    private var localizedBundle: Bundle {
        l.bundle()
    }

    private var appName: String {
        // Try CFBundleDisplayName, then CFBundleName from the selected language bundle
        if let display = localizedBundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String, !display.isEmpty {
            return display
        }
        if let name = localizedBundle.object(forInfoDictionaryKey: "CFBundleName") as? String, !name.isEmpty {
            return name
        }
        // Fallback to localized string table
        return l.localized("about.app_name_fallback")
    }

    private var versionString: String {
        // Version/build come from Info.plist (not localized), format string is localized
        let version = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "—"
        let build = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String) ?? "—"
        let fmt = l.localized("about.version_format") // e.g., "Version %@ (%@)"
        return String(format: fmt, version, build)
    }

    private var copyrightString: String? {
        // Read from InfoPlist.strings in the selected language if present
        if let s = localizedBundle.object(forInfoDictionaryKey: "NSHumanReadableCopyright") as? String, !s.isEmpty {
            return s
        }
        return nil
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // App icon from asset catalog (fallback to system symbol)
                AppIconView()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                Text(appName)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(versionString)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let copyright = copyrightString {
                    Text(copyright)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }

                Divider().padding(.vertical, 6)

                // Medical disclaimer
                VStack(alignment: .leading, spacing: 10) {
                    Text(l.localized("about.disclaimer_title"))
                        .font(.headline)

                    Text(l.localized("about.disclaimer_body"))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Privacy statement
                VStack(alignment: .leading, spacing: 10) {
                    Text("Privacy")
                        .font(.headline)
                    
                    Text("This app stores all data locally on your device. When you scan a barcode, only the barcode number is sent to OpenFoodFacts API to retrieve nutritional information. No personal information is collected or shared.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    // Links to privacy policies
                    VStack(alignment: .leading, spacing: 8) {
                        if let url = URL(string: "https://asimonleeaustralia-max.github.io/MealTrackerPrivacyPolicy/privacy-policy") {
                            Link("View Full Privacy Policy", destination: url)
                                .font(.subheadline)
                        }
                        
                        if let url = URL(string: "https://world.openfoodfacts.org/privacy") {
                            Link("OpenFoodFacts Privacy Policy", destination: url)
                                .font(.subheadline)
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 8)

                Spacer(minLength: 12)
            }
            .padding()
        }
        .navigationTitle(l.localized("about_title"))
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

private struct AppIconView: View {
    var body: some View {
        // Attempt to load the primary app icon from the asset catalog by name.
        // If not available, show a placeholder system image.
        if let iconName = Bundle.main.object(forInfoDictionaryKey: "CFBundleIcons") as? [String: Any],
           let primary = iconName["CFBundlePrimaryIcon"] as? [String: Any],
           let files = primary["CFBundleIconFiles"] as? [String],
           let last = files.last,
           let image = UIImage(named: last) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.secondary.opacity(0.15))
                Image(systemName: "fork.knife.circle")
                    .font(.system(size: 40, weight: .regular))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
