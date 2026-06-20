# App Store Readiness Checklist - MealTracker (Local-Only App)

## ✅ COMPLETED FIXES

### 1. ✅ Removed Background Task Scheduling
- **File:** `MealTrackerApp.swift`
- **Action:** Removed BackgroundTasks import and all BGTaskScheduler code
- **Reason:** Not needed for local-only app; causes App Review questions

### 2. ✅ Added Privacy Statement to About Screen
- **File:** `AboutView.swift`
- **Action:** Added clear privacy statement that data is local-only
- **Reason:** Required even without external privacy policy URL

### 3. ✅ Created Privacy Manifest
- **File:** `PrivacyInfo.xcprivacy` (NEW)
- **Action:** Created required privacy manifest for iOS 17+
- **Reason:** Mandatory for App Store submission as of May 2024

### 4. ✅ Created Info.plist Template
- **File:** `INFO_PLIST_REQUIRED_ENTRIES.plist` (NEW)
- **Action:** Template with all required privacy usage descriptions
- **Reason:** Must explain camera, photos, and location access

---

## 🚨 CRITICAL - YOU MUST DO THESE MANUALLY

### 1. DELETE ParquetDownloadManager.swift
**Location:** `/repo/ParquetDownloadManager.swift`

**Action Required:**
```
1. In Xcode, select ParquetDownloadManager.swift
2. Right-click → Delete → Move to Trash
```

**Why:** This file downloads data from HuggingFace (external network). Will cause instant rejection since you claim "local-only".

### 2. REMOVE MealsSeedingManager References
**Search your project for:** `MealsSeedingManager`

**Files likely affected:**
- `SettingsView.swift` (lines checking mealsDB status)
- Any imports or references to seeding

**Action:** Delete or comment out all references

### 3. ADD Privacy Strings to Info.plist

**In Xcode:**
1. Open your `Info.plist` file
2. Add a new row (click the + button)
3. Add each of these keys with the suggested values:

```
Key: Privacy - Camera Usage Description
Value: MealTracker needs camera access to photograph your meals. Photos are stored locally on your device.

Key: Privacy - Photo Library Usage Description  
Value: MealTracker needs photo library access to select meal photos. Photos are stored locally on your device.

Key: Privacy - Location When In Use Usage Description
Value: MealTracker can optionally tag meals with location. This is optional and all data stays on your device.
```

**⚠️ CRITICAL:** If you don't use location, also delete `LocationManager.swift`

### 4. ADD PrivacyInfo.xcprivacy to Xcode Project

**Steps:**
1. In Xcode, drag `PrivacyInfo.xcprivacy` from Finder into your project
2. Check "Copy items if needed"
3. Make sure it's in your app target (check the box)
4. Build the project to verify no errors

---

## ⚠️ DECISIONS YOU NEED TO MAKE

### Decision 1: Location Feature
**Current:** App has `LocationManager.swift` for optional location tagging

**Options:**
- **KEEP:** Add location usage string to Info.plist (see above)
- **REMOVE:** Delete `LocationManager.swift` and remove location permission

**Recommendation:** If not actively using it, REMOVE to simplify App Review

**To remove:**
1. Delete `LocationManager.swift`
2. Remove any `@StateObject var locationManager` references
3. Remove location permission from Info.plist

---

### Decision 2: SessionManager & Login System
**Current:** Code references `SessionManager` with `.isLoggedIn` checks

**Question:** Does your app actually have login/accounts?

**If NO (recommended for local-only):**
- Remove or stub out SessionManager
- Remove all tier checking code
- Simplify to just local data

**If YES:**
- You MUST add privacy policy URL
- You MUST implement "Sign in with Apple" if you have other social logins
- This contradicts "local-only" claim

---

### Decision 3: In-App Purchases
**Current:** Code has `Entitlements.tier()` with `.free` and `.paid` tiers

**Question:** Are you implementing IAP for Pro features?

**If NO:**
- Remove all Entitlements code
- Remove tier checks
- Remove photo/meal limits

**If YES:**
- Implement StoreKit 2
- Add restore purchases
- Cannot claim "no data collection" (Apple requires IAP metadata)

---

## 📋 APP STORE CONNECT CHECKLIST

Before you submit in App Store Connect:

### App Information
- [ ] App name (check availability)
- [ ] Subtitle (optional, 30 chars)
- [ ] Category: **Health & Fitness** or **Food & Drink**
- [ ] Age Rating: **4+** (if no concerning content)

### Privacy
- [ ] Select: **"No, this app does not collect data"**
  - ⚠️ UNLESS you add login/IAP - then must disclose
- [ ] Privacy Policy URL: 
  - If truly local-only: **Optional but recommended**
  - Use About screen as in-app privacy statement
- [ ] If you add external privacy URL: Must be publicly accessible (https)

### Support & Marketing
- [ ] Support URL or email: **REQUIRED**
  - Example: `mailto:support@yourname.com`
