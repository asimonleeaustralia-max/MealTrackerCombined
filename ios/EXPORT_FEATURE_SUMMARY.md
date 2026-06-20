# Export Feature Implementation Summary

## Overview
Added a JSON export feature to the Settings page that allows users to export all their meals data to a JSON file.

## Changes Made

### SettingsView.swift

#### 1. New State Variables (Lines ~40-43)
```swift
@State private var showingExportSuccess: Bool = false
@State private var showingExportError: Bool = false
@State private var exportErrorMessage: String = ""
@State private var exportedFileURL: URL?
```

#### 2. New Export Section in UI (Lines ~176-185)
Added a new "Export" section at the bottom of the settings page with:
- Section header: "Export"
- Button labeled: "Export Meals as JSON"
- Icon: square and arrow up (system symbol)

#### 3. Success and Error Alerts (Lines ~243-256)
- Success alert with options to:
  - Share the exported file
  - Dismiss with OK
- Error alert showing the error message

#### 4. Helper Function (Lines ~262-265)
`localizedOrFallback()` - Provides fallback English text if localization keys are missing

#### 5. Export Implementation (Lines ~408-570)

##### exportMeals()
- Triggered when user taps the export button
- Calls `generateMealsJSON()` asynchronously
- Shows success or error alerts based on result

##### generateMealsJSON()
- Fetches all meals from CoreData using `Meal.fetchAllMealsRequest()`
- Converts each meal to a dictionary with the following logic:
  - **Always included**: `id`, `date` (ISO8601 format)
  - **Included if not empty**: `title`
  - **Included if non-zero**: All numeric nutrition fields
  - **Included if not empty**: Optional string fields (`lastSyncGUID`, `photoGuesserType`, `productName`)
  - **Special handling**: Location coordinates included only if either latitude or longitude is non-zero
- Creates JSON with pretty printing and sorted keys
- Saves to temporary directory with timestamp in filename
- Returns file URL

##### addIfNonZero()
- Helper function that adds numeric values to the dictionary only if non-zero
- Also includes the corresponding `isGuess` flag if the value is a guess

##### shareFile()
- Presents iOS share sheet (UIActivityViewController)
- Handles iPad popover positioning
- Allows user to save to Files, AirDrop, or share via other apps

## Features

### What Gets Exported
All meals from CoreData with the following fields (when not zero/empty):

**Always Included:**
- `id` (UUID string)
- `date` (ISO8601 formatted string)

**Included if not empty:**
- `title`

**Included if non-zero:**
- Basic nutrition: calories, carbohydrates, protein, sodium, fat
- Carbohydrate breakdown: starch, sugars, fibre
- Fat breakdown: monounsaturatedFat, polyunsaturatedFat, saturatedFat, transFat, omega3, omega6
- Protein breakdown: animalProtein, plantProtein, proteinSupplements, a2BetaCasein, a1BetaCasein
- Alcohol and stimulants: alcohol, nicotine, theobromine, caffeine, taurine, creatine
- Vitamins: vitaminA, vitaminB, vitaminC, vitaminD, vitaminE, vitaminK
- Minerals: calcium, iron, potassium, zinc, magnesium, iodine, phosphorus
- Location: latitude, longitude (if either is non-zero)
- Accuracy flags: `*IsGuess` for each field that has a value

**Included if not empty:**
- `lastSyncGUID`
- `photoGuesserType`
- `productName`

### User Experience
1. User opens Settings
2. Scrolls to "Export" section at the bottom
3. Taps "Export Meals as JSON"
4. On success:
   - Alert appears: "Export Successful"
   - Message: "Your meals have been exported successfully."
   - Options: Share or OK
5. If Share is tapped:
   - iOS share sheet appears
   - User can save to Files, AirDrop, email, etc.
6. On failure:
   - Alert appears: "Export Failed"
   - Shows error message

### File Format
- **Format**: JSON
- **Encoding**: UTF-8
- **Pretty printed**: Yes (readable multi-line format)
- **Sorted keys**: Yes (alphabetical order)
- **Filename**: `meals_export_YYYY-MM-DDTHH-MM-SS.json`
- **Location**: Temporary directory (managed by iOS)

## Example JSON Output

```json
[
  {
    "a1BetaCasein": 2.5,
    "calories": 450,
    "carbohydrates": 35,
    "date": "2026-03-20T14:30:00Z",
    "fat": 20,
    "id": "12345678-1234-1234-1234-123456789012",
    "protein": 25,
    "proteinIsGuess": true,
    "saturatedFat": 8,
    "title": "Lunch on Thursday, afternoon",
    "vitaminC": 30
  }
]
```

## Localization Support
The feature uses the app's LocalizationManager with fallback English text:
- `export_section_title` → "Export"
- `export_meals_button` → "Export Meals as JSON"
- `export_success_title` → "Export Successful"
- `export_success_message` → "Your meals have been exported successfully."
- `export_error_title` → "Export Failed"
- `share` → "Share"
- `ok` → "OK"

## Technical Notes
- Uses Swift Concurrency (async/await)
- CoreData operations performed on proper context queue via `context.perform()`
- Thread-safe with `@MainActor` for UI updates
- File is saved to system temporary directory (automatically cleaned up by iOS)
- Share sheet properly configured for iPad with popover positioning
