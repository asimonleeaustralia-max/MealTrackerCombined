# Privacy Policy for MealTracker

**Last Updated:** March 21, 2026

## Overview

MealTracker is a nutrition tracking application that stores data locally on your device. This privacy policy explains how we handle your information.

## Data Collection

**We do not collect, transmit, or share any personal information.**

All data you enter into MealTracker is stored exclusively on your device using Apple's Core Data framework. This includes:
- Meal information (names, dates, nutrition data)
- Photos of meals
- Personal settings and preferences
- Location data (if you enable this optional feature)

### Barcode Scanning and OpenFoodFacts

When you scan a product barcode, MealTracker sends the barcode number to the OpenFoodFacts API to retrieve nutritional information:
- **What is sent:** Only the barcode number (e.g., a UPC or EAN code)
- **What is NOT sent:** No personal information, device identifiers, or location data
- **Purpose:** To automatically populate nutritional information for scanned products
- **Third-party:** OpenFoodFacts is a free, open database maintained by Open Food Facts (openfoodfacts.org)
- **OpenFoodFacts Privacy:** See their privacy policy at https://world.openfoodfacts.org/privacy

## Data Storage

- **Local Storage Only:** All data remains on your device
- **No Cloud Sync:** We do not sync your data to any servers
- **No Analytics:** We do not track your usage or behavior
- **No Third Parties:** We do not share data with anyone

## Permissions

MealTracker requests the following permissions for app functionality:

### Camera Access (Optional)
- **Purpose:** To photograph your meals
- **Storage:** Photos are saved locally on your device
- **Transmission:** Photos never leave your device

### Photo Library Access (Optional)
- **Purpose:** To select existing photos for meals
- **Storage:** Selected photos are referenced or copied locally
- **Transmission:** Photos never leave your device

### Location Access (Optional)
- **Purpose:** To add location context to meals (if you choose)
- **Storage:** Location data is saved locally with the meal
- **Transmission:** Location data never leaves your device
- **Note:** This feature can be disabled entirely

## Your Control

You have complete control over your data:

- **Delete Anytime:** Delete individual meals or all data through the app
- **Disable Permissions:** Revoke camera, photo, or location access in iOS Settings
- **Uninstall:** Deleting the app removes all stored data

## Data Security

Your data is protected by:
- iOS built-in encryption and security
- Local-only storage (no network transmission)
- iOS Keychain for sensitive settings (if applicable)

## Children's Privacy

MealTracker does not knowingly collect information from anyone, including children under 13. All data remains on the user's device.

## Changes to Privacy Policy

If we update this privacy policy, we will:
- Update the "Last Updated" date above
- Notify users through an app update

## Contact

If you have questions about privacy or data handling:

**Email:** [your-email@example.com]

## Third-Party Services

MealTracker uses the following third-party service:

### OpenFoodFacts API
- **Purpose:** Retrieve nutritional information for scanned product barcodes
- **Data Sent:** Only product barcode numbers (no personal information)
- **Privacy Policy:** https://world.openfoodfacts.org/privacy
- **About:** OpenFoodFacts is a free, collaborative, open database of food products

MealTracker does NOT use:
- Analytics services (e.g., Google Analytics, Firebase)
- Crash reporting services
- Advertising networks
- Social media integrations
- Cloud storage services

## Legal Basis

This app operates on the principle of local data processing. Since no data is collected or transmitted, we do not require consent for data processing under GDPR or similar regulations.

## Your Rights

Since we don't collect or store your data on our systems:
- We cannot access your data
- We cannot delete your data remotely (you control it locally)
- We have no data to share or export beyond what's on your device

## Disclaimer

MealTracker is for informational purposes only and is not medical advice. Consult healthcare professionals for dietary decisions.

---

**How to Use This Privacy Policy:**

1. **Host it online:**
   - Create a free GitHub Pages site
   - Or use a simple hosting service
   - Must be accessible via HTTPS

2. **Update the email:**
   - Replace `[your-email@example.com]` with your support email

3. **Add URL to App Store Connect:**
   - In App Store Connect → App Information
   - Add the public URL in "Privacy Policy URL"

4. **Keep it accessible:**
   - URL must remain live as long as app is on App Store
   - Cannot change URL without updating App Store Connect

**Note:** For a truly local-only app, Apple sometimes accepts apps without an external privacy policy if you clearly state "no data collected" in App Store Connect. However, having one is best practice and prevents potential rejection.
