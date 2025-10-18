# Screenshot Flow Diagnostic Guide

## Expected vs Actual Behavior

### What Epic 4 Actually Does (By Design):

1. ✅ User takes screenshot → iOS notification
2. ✅ App detects screenshot → writes to App Group
3. ✅ Keyboard polls → detects notification
4. ✅ Banner appears: "Screenshot taken - Scan for scams?"
5. ✅ User taps "Scan Now" → Opens app to Scan tab
6. **❌ STOPS HERE - User must manually:**
   - Tap "Scan My Screen" button
   - Select the screenshot from Photos
   - Confirm and scan
   - **THEN** backend receives request

### What You're Expecting (Not Implemented):

Automatic end-to-end flow where screenshot is immediately sent to backend.

## Root Cause Analysis

**The screenshot is NOT automatically sent to backend because:**

1. **iOS Privacy Restrictions:**
   - Apps cannot automatically access photos without explicit user selection
   - Even with "All Photos" permission, automatic access may violate App Store guidelines
   - PhotosPicker UI enforces user selection

2. **Epic 4 Scope:**
   - Only implements **notification and navigation**
   - Does NOT implement **automatic scanning**
   - Manual selection is intentional (see PRD line 81: "opens to scan screen")

3. **Missing Implementation:**
   - No automatic screenshot fetching from Photos library
   - No automatic scan trigger on deep link
   - No deep link parameter passing screenshot info

## Diagnostic Steps

### Step 1: Verify Screenshot Detection

**Test:** Take screenshot with app in foreground

**Check Console Logs:**
```
ScreenshotNotificationManager: Screenshot notification created - ID: <UUID>
```

**If Missing:** Screenshot detection not working
**If Present:** Detection works, continue to Step 2

### Step 2: Verify App Group Writing

**Check Logs:**
```
SharedStorageManager: Wrote screenshot notification - ID: <UUID>
```

**Manual Verification:**
```swift
// Add temporary code to TypeSafeApp.swift onAppear:
let notifications = SharedStorageManager.shared.getActiveScreenshotNotifications()
print("DEBUG: Active notifications: \(notifications.count)")
```

**If Missing:** App Group write failing
**If Present:** Continue to Step 3

### Step 3: Verify Keyboard Polling

**Test:** Take screenshot with keyboard open

**Check Console Logs:**
```
ScreenshotNotificationService: New screenshot notification detected
KeyboardViewController: Handling screenshot notification
KeyboardViewController: Screenshot alert banner displayed
```

**If Missing:** Keyboard not polling or not detecting
**If Present:** Continue to Step 4

### Step 4: Verify Deep Link

**Test:** Tap "Scan Now" button

**Check Console Logs:**
```
KeyboardViewController: Launching companion app for screenshot scan
DeepLinkCoordinator: Received URL: typesafe://scan
DeepLinkCoordinator: Navigating to scan view
MainTabView: Deep link triggered - navigating to scan tab
```

**If Missing:** Deep link broken
**If Present:** Deep link works, but automatic scan not implemented

### Step 5: Verify Settings

**Check these settings are enabled:**

1. **Screenshot Detection:** Settings → Screenshot Scan Prompts
2. **Send Screenshot Images:** Settings → Privacy → Send Screenshot Images
3. **Keyboard Full Access:** iOS Settings → Keyboard → TypeSafe → Full Access

**Important:** Even with all settings enabled, manual selection is still required.

## Current Implementation Gap

### What's Implemented:
- ✅ Screenshot detection (Story 4.1)
- ✅ Keyboard notification banner (Story 4.2)
- ✅ Deep link navigation
- ✅ Manual photo selection and scanning (Epic 3)

### What's NOT Implemented:
- ❌ Automatic screenshot fetching from Photos
- ❌ Auto-trigger scan on deep link
- ❌ Background/automatic backend upload

## Solutions

### Option 1: Implement Automatic Scan (Requires New Story)

**Implementation Required:**