- [ ] Marketing URL: Optional
- [ ] Copyright: Your name, year

### Export Compliance
- [ ] Question: "Does your app use encryption?"
  - Answer: **NO** (assuming you use only standard iOS encryption)
  - If asked about HTTPS: This doesn't count as export-controlled

### App Review Information
- [ ] Contact email: **REQUIRED**
- [ ] Phone number: **REQUIRED**
- [ ] Review notes: 
```
MealTracker is a local-only nutrition tracking app. All data is stored 
using Core Data on the user's device. No data is transmitted or collected.

Camera: Used to photograph meals (optional)
Photos: Used to select meal images (optional)
Location: Optional meal tagging (can be disabled)

Test account: Not required - no login system
```

---

## 🧪 TESTING BEFORE SUBMISSION

### Required Tests

#### 1. Test All Permissions
- [ ] Launch app → try to take photo → camera permission appears
- [ ] Permission message matches Info.plist text
- [ ] Deny permission → app doesn't crash
- [ ] Go to Settings → reset permissions → test again

#### 2. Test Offline Mode
- [ ] Enable Airplane Mode
- [ ] Launch app → should work perfectly
- [ ] Create meal → save → verify it saves
- [ ] If anything fails in airplane mode → you have network code!

#### 3. Test on Real Device
- [ ] Must test on physical iPhone (not just simulator)
- [ ] Install via TestFlight or direct install
- [ ] Test all features work
- [ ] Check for any network activity in Settings → Cellular

#### 4. Test Core Functionality
- [ ] Create a meal with photo
- [ ] Edit a meal
- [ ] Delete a meal
- [ ] View meals gallery
- [ ] Change settings
- [ ] Force quit app → relaunch → data persists

---

## 📸 SCREENSHOTS REQUIRED

You need screenshots for App Store in these sizes:

### iPhone (Required)
- **6.7" Display** (iPhone 15 Pro Max): 1290 x 2796 pixels
- **6.5" Display** (iPhone 14 Plus): 1242 x 2688 pixels

### iPad (If supporting)
- **12.9" Display**: 2048 x 2732 pixels

**Tips:**
1. Take screenshots on device or simulator
2. Show your app's best features:
   - Meals gallery view
   - Meal entry form with photo
   - Weekly report (if you have it)
   - Settings screen
3. Add text overlays describing features (optional but recommended)

---

## 🎯 FINAL VERIFICATION

Before clicking "Submit for Review":

### Code Verification
- [ ] ✅ No `ParquetDownloadManager.swift` in project
- [ ] ✅ No `URLSession` network calls (except in debug-only code)
- [ ] ✅ No `import BackgroundTasks` in production code
- [ ] ✅ `PrivacyInfo.xcprivacy` in project and target
- [ ] ✅ All privacy strings in Info.plist

### Build Verification
- [ ] ✅ Archive for release
- [ ] ✅ No warnings about missing privacy manifest
- [ ] ✅ No warnings about missing usage descriptions
- [ ] ✅ Upload to App Store Connect succeeds

### App Store Connect Verification
- [ ] ✅ All metadata filled in
- [ ] ✅ Screenshots uploaded
- [ ] ✅ Privacy nutrition label: "No data collected"
- [ ] ✅ Support contact provided
- [ ] ✅ Build selected

---

## ⏱️ ESTIMATED TIME TO COMPLETE

- **File deletions:** 10 minutes
- **Info.plist edits:** 15 minutes
- **Add Privacy Manifest to Xcode:** 5 minutes
- **Testing:** 30-60 minutes
- **Screenshots:** 30 minutes
- **App Store Connect metadata:** 30 minutes

**Total: 2-3 hours**

---

## 🆘 COMMON REJECTION REASONS & FIXES

### Rejection: "Missing usage descriptions"
**Fix:** Add all privacy strings to Info.plist

### Rejection: "App crashes on permissions"
**Fix:** Handle denied permissions gracefully (don't crash)

### Rejection: "Privacy policy required"
**Fix:** Either add URL or cite Guideline 5.1.1(v) exception for local-only

### Rejection: "Network activity detected"
**Fix:** DELETE ParquetDownloadManager.swift and all network code

### Rejection: "Background modes not explained"
**Fix:** Remove background tasks or explain clearly in review notes

---

## ✅ WHEN YOU'RE READY

After completing all items above:

1. Clean build in Xcode (Product → Clean Build Folder)
2. Archive (Product → Archive)
3. Upload to App Store Connect
4. Fill in all metadata
5. Submit for review
6. Typical review time: **1-3 days**

Good luck! 🚀

---

## 📞 NEED HELP?

If you get rejected, the App Review team will tell you exactly what's wrong. Common issues:

1. Missing privacy strings → Add to Info.plist
2. Crash on permission denial → Test and fix
3. Network activity → Remove ParquetDownloadManager
4. Misleading privacy claims → Be honest about data usage

You can respond to rejections in App Store Connect Resolution Center.
