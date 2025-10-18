# Story 5.2 Auto-Scan Diagnostic Guide

## Issue: Screenshot taken but nothing happens

This guide helps diagnose why automatic screenshot scanning might not be working.

## Step-by-Step Diagnostic

### Step 1: Check Screenshot Detection in Main App

**Location to check:** Main App (TypeSafe target)

1. Open the main app
2. Take a screenshot
3. **Look for this console log:**
   ```
   ScreenshotNotificationManager: Screenshot notification created - ID: [some-uuid]
   ```

**If you DON'T see this log:**
- ❌ Screenshot detection is not working in main app
- **Fix:** Check if screenshot detection is registered in `TypeSafeApp.swift`
- **Verify:** The app should call `screenshotManager.registerForNotifications()` in `onAppear`

**If you DO see this log:**
- ✅ Screenshot detection is working
- Move to Step 2

---

### Step 2: Check App Group Storage

**What to verify:**
The screenshot notification should be written to App Group storage.

**Console logs to look for:**
```
ScreenshotNotificationManager: Screenshot notification created - ID: [uuid]
```

**Common issues:**
1. **App Group not configured properly**
   - Check `TypeSafe.entitlements` has: `group.com.typesafe.shared`
   - Check `TypeSafeKeyboard.entitlements` has the same group

2. **Storage write failed**
   - If you see: `Failed to access App Group storage`
   - The entitlements might not be properly signed

---

### Step 3: Check Keyboard Extension Polling

**Location to check:** Keyboard Extension (TypeSafeKeyboard target)

1. Open any app that uses the keyboard
2. Switch to TypeSafe keyboard
3. **Look for these console logs:**
   ```
   ScreenshotNotificationService: Starting polling (interval: 2.0s)
   KeyboardViewController: Screenshot notification polling started
   ```

**If you DON'T see polling logs:**
- ❌ Keyboard is not polling for notifications
- **Check:** Settings for screenshot prompts (both toggles must be ON)
- **Check:** `setupScreenshotNotificationPolling()` is called in `viewDidLoad`

**If polling is working but no notifications detected:**
- The App Group might not be accessible from keyboard
- Check entitlements match exactly

**When notification IS detected, you should see:**
```
ScreenshotNotificationService: New screenshot notification detected
  - ID: [uuid]
  - Timestamp: [time]
  - Age: [seconds]
KeyboardViewController: Screenshot alert banner displayed
```

---

### Step 4: Check Banner Display

**What should happen:**
A blue banner should appear above the keyboard saying:
```
📸 Screenshot taken - Scan for scams?
    [Scan Now]  [✕]
```

**If banner doesn't appear:**
1. Check if Full Access is granted (banner requires it)
2. Check console for: `Screenshot alert banner displayed`
3. Check if banner is being dismissed too quickly

---

### Step 5: Check Deep Link Opening

**When you tap "Scan Now":**

1. **Look for this log in keyboard:**
   ```
   KeyboardViewController: Launching companion app for screenshot scan
   KeyboardViewController: Deep link opened - success: true
   ```

2. **Then in main app:**
   ```
   DeepLinkCoordinator: Received URL: typesafe://scan?auto=true
   DeepLinkCoordinator: Navigating to scan view
   DeepLinkCoordinator: auto=true
   ```

**If deep link doesn't open:**
- ❌ URL scheme might not be registered
- **Check:** `Info.plist` has URL scheme `typesafe`
- **Check:** App is registered to handle `typesafe://` URLs

---

### Step 6: Check Auto-Scan Trigger

**When app opens with auto=true:**

**Look for these logs:**
```
ScanView: handleAutoScan triggered
```

**Then check settings:**
```
ScanView: Auto-scan disabled in settings - falling back to manual
```
OR
```
ScanView: Photos permission not granted - falling back to manual
```

**If auto-scan starts:**
```
ScreenshotFetchService: Starting fetch with 5.0s timeout
ScreenshotFetchService: Fetching most recent screenshot
ScreenshotFetchService: Found screenshot with creation date: [date]
ScreenshotFetchService: Screenshot age: [seconds] seconds, recent: true
ScreenshotFetchService: Converting asset to UIImage
ScreenshotFetchService: Successfully converted asset to UIImage
ScanView: Fetch completed successfully before timeout
```

