# API Removal Summary: Open Food Facts, TheCocktailDB, and TheMealDB

## Overview
This document tracks the removal of three external data sources from the app:
1. **Open Food Facts / HuggingFace** - Large Parquet file download feature
2. **TheCocktailDB** - Cocktail and drink information API
3. **TheMealDB** - Recipe and meal information API

All removals improve App Store compliance and reduce external dependencies.

---

## Part 1: Open Food Facts / HuggingFace Download Removal

### Overview
Removed the large Parquet file download feature that fetched nutrition data from HuggingFace's Open Food Facts dataset. This eliminates App Store compliance concerns around large background downloads.

## Files Modified

### 1. MealTrackerApp.swift
**Removed:**
- Import statements: `BackgroundTasks`, `UserNotifications`
- `@UIApplicationDelegateAdaptor` for AppDelegate
- Background task identifier: `mealsSeedingTaskIdentifier`
- BGTaskScheduler registration in `init()`
- User notification permission request
- `scheduleMealsSeedingTask()` static method
- `scheduleMealsSeedingIfQueued()` method
- Calls to schedule background tasks in `.onChange(of: scenePhase)`

**Impact:** App no longer registers or schedules background processing tasks.

### 2. AppDelegate.swift
**Removed:**
- `handleEventsForBackgroundURLSession` method
- All ParquetDownloadManager references

**Status:** File now contains only an empty AppDelegate class (can be deleted if not needed for future use).

### 3. SettingsView.swift
**Removed:**
- `@StateObject private var networkMonitor`
- All OFF (Open Food Facts) download UI state variables:
  - `offStatusText`, `offProgress`, `offExpectedBytes`, `offReceivedBytes`
  - `showingOFFConfirm`, `offConfirmMessage`, `offError`, `offFreeBytes`
- All MealsSeedingManager UI state variables:
  - `seederStatusText`, `seederDownloaded`, `seederTotal`, `seederPhase`
  - `showingSeederConfirm`, `seederError`
- Computed properties for seeder status:
  - `durableCompleted`, `durableCompletedCount`, `isSeederCompletedForDisplay`
- Variable: `isEligibleForOfflineDB`
- `refreshSeederStatus()` method
- ParquetDownloadManager references in `refreshMealsDBInfo()`

**Updated:**
- `refreshMealsDBInfo()` now uses `MealsDBManager` instead of `ParquetDownloadManager`
- Comments updated to clarify Meals DB is from TheMealDB only (CocktailDB removed separately)

## Files That Should Be Deleted

### 1. ParquetDownloadManager.swift (261 lines)
**Purpose:** Managed background downloads of the large Parquet file from HuggingFace
**Dependencies:** 
- Used URLSession with background configuration
- Had file management for Application Support directory
- Provided progress tracking and status updates

### 2. MealsSeedingManager.swift (232 lines)
**Purpose:** Orchestrated background meal seeding from the Parquet file
**Dependencies:**
- Used BackgroundTasks framework
- Coordinated with BGTaskScheduler
- Persisted download state in UserDefaults
- Posted local notifications on completion

**Note:** These files still exist in your project but are no longer referenced. You should delete them from Xcode.

## Remaining Meal Data Sources (After Open Food Facts Removal)

The app still has access to meal/nutrition data from:
1. **TheMealDB** - Recipe and meal information (TheMealDBClient.swift) - **REMOVED IN PART 3**
2. **TheCocktailDB** - Cocktail/drink information (TheCocktailDBClient.swift) - **REMOVED IN PART 2**
3. **Local Barcode Database** - Bundled JSON and optional DuckDB (BarcodeRepository.swift)
4. **User-entered data** - Core Data storage (Meal entity)

## App Store Compliance Improvements

✅ **Eliminated large background downloads** without user consent
✅ **No longer requires BGTaskScheduler** permissions
✅ **Reduced network bandwidth** usage significantly
✅ **Simplified privacy manifest** requirements (no more tracking large downloads)
✅ **Removed background notification** permission requirement

## Next Steps

1. **Delete these files from Xcode:**
   - ParquetDownloadManager.swift
   - MealsSeedingManager.swift

2. **Remove from Info.plist** (if present):
   - `BGTaskSchedulerPermittedIdentifiers` array with `com.mealtracker.mealsseeding`

3. **Test that app builds** without these dependencies

4. **Consider:**
   - Can AppDelegate.swift be deleted entirely?
   - Are there any UI sections in SettingsView that still reference OFF downloads?
   - Any localization strings that mention "download" or "Open Food Facts"?

## Code Still Using MealsDBManager

The following files may reference MealsDBManager for TheMealDB data:
- MealsSeeder.swift
- MealsDBManager.swift
- Any views that display meal suggestions

These are **NOT affected** by this removal and should continue working normally.

---

## Part 2: TheCocktailDB API Removal

### Overview
Removed all references to TheCocktailDB API to reduce external dependencies and simplify the codebase. The app now focuses solely on meal data from TheMealDB.

### Files Deleted

#### 1. TheCocktailDBClient.swift (215 lines)
**Purpose:** Fetched cocktail and drink data from TheCocktailDB API
**Capabilities:**
- Listed drink categories from the API
- Fetched drink summaries by category
- Retrieved detailed drink information
- Mapped drink data to `MealsRepository.MealRow` format

### Files Modified

#### 1. MealsSeeder.swift
**Removed:**
- All drink fetching logic from `TheCocktailDBClient`
- Progress tracking for drink downloads in `seedMealsDBWithProgress()`
- References to alcohol/drink data in header comments

**Updated:**
- `seedMealsDB()` now only fetches meals from TheMealDB
- `seedMealsDBWithProgress()` simplified to handle meals only
- Header comments updated to remove drink/alcohol mentions