1. **Add Photos Framework Integration:**
```swift
import Photos

func fetchMostRecentScreenshot() -> PHAsset? {
    let fetchOptions = PHFetchOptions()
    fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
    fetchOptions.predicate = NSPredicate(format: "mediaSubtype == %d", 
                                         PHAssetMediaSubtype.photoScreenshot.rawValue)
    fetchOptions.fetchLimit = 1
    
    let fetchResult = PHAsset.fetchAssets(with: .image, options: fetchOptions)
    return fetchResult.firstObject
}
```

2. **Modify ScanView to Accept Deep Link Parameter:**
```swift
struct ScanView: View {
    @EnvironmentObject private var deepLinkCoordinator: DeepLinkCoordinator
    
    var body: some View {
        // ...
        .onChange(of: deepLinkCoordinator.shouldNavigateToScan) { shouldScan in
            if shouldScan {
                autoSelectAndScanScreenshot()
            }
        }
    }
    
    private func autoSelectAndScanScreenshot() {
        // 1. Fetch most recent screenshot
        // 2. Convert PHAsset to UIImage
        // 3. Trigger OCR and scan automatically
    }
}
```

3. **Privacy Considerations:**
   - Request Photos library access on app launch
   - Add NSPhotoLibraryUsageDescription to Info.plist
   - Document that automatic access will be used
   - May require App Store review explanation

4. **Testing:**
   - Verify works across iOS versions
   - Test with "Limited Photos" access
   - Test with denied permissions
   - Verify App Store compliance

### Option 2: Keep Manual Flow (Recommended for v1)

**Benefits:**
- Complies with iOS privacy guidelines
- Clearer user intent (explicit selection)
- Passes App Store review easily
- Users understand what's being shared

**User Experience:**
1. Take screenshot → Banner appears
2. Tap "Scan Now" → App opens to Scan tab
3. **One additional tap:** "Scan My Screen"
4. Select screenshot → Backend scan

**This adds only 1-2 seconds to the flow.**

## Recommended Path Forward

### Immediate (Keep Current Implementation):
The current flow works correctly for a v1.0 release:
- Screenshot detection ✅
- Keyboard notification ✅
- Quick access to scan ✅
- Privacy-compliant ✅

### Future Enhancement (Epic 4.5 or v1.1):
Create a new story for automatic screenshot scanning:
- **Story 4.5: Automatic Screenshot Scan on Deep Link**
- Implement photo library integration
- Auto-select most recent screenshot
- Auto-trigger OCR and backend scan
- Handle edge cases and permissions
- App Store compliance review

## What To Do Right Now

1. **Verify the current flow is working:**
   - Take screenshot → Banner appears (2-4 second delay)
   - Tap "Scan Now" → App opens to Scan tab
   - **Manually tap "Scan My Screen"**
   - Select screenshot → **Backend receives request**

2. **If banner doesn't appear:**
   - Check console logs for screenshot detection
   - Verify keyboard has Full Access enabled
   - Verify settings are enabled in app

3. **If deep link doesn't work:**
   - Rebuild app with new Info.plist
   - Verify URL scheme registered
   - Check console logs for deep link handler

4. **If backend never receives request:**
   - You might be expecting automatic behavior that isn't implemented
   - Try the full manual flow: Screenshot → Banner → Scan Now → **Scan My Screen** → Select → Scan

## Testing Checklist

- [ ] Screenshot with app in foreground → Log appears
- [ ] Screenshot with keyboard open → Banner appears within 2-4 seconds
- [ ] Banner has correct text and buttons
- [ ] Tap "Scan Now" → App opens
- [ ] App navigates to Scan tab (tab 0)
- [ ] **Manually tap "Scan My Screen"** → Photo picker appears
- [ ] Select screenshot → OCR processes
- [ ] Confirm text → **Backend receives /scan-image request** ✅
- [ ] Check backend logs for the request

## Conclusion

**The screenshot flow is working as designed.**

The "missing" piece is **automatic screenshot scanning**, which was never implemented in Epic 4. The current implementation requires one additional user tap to maintain iOS privacy compliance.

If you need automatic scanning, we need to implement Option 1 above as a new story/enhancement.