---

## Quick Settings Checklist

Before testing, verify these settings are enabled:

### Main App Settings (TypeSafe → Settings)
- [ ] **Screenshot Detection** is ON
- [ ] **Screenshot Scan Prompts** is ON  
- [ ] **Automatic Screenshot Scanning** is ON
- [ ] **Photos Permission** is "Full Access" or "Limited Access"

### Keyboard Settings (System Settings → TypeSafe Keyboard)
- [ ] **Full Access** is granted (required for banner display)
- [ ] Keyboard is added and enabled in Settings

---

## Testing Flow

### Complete Manual Test:

1. **Open main app** and go to Settings
2. Verify all toggles are ON (see checklist above)
3. **Open any app** with text input (Messages, Notes, etc.)
4. **Switch to TypeSafe keyboard**
5. **Take a screenshot** (Volume Up + Power button)
6. **Wait 2-5 seconds** for keyboard to detect it
7. **Look for blue banner** above keyboard
8. **Tap "Scan Now"** button
9. **App should open** and show loading indicator
10. **Screenshot should auto-fetch** and proceed to OCR

---

## Common Issues & Solutions

### Issue 1: No logs at all
**Cause:** Console not filtering properly  
**Fix:** In Xcode console, search for `Screenshot` or `Auto-scan`

### Issue 2: Screenshot detected but no banner
**Cause:** Full Access not granted OR settings disabled  
**Fix:**  
1. Check Settings → General → Keyboard → TypeSafe → Allow Full Access
2. Check app settings: Screenshot Detection + Scan Prompts both ON

### Issue 3: Banner shows but "Scan Now" does nothing
**Cause:** Deep link not opening  
**Fix:**  
1. Check Info.plist has URL scheme registered
2. Check app is in foreground (iOS might block background URL opens)
3. Try force-quitting and reopening the app

### Issue 4: App opens but goes to manual picker
**Cause:** Auto-scan failed (permission, timeout, or screenshot not found)  
**Fix:** Check console for specific error:
- "Auto-scan disabled in settings" → Enable in Settings
- "Photos permission not granted" → Grant permission
- "Screenshot not found" → Screenshot might be older than 60 seconds
- "Screenshot is older than 60 seconds" → Take a fresh screenshot

### Issue 5: Fetch times out after 5 seconds
**Cause:** Screenshot fetch is taking too long (large photo library, iCloud sync)  
**Fix:**  
- This is expected behavior - it falls back to manual picker
- User can manually select the screenshot
- Consider if timeout needs to be increased for slow devices

---

## Enhanced Logging (Temporary)

To add more detailed logging for debugging, you can temporarily add these prints:

**In ScanView.swift `handleAutoScan()`:**
```swift
print("DEBUG: Settings - automaticScreenshotScanEnabled: \(settingsManager.settings.automaticScreenshotScanEnabled)")
print("DEBUG: Permission status: \(photosPermission.checkAuthorizationStatus())")
```

**In ScreenshotFetchService.swift:**
```swift
print("DEBUG: PHAsset count: \(fetchResult.count)")
print("DEBUG: First asset: \(fetchResult.firstObject != nil)")
```

---

## Expected Timeline

From screenshot to scan results:

1. **0.0s** - User takes screenshot
2. **0-2s** - App detects and writes to App Group
3. **0-2s** - Keyboard polls and detects notification  
4. **0.3s** - Banner animates in
5. **User action** - Taps "Scan Now"
6. **0.5s** - App opens via deep link
7. **0-1s** - Auto-scan checks permissions and settings
8. **0.5-2s** - Fetches screenshot from Photos
9. **1-2s** - Converts to UIImage
10. **2-3s** - OCR processing
11. **Total: ~3-8 seconds** from tap to results

---

## Next Steps

1. **Run through Steps 1-6** with console open
2. **Note which step fails** (no logs appear)
3. **Apply the corresponding fix** from Common Issues
4. **Retest** the complete flow

If you're still having issues after following this guide, share:
- Which step fails (1-6)
- Console logs you're seeing
- Settings screenshot
- Whether you're testing on simulator or device (Photos requires device!)