**Impact:** App now seeds only meal data, not cocktail/drink data.

#### 2. SettingsView.swift
**Updated:**
- Comment on line 41: Changed from "TheMealDB/TheCocktailDB only" to "TheMealDB only"
- Comment in `refreshMealsDBInfo()`: Changed from "TheMealDB/TheCocktailDB" to "TheMealDB"

**Impact:** Clarified that the Meals DB now contains only TheMealDB data.

#### 3. REMOVAL_SUMMARY.md
**Updated:**
- Added Part 2 section documenting TheCocktailDB removal
- Updated title to reflect both removals
- Updated remaining data sources list to note CocktailDB removal

### Benefits of Removal

✅ **Reduced external API dependencies** - One fewer external service to maintain
✅ **Simplified codebase** - Less code to maintain and test
✅ **Focused data model** - App now focuses on meals/food rather than drinks
✅ **Faster seeding** - Fewer API calls during database initialization
✅ **Lower network usage** - Eliminated all cocktail data downloads

### Remaining Meal Data Sources (After Both Removals)

The app now has access to meal/nutrition data from:
1. **TheMealDB** - Recipe and meal information (TheMealDBClient.swift) - **REMOVED IN PART 3**
2. **Local Barcode Database** - Bundled JSON and optional DuckDB (BarcodeRepository.swift)
3. **User-entered data** - Core Data storage (Meal entity)

### Next Steps

1. **Delete TheCocktailDBClient.swift from Xcode** if not already removed
2. **Test meal seeding** to ensure it works with TheMealDB only
3. **Verify database** contains expected meal data
4. **Update documentation** if there are user-facing mentions of drink/cocktail features
5. **Consider removing** alcohol-related fields from the data model if no longer needed

---

## Part 3: TheMealDB API Removal

### Overview
Removed all references to TheMealDB API to eliminate unused external dependencies. The app was not actively using this API—the code existed but was never triggered. The Meals.duckdb database was either empty or populated with data that had no nutritional value.

### Files Deleted

#### 1. TheMealDBClient.swift (222 lines)
**Purpose:** Fetched recipe and meal data from TheMealDB API
**Capabilities:**
- Listed meal categories from the API
- Fetched meal summaries by category
- Retrieved detailed meal information (name, category, instructions)
- Mapped meal data to `MealsRepository.MealRow` format
- **Note:** Did NOT provide nutritional information—all nutrition fields were set to `nil`

#### 2. MealsSeeder.swift (93 lines)
**Purpose:** Orchestrated fetching meals from TheMealDB and storing them in Meals.duckdb
**Capabilities:**
- Called TheMealDBClient to fetch meals
- Upserted meals into MealsRepository
- Provided progress tracking
- **Note:** Was never called by any UI or background process

#### 3. MealsRepository.swift (278 lines)
**Purpose:** Actor-based repository for accessing Meals.duckdb
**Capabilities:**
- Fetch meals by ID
- Search meals by title/description
- Upsert meal data
- **Note:** Only used by MealsSeeder, which was never called

#### 4. MealsDBManager.swift (235 lines)
**Purpose:** Managed the Meals.duckdb database file
**Capabilities:**
- Created/opened DuckDB connection
- Managed database schema
- Handled file operations (size, existence, deletion)
- **Note:** Only used by MealsRepository

### Files Modified

#### 1. SettingsView.swift
**Removed:**
- State variables: `mealsDBExists`, `mealsDBSizeBytes`, `showingMealsDeleteConfirm`
- Method: `refreshMealsDBInfo()`
- Call to `refreshMealsDBInfo()` in `.onAppear`

**Impact:** Removed UI state tracking for unused Meals database.

#### 2. REMOVAL_SUMMARY.md
**Updated:**
- Title to include TheMealDB removal
- Overview to mention three removals instead of two
- Added Part 3 section documenting TheMealDB removal
- Updated remaining data sources lists to note TheMealDB removal

### Why This Was Removed

❌ **Never actually used** - No UI trigger existed to call the seeding functions  
❌ **No nutritional value** - TheMealDB API doesn't provide nutrition data (calories, macros, etc.)  
❌ **Empty or useless database** - Meals.duckdb either didn't exist or contained meal names without nutrition  
✅ **Reduces complexity** - Less code to maintain  
✅ **Fewer dependencies** - One fewer external API  
✅ **Cleaner architecture** - Removes unused DuckDB integration

### Benefits of Removal

✅ **Eliminated unused code** - Removed ~828 lines of dormant code  
✅ **Reduced external dependencies** - No more TheMealDB API calls  
✅ **Simplified data model** - No need for DuckDB-backed meal reference system  
✅ **Cleaner codebase** - Easier to understand and maintain  
✅ **Lower maintenance burden** - Fewer potential breaking changes from external APIs

### Remaining Meal Data Sources (After All Three Removals)

The app now has access to meal/nutrition data from:
1. **Local Barcode Database** - Bundled JSON and optional DuckDB with actual nutrition data (BarcodeRepository.swift)
2. **User-entered data** - Core Data storage (Meal entity) with full nutrition tracking

### Next Steps

1. **Delete these files from Xcode:**
   - TheMealDBClient.swift
   - MealsSeeder.swift
   - MealsRepository.swift
   - MealsDBManager.swift

2. **Optional cleanup:**
   - Delete DuckDBManager.swift if it's not used elsewhere
   - Remove DuckDB package dependency if no longer needed
   - Delete any bundled Meals.duckdb file from app bundle

3. **Test the app** to ensure:
   - Barcode scanning still works
   - User meal entry/editing works
   - No crashes or missing references

4. **Consider:**
   - Are there any localization strings mentioning "meal database" or "download meals"?
   - Any user documentation that mentions these features?
