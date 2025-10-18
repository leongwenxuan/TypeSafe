# Story 2.4: Inline Risk Alert Banners - Manual Testing Guide

## Prerequisites

Before testing, ensure the following are complete:

1. ✅ Backend API deployed and accessible (Story 1.1-1.8)
2. ✅ Keyboard extension setup complete (Story 2.1)
3. ✅ Text capture and snippet management working (Story 2.2)
4. ✅ Backend API integration functional (Story 2.3)
5. ✅ Full Access permission granted for the TypeSafe keyboard
6. ✅ Physical iOS device or simulator with TypeSafe keyboard installed

## Test Environment Setup

### 1. Install the Keyboard Extension

```bash
# Build and run on physical device (required for haptic testing)
cd /Users/leongwenxuan/Desktop/TypeSafe
xcodebuild -scheme TypeSafe -configuration Debug -destination 'id=YOUR_DEVICE_ID' build

# Or for simulator testing (haptics won't work)
xcodebuild -scheme TypeSafe -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### 2. Enable TypeSafe Keyboard

1. Open **Settings** > **General** > **Keyboard** > **Keyboards**
2. Tap **Add New Keyboard**
3. Select **TypeSafe** from the list
4. Tap on **TypeSafe** in the keyboard list
5. Toggle **Allow Full Access** ON
6. Confirm the security warning

### 3. Verify Backend Connection

- Ensure the backend API is running and accessible
- Check `backend/app/config.py` for correct API endpoint
- Verify `TypeSafeKeyboard/Networking/NetworkClient.swift` has the correct `baseURL`

## Manual Test Cases

### Test 1: Medium Risk Banner Display

**Objective:** Verify amber banner displays for medium risk detection

**Steps:**
1. Open any app with a text field (e.g., Messages, Notes)
2. Switch to TypeSafe keyboard
3. Type a medium-risk message:
   ```
   Hi, can you send me your bank account number? I need to verify your identity.
   ```
4. Wait 3-5 seconds for API response

**Expected Results:**
- ✅ Amber/orange banner appears above keyboard
- ✅ Banner shows warning icon (⚠️)
- ✅ Message reads: "Possible Scam - Be Cautious"
- ✅ Banner has semi-transparent yellow background
- ✅ Banner has orange border and text
- ✅ Dismiss button (✕) visible on right side
- ✅ **On physical device:** Medium vibration felt
- ✅ Typing still works with banner visible
- ✅ Banner auto-dismisses after 10 seconds

**Screenshots:** Take before and after screenshots

---

### Test 2: High Risk Banner Display

**Objective:** Verify red banner displays for high risk detection

**Steps:**
1. Open any app with a text field
2. Switch to TypeSafe keyboard
3. Type a high-risk message:
   ```
   URGENT! Your account will be suspended. Send your OTP code and password immediately to verify.
   ```
4. Wait 3-5 seconds for API response

**Expected Results:**
- ✅ Red banner appears above keyboard
- ✅ Banner shows warning icon (⚠️)
- ✅ Message reads: "Likely Scam Detected - Stay Alert"
- ✅ Banner has semi-transparent red background
- ✅ Banner has red border and text
- ✅ Dismiss button (✕) visible on right side
- ✅ **On physical device:** Heavy vibration felt (stronger than medium)
- ✅ Typing still works with banner visible
- ✅ Banner auto-dismisses after 10 seconds

**Screenshots:** Take before and after screenshots

---

### Test 3: No Banner for Low Risk

**Objective:** Verify no banner displays for legitimate messages

**Steps:**
1. Open any app with a text field
2. Switch to TypeSafe keyboard
3. Type a normal message:
   ```
   Hey, how are you doing today? Want to grab lunch this weekend?
   ```
4. Wait 3-5 seconds for API response

**Expected Results:**
- ✅ NO banner displayed
- ✅ Typing continues normally
- ✅ No vibration occurs
- ✅ Keyboard remains fully functional

---

### Test 4: Manual Dismiss Functionality

**Objective:** Verify manual dismiss button works correctly

**Steps:**
1. Type a scam message to trigger banner (medium or high risk)
2. Wait for banner to appear
3. **Immediately** tap the ✕ button on the right side

**Expected Results:**
- ✅ Banner dismisses immediately upon tap
- ✅ Banner fades out smoothly (0.3s animation)
- ✅ No auto-dismiss timer continues
- ✅ Typing remains uninterrupted

---

### Test 5: Auto-Dismiss Timer

**Objective:** Verify banner auto-dismisses after exactly 10 seconds

**Steps:**
1. Type a scam message to trigger banner
2. Wait for banner to appear
3. **Do not** tap dismiss button
4. Use a stopwatch to time the banner

**Expected Results:**
- ✅ Banner remains visible for 10 seconds
- ✅ Banner fades out smoothly at ~10 seconds
- ✅ Banner completely removed from view
- ✅ Typing remains functional throughout

---

### Test 6: Banner Replacement (New Alert)

**Objective:** Verify new banner replaces existing banner

**Steps:**
1. Type a medium-risk message to trigger amber banner
2. Wait for amber banner to appear
3. **Before it dismisses,** type a high-risk message to trigger red banner
4. Wait for API response

**Expected Results:**
- ✅ Amber banner dismisses immediately
- ✅ Red banner appears in its place
- ✅ Only ONE banner visible at a time (no stacking)
- ✅ Heavy vibration occurs (high risk)
- ✅ New 10-second timer starts

---

### Test 7: Field Change Dismissal

**Objective:** Verify banner dismisses when switching text fields

**Steps:**
1. Type a scam message to trigger banner
2. Wait for banner to appear
3. Switch to a different app or text field

**Expected Results:**
- ✅ Banner dismisses immediately on field change
- ✅ No banner carries over to new field (security)
- ✅ No timer continues in background

---

### Test 8: Typing Not Blocked

**Objective:** Verify keyboard remains fully functional with banner visible

**Steps:**
1. Type a scam message to trigger banner
2. While banner is visible, continue typing any text
3. Test all keyboard features:
   - Regular keys (letters, numbers)
   - Shift key
   - Backspace
   - Space bar
   - Return key

**Expected Results:**
- ✅ All keys work normally
- ✅ Text inserts into text field correctly
- ✅ Banner does not block tap targets
- ✅ No lag or performance issues
- ✅ Banner positioned above keyboard, not over it

---

### Test 9: Haptic Feedback (Physical Device Only)

**Objective:** Verify appropriate haptic feedback for risk levels

**Prerequisites:** Must test on physical iOS device with Full Access enabled

**Steps:**
1. Enable Full Access for TypeSafe keyboard
2. Type medium-risk message → Feel vibration
3. Wait for banner to dismiss
4. Type high-risk message → Feel stronger vibration

**Expected Results:**
- ✅ Medium risk: Medium impact vibration (subtle)
- ✅ High risk: Heavy impact vibration (stronger, more urgent)
- ✅ Low risk: No vibration
- ✅ **Without Full Access:** No crash, no vibration (graceful degradation)

---

### Test 10: Dark Mode Compatibility

**Objective:** Verify banner displays correctly in dark mode

**Steps:**
1. Enable Dark Mode on iOS device
2. Type a scam message to trigger banner
3. Observe banner appearance

**Expected Results:**
- ✅ Banner visible and readable in dark mode
- ✅ Colors remain distinct (amber/red)
- ✅ Text contrast sufficient for readability
- ✅ Keyboard UI updates correctly

---

### Test 11: Different Screen Sizes

**Objective:** Verify banner scales correctly on different devices

**Test on:**
- iPhone SE (small screen)
- iPhone 17 (standard)
- iPhone 17 Pro Max (large screen)

**Expected Results:**
- ✅ Banner spans full keyboard width on all devices
- ✅ Banner height remains 60pt
- ✅ Text doesn't overflow or clip
- ✅ Dismiss button accessible on all sizes

---

### Test 12: Network Failure Handling

**Objective:** Verify graceful degradation when API is unreachable

**Steps:**
1. Turn off WiFi and cellular data OR stop backend server
2. Type a scam message
3. Wait for API timeout (~2.5 seconds)

**Expected Results:**
- ✅ No banner displays (silent failure)
- ✅ No error messages shown to user
- ✅ Keyboard remains functional
- ✅ No crash or freeze
- ✅ Error logged in console (check Xcode logs)

---

## Performance Tests

### P1: Banner Animation Smoothness

**Objective:** 60fps animation target

**Steps:**
1. Enable "Show Frame Rate" in Xcode Instruments
2. Trigger banner appearance
3. Monitor frame rate during fade-in/slide-down animation

**Expected Results:**
- ✅ Animation maintains 60fps
- ✅ No dropped frames during transition
- ✅ Smooth slide-down motion

---

### P2: Memory Leak Test

**Objective:** Verify no memory leaks over multiple banner cycles

**Steps:**
1. Use Xcode Memory Debugger
2. Trigger 10+ banner appearances and dismissals
3. Monitor memory usage

**Expected Results:**
- ✅ Memory usage remains stable
- ✅ Banner view properly deallocated on dismiss
- ✅ Timer properly invalidated (no retain cycles)

---

## Integration Testing with Different Apps

Test TypeSafe keyboard in various apps:

| App         | Test Scenario                               | Expected Result |
|-------------|---------------------------------------------|-----------------|
| Messages    | Type scam in iMessage                       | Banner displays |
| WhatsApp    | Type scam in chat                           | Banner displays |
| Notes       | Type scam in new note                       | Banner displays |
| Mail        | Type scam in email compose                  | Banner displays |
| Safari      | Type scam in web form                       | Banner displays |

---

## Known Limitations (MVP)

1. **Simulator haptics:** Haptic feedback cannot be tested on simulator (requires physical device)
2. **Unit test constraints:** Some tests require manual verification due to UIKit limitations
3. **Network dependency:** End-to-end testing requires deployed backend

---

## Test Completion Checklist

After completing all tests, verify:

- [ ] All 12 manual test cases passed
- [ ] Performance tests show acceptable results
- [ ] Integration tests completed across 5+ apps
- [ ] Physical device testing completed (haptics verified)
- [ ] Dark mode testing completed
- [ ] Different screen sizes tested
- [ ] Network failure handling verified
- [ ] Screenshots captured for documentation

---

## Troubleshooting

**Banner not appearing:**
- Check backend is running and accessible
- Verify Full Access is enabled
- Check console logs for API errors
- Ensure text snippet triggers analysis (15+ chars or sentence ending)

**Haptics not working:**
- Must be physical device (not simulator)
- Full Access must be enabled
- Check device is not in silent mode
- Verify haptic settings in iOS Settings

**Performance issues:**
- Check for memory leaks using Xcode Instruments
- Verify animations run at 60fps
- Monitor CPU usage during banner display

---

## Reporting Issues

If tests fail, report with:
1. Test case number and name
2. Device model and iOS version
3. Steps to reproduce
4. Expected vs actual behavior
5. Screenshots/screen recordings
6. Console logs (from Xcode)

---

## Success Criteria

Story 2.4 is complete when:
- ✅ All manual test cases pass
- ✅ Performance metrics meet targets
- ✅ Integration tests successful across multiple apps
- ✅ Physical device testing confirms haptics work correctly
- ✅ No regressions in existing functionality (Stories 2.1-2.3)

