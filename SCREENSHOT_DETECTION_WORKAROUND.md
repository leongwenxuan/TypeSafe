# Screenshot Detection Workaround - Keyboard-Based Detection

## Problem

**iOS Limitation:** The main TypeSafe app cannot reliably detect screenshots when it's suspended in the background. When a user:
1. Is typing in Messages (main app suspended)
2. Takes a screenshot
3. The main app doesn't wake up to detect it

`UIApplication.userDidTakeScreenshotNotification` **only fires when the app is in foreground or recently backgrounded** (< 5 seconds).

## Solution

**The keyboard extension itself polls the Photos library** to detect new screenshots!

### How It Works

```
User typing in Messages
       ↓
TypeSafe Keyboard is active
       ↓
Every 3 seconds: Keyboard checks Photos for new screenshots
       ↓
Screenshot taken!
       ↓
Keyboard detects it within 3 seconds
       ↓
🟢 "Screenshot detected directly by keyboard!"
       ↓
Banner appears: "Screenshot taken - Scan for scams?"
       ↓
User taps "Scan Now"
       ↓
Deep link: typesafe://scan?auto=true
       ↓
Main app opens, auto-fetches screenshot
       ↓
Results displayed
```

## Implementation

### New File: `ScreenshotDetectionService.swift`

Located in: `TypeSafeKeyboard/`

**Key Features:**
- Polls Photos library every 3 seconds
- Uses `PHAsset.fetchAssets` with screenshot filter
- Tracks last detected screenshot date
- Only triggers for screenshots < 10 seconds old
- Lightweight queries (fetch limit = 1)

**Method:**
```swift
startPolling(onScreenshotDetected: @escaping () -> Void)
```

### Updated: `KeyboardViewController.swift`

**Added:**
```swift
private var screenshotDetectionService: ScreenshotDetectionService?
```

**In `setupScreenshotNotificationPolling()`:**
- Initializes both services:
  1. `ScreenshotNotificationService` (reads from App Group - main app detection)
  2. `ScreenshotDetectionService` (NEW - direct Photos polling)
- Creates synthetic notification when screenshot detected
- Reuses existing `handleScreenshotNotification()` flow

**In `viewWillDisappear()`:**
- Stops both services to save battery

## Dual Detection System

Now the keyboard has **TWO ways** to detect screenshots:

### Method 1: Main App Detection (Original)
- Main app detects screenshot (when active)
- Writes to App Group
- Keyboard polls App Group

### Method 2: Keyboard Direct Detection (NEW - Workaround)
- Keyboard polls Photos library
- Detects screenshot directly
- Creates synthetic notification

**Result:** Whichever detects it first wins!

## Requirements

### Permissions Required:
1. **Full Access** - Already required, enables Photos access in keyboard
2. **Photos Permission** - Shared with main app, already requested

### Performance Impact:
- Photos query every 3 seconds
- Very lightweight (fetch limit = 1, sorted by date descending)
- Only runs when keyboard is visible
- Stops when keyboard dismissed

## Configuration

### Adjustable Parameters (in `ScreenshotDetectionService.swift`):

```swift
// How often to check (default: 3 seconds)
private let pollingInterval: TimeInterval = 3.0

// How recent screenshot must be to trigger (default: 10 seconds)
private let screenshotRecencyThreshold: TimeInterval = 10.0
```

**Lower polling interval = faster detection but more battery usage**

## Testing

### Test Scenario 1: Main App Active
1. Open TypeSafe app
2. Take screenshot
3. Should see: `🟢 SCREENSHOT DETECTED!` (main app)
4. Switch to Messages, open keyboard
5. Banner appears

### Test Scenario 2: Main App Suspended (THE FIX)
1. Open Messages
2. Switch to TypeSafe keyboard
3. Take screenshot
4. Wait up to 3 seconds
5. Should see: `🟢 KeyboardViewController: Screenshot detected directly by keyboard!`
6. Banner appears within 3 seconds!

### Test Scenario 3: Keyboard Not Open
1. Take screenshot while typing on default keyboard
2. Nothing happens (expected)
3. Switch to TypeSafe keyboard
4. If screenshot < 10 seconds old, banner appears!

## Console Logs to Watch

### Success Case (Keyboard Detection):
```
KeyboardViewController: Direct screenshot detection initialized
🟢 ScreenshotDetectionService: NEW SCREENSHOT DETECTED!
   Screenshot date: 2025-10-18 10:30:45
   Age: 2.3s
🟢 KeyboardViewController: Screenshot detected directly by keyboard!
KeyboardViewController: Handling screenshot notification
KeyboardViewController: Screenshot alert banner displayed
```

### Both Methods Fire (Rare):
```
🟢 SCREENSHOT DETECTED! (main app)
🟢 ScreenshotDetectionService: NEW SCREENSHOT DETECTED! (keyboard)
```
→ Banner shows once (deduplicated by notification handler)

## Advantages

✅ **Works when main app suspended** - Primary goal achieved!
✅ **No background modes needed** - Stays within iOS guidelines
✅ **Leverages existing permissions** - Full Access already required
✅ **Reuses existing flow** - Same banner, same deep link
✅ **Dual redundancy** - Two detection methods for reliability
✅ **User-initiated context** - Only detects when user is actively using keyboard

## Limitations

⚠️ **Detection delay:** Up to 3 seconds (vs instant with main app)
⚠️ **Requires keyboard open:** Only detects while keyboard is visible
⚠️ **Battery impact:** Small (pauses when keyboard dismissed)
⚠️ **Requires Full Access:** Users must grant this permission

## Future Optimizations

### Possible Improvements:
1. **Adaptive polling:** Speed up when user activity detected
2. **Smart suspend:** Stop polling after 60 seconds of no screenshots
3. **Cache last check:** Persist across keyboard sessions
4. **User preference:** Allow users to disable if concerned about battery

## Privacy Considerations

**What keyboard accesses:**
- Creation date of most recent screenshot only
- NO screenshot content read
- NO other photos accessed
- NO data sent anywhere

**Privacy-safe because:**
- Only reads metadata (date)
- Only checks most recent (fetch limit = 1)
- Only triggers for very recent screenshots (< 10s)
- Only runs when user is actively using keyboard

## Summary

This workaround **solves the iOS limitation** by detecting screenshots directly from the keyboard extension, which has the necessary permissions and remains active while the user is typing.

**The flow now works end-to-end:**
Screenshot → Keyboard Detection → Banner → Scan Now → Auto-fetch → Results

🎉 **Problem solved!**

