# Screenshot Detection Not Working - Quick Debug Guide

## Step 1: Check Console Logs

When you take a screenshot in the **main app** (not keyboard), you should see:

```
ScreenshotNotificationManager: Screenshot notification created - ID: [uuid]
```

**If you DON'T see this log:**
- Screenshot detection is not working in the main app
- The feature is disabled or not registered

---

## Step 2: Check Settings in Main App

Open the TypeSafe app → Settings tab

**Required Settings (ALL must be ON):**
1. ✅ **Screenshot Detection** - Enables detection in main app
2. ✅ **Screenshot Scan Prompts** - Enables banner in keyboard
3. ✅ **Automatic Screenshot Scanning** - Enables auto-fetch

**How to verify in code:**

Run these commands in Xcode debugger when app is running:
```
po SettingsManager.shared.settings.screenshotDetectionEnabled
po SettingsManager.shared.settings.screenshotScanPromptsEnabled  
po SettingsManager.shared.settings.automaticScreenshotScanEnabled
```

All should return `true`

---

## Step 3: Are You Testing in Simulator or Device?

⚠️ **CRITICAL:** Screenshot detection has different behavior:

### Simulator:
- ❌ Photos Framework doesn't work (no real Photos library)
- ✅ Screenshot detection notification DOES work
- You can test Step 1 (detection) but NOT auto-fetch

### Physical Device:
- ✅ Everything works
- Screenshots go to actual Photos library
- Auto-fetch can retrieve them

**Solution:** You MUST test on a **real device** for the full flow!

---

## Step 4: Check Keyboard Extension Settings

The keyboard extension needs:

1. **Full Access granted:**
   - Settings → General → Keyboard → TypeSafe
   - "Allow Full Access" = ON

2. **Keyboard is active:**
   - Settings → General → Keyboard → Keyboards
   - TypeSafe keyboard should be in the list

3. **In an app with text input:**
   - Open Messages, Notes, or Safari
   - Tap a text field
   - Switch to TypeSafe keyboard (globe icon)

---

## Step 5: Testing Sequence

### A. Test Main App Screenshot Detection (Simulator OK)

1. **Open main TypeSafe app**
2. Keep Xcode console visible
3. **Take a screenshot** (Cmd+S in simulator, or Volume+Power on device)
4. **Look for log:**
   ```
   ScreenshotNotificationManager: Screenshot notification created
   ```

**If you see this ✅:**
- Detection works!
- Move to Step B

**If you DON'T see this ❌:**
- Settings are off OR
- Registration failed
- Check Step 2 and run this fix:

---

## Step 6: Quick Fix Commands

If screenshot detection isn't working, try this in Xcode console while app is running:

```lldb
# Check if manager is registered
po ScreenshotNotificationManager.shared

# Manually trigger registration
expr ScreenshotNotificationManager.shared.registerForScreenshotNotifications()

# Check if it's enabled
expr ScreenshotNotificationManager.shared.setEnabled(true)

# Check settings
po SettingsManager.shared.settings
```

---

## Step 7: Check App Group Access

The keyboard needs to read notifications from App Group:

```
group.com.typesafe.shared
```

**Verify in Xcode:**
1. Select **TypeSafe target** → Signing & Capabilities
2. Check "App Groups" capability exists
3. Verify `group.com.typesafe.shared` is listed

4. Select **TypeSafeKeyboard target** → Signing & Capabilities
5. Check "App Groups" capability exists
6. Verify **SAME** `group.com.typesafe.shared` is listed

---

## Step 8: Full Flow Test (Device Only)

Once Step 5A works, test the full flow on a **physical device:**

1. **Open Settings** in TypeSafe app
   - Verify all 3 toggles are ON
   - Grant Photos permission (should show "Full Access")

2. **Open Messages** or Notes app

3. **Switch to TypeSafe keyboard**

4. **Take a screenshot**

5. **Wait 2-5 seconds** - Watch for blue banner above keyboard

6. **Look for console log:**
   ```
   ScreenshotNotificationService: New screenshot notification detected
   KeyboardViewController: Screenshot alert banner displayed
   ```

7. **Tap "Scan Now"** on the banner

8. **App should open and show:**
   - "Loading Your Screenshot..."
   - "Extracting Text..."
   - "Analyzing for Scams..."
   - Results screen

---

## Common Issues

### Issue 1: "Nothing happens" when screenshot taken

**Cause:** Settings are disabled OR testing in simulator

**Fix:**
1. Check all 3 settings are ON in main app
2. Test on physical device
3. Check console logs in Step 5A

### Issue 2: Banner doesn't appear in keyboard

**Cause:** 
- Full Access not granted OR
- Keyboard extension can't read App Group OR
- Settings disabled in keyboard extension

**Fix:**
1. Grant Full Access in Settings
2. Verify App Groups match in both targets
3. Check keyboard console for polling logs:
   ```
   ScreenshotNotificationService: Starting polling
   ```

### Issue 3: Banner appears but "Scan Now" does nothing

**Cause:** Deep link not registered OR app not in foreground

**Fix:**
1. Check Info.plist has URL scheme `typesafe`
2. Make sure app is running (not force-quit)
3. Try opening app manually first

### Issue 4: App opens but shows manual picker

**Cause:** Auto-scan is disabled OR Photos permission denied

**Fix:**
1. Settings → Automatic Screenshot Scanning = ON
2. Settings → Photos → TypeSafe → "Full Access"

---

## Quick Test Script

Run this sequence to test each component:

```bash
# 1. Launch app
open TypeSafe.app

# 2. In Xcode console, verify registration:
po ScreenshotNotificationManager.shared

# 3. Take screenshot in simulator
# (Cmd+S or Edit → Take Screenshot)

# 4. Look for log:
# "Screenshot notification created"

# 5. If no log, manually enable:
expr SettingsManager.shared.updateScreenshotDetectionSetting(true)
expr SettingsManager.shared.updateScreenshotScanPromptsSetting(true)
expr SettingsManager.shared.updateAutomaticScanSetting(true)

# 6. Try screenshot again
```

---

## What to Share for Help

If still not working, share:

1. **Screenshot of Settings page** (all toggles visible)
2. **Console logs** when you take a screenshot
3. **Testing on:** Simulator or Device (which model?)
4. **Xcode version:**
5. **Output of:**
   ```
   po SettingsManager.shared.settings
   ```

---

## Expected Behavior Summary

✅ **Working correctly looks like:**

1. Take screenshot → See log "Screenshot notification created"
2. Switch to keyboard → See banner within 2-5 seconds
3. Tap "Scan Now" → App opens immediately
4. See "Loading Your Screenshot..." → "Extracting Text..." → "Analyzing for Scams..."
5. Results appear in 5-8 seconds total

If ANY step fails, that's where the issue is!

