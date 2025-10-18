# Story 2.5: Manual Testing Guide
## Complete Keyboard Layouts (Numbers & Symbols)

### Prerequisites
- TypeSafe keyboard extension installed on device/simulator
- Full Access enabled (Settings → General → Keyboard → TypeSafe → Allow Full Access)
- Test in both light and dark mode

### Test Environment Setup
1. Build and run TypeSafe app on simulator/device
2. Open Settings → General → Keyboard → Keyboards → Add New Keyboard → TypeSafe
3. Enable Full Access for haptic feedback testing
4. Open Notes app or Messages app for testing

---

## Test Suite

### Test 1: Layout Switching - Basic Transitions
**Objective:** Verify all layout switching buttons work correctly

**Steps:**
1. Open keyboard in Notes app
2. Verify you're on letter layout (QWERTY visible)
3. Tap "123" button → Should switch to number layout
4. Verify number layout displays: 1-9, 0 in top row
5. Tap "#+=" button → Should switch to symbol layout  
6. Verify symbol layout displays: [, ], {, }, #, %, etc.
7. Tap "123" button → Should return to number layout
8. Tap "ABC" button → Should return to letter layout

**Expected Results:**
- All layout transitions are smooth and instant (< 100ms feel)
- No visual glitches or flashing
- Correct keys displayed for each layout
- Layout state is maintained (doesn't auto-reset)

**Status:** [ ] Pass [ ] Fail

**Notes:**
_____________________________________________

---

### Test 2: Number Input
**Objective:** Verify all number keys insert correct characters

**Steps:**
1. Switch to number layout ("123" button)
2. Type each number: 0 1 2 3 4 5 6 7 8 9
3. Type symbols from row 2: - / : ; ( ) $ & @ "
4. Type symbols from row 3: . , ? ! '

**Expected Results:**
- Each key inserts the correct character
- No unexpected character substitutions
- Characters appear immediately in text field
- Snippet buffer captures numbers/symbols (check via typing trigger text)

**Actual Output:**
_____________________________________________

**Status:** [ ] Pass [ ] Fail

**Notes:**
_____________________________________________

---

### Test 3: Symbol Input
**Objective:** Verify all extended symbol keys work correctly

**Steps:**
1. Switch to symbol layout ("123" → "#+=" buttons)
2. Type row 1 symbols: [ ] { } # % ^ * + =
3. Type row 2 symbols: _ \ | ~ < > $ £ ¥ •
4. Type row 3 symbols: . , ? ! '

**Expected Results:**
- All symbols insert correctly
- Special currency symbols (£, ¥, •) render properly
- Backslash and other special characters work

**Actual Output:**
_____________________________________________

**Status:** [ ] Pass [ ] Fail

**Notes:**
_____________________________________________

---

### Test 4: Special Keys Across All Layouts
**Objective:** Verify backspace, space, return work on all layouts

**Steps:**
1. **On Letter Layout:**
   - Type "hello world"
   - Press backspace 5 times → Should delete "world"
   - Press space → Should add space
   - Press return → Should create new line

2. **On Number Layout:**
   - Type "123 456"
   - Press backspace 4 times → Should delete " 456"
   - Press space → Should add space
   - Press return → Should create new line

3. **On Symbol Layout:**
   - Type "[test]"
   - Press backspace 2 times → Should delete "]"
   - Press space → Should add space
   - Press return → Should create new line

**Expected Results:**
- Backspace deletes one character at a time on all layouts
- Space inserts space on all layouts
- Return creates new line on all layouts
- Globe button (🌐) switches keyboards on all layouts

**Status:** [ ] Pass [ ] Fail

**Notes:**
_____________________________________________

---

### Test 5: Snippet Capture Integration
**Objective:** Verify snippet capture works with numbers/symbols

**Steps:**
1. Clear any existing text in Notes
2. Type on number layout: "Call 555-1234 urgent"
3. Type on symbol layout: "Price: $99.99!!!"
4. Type text that triggers analysis (e.g., long sentence with phone number or suspicious pattern)

**Expected Results:**
- Snippet buffer captures numbers and symbols
- API analysis triggered correctly (check console logs)
- Banner appears if medium/high risk detected
- Layout switching doesn't interfere with snippet capture

**Status:** [ ] Pass [ ] Fail

**Notes:**
_____________________________________________

---

### Test 6: Banner Functionality Preserved
**Objective:** Verify banner works correctly with all layouts

**Steps:**
1. Type text that triggers medium/high risk detection
2. Verify banner appears at top of keyboard
3. Switch to number layout while banner visible
4. Switch to symbol layout while banner visible
5. Type more text on each layout
6. Dismiss banner by tapping X or waiting 10 seconds

**Expected Results:**
- Banner appears correctly on all layouts
- Layout switches don't dismiss or break banner
- Banner animation smooth during layout changes
- Banner auto-dismisses after 10 seconds
- Haptic feedback works (if Full Access enabled)

**Status:** [ ] Pass [ ] Fail

**Notes:**
_____________________________________________

---

### Test 7: Appearance and Dark Mode
**Objective:** Verify visual consistency across layouts and modes

**Steps:**
1. **Light Mode Testing:**
   - Switch between all three layouts
   - Verify button colors are consistent
   - Check spacing and alignment
   - Verify all text is readable

2. **Dark Mode Testing:**
   - Enable Dark Mode (Settings → Display & Brightness → Dark)
   - Open keyboard in Notes app
   - Switch between all three layouts
   - Verify dark theme applied correctly
   - Check button contrast and readability

**Expected Results:**
- All layouts maintain consistent visual style
- Dark mode styling applies to all layouts
- No layout alignment issues
- Button shadows render correctly
- Special keys (ABC, 123, #+= ) styled consistently

**Status:** [ ] Pass [ ] Fail

**Notes:**
_____________________________________________

---

### Test 8: Rapid Layout Switching (Stress Test)
**Objective:** Verify stability under rapid layout changes

**Steps:**
1. Rapidly tap between layouts 20+ times:
   - ABC → 123 → #+= → 123 → ABC (repeat)
2. Type characters on each layout intermittently
3. Check for any visual glitches
4. Monitor for crashes or hangs
5. Check memory usage in Xcode Instruments (if possible)

**Expected Results:**
- No crashes or freezes
- No visual glitches or orphaned views
- Layout transitions remain smooth
- No performance degradation
- No memory leaks (views properly cleaned up)

**Status:** [ ] Pass [ ] Fail

**Notes:**
_____________________________________________

---

### Test 9: Layout Persistence
**Objective:** Verify layout state persists correctly

**Steps:**
1. Switch to number layout ("123")
2. Switch to another app (press Home)
3. Return to Notes and bring up keyboard
4. Verify keyboard returns to number layout (not letter)
5. Switch to symbol layout ("#+=" )
6. Type in Messages app
7. Verify keyboard maintains symbol layout

**Expected Results:**
- Layout state persists when switching apps
- Layout state persists when switching text fields
- Layout does NOT reset on field change (per AC 7)

**Status:** [ ] Pass [ ] Fail

**Notes:**
_____________________________________________

---

### Test 10: Edge Cases
**Objective:** Test unusual scenarios and edge cases

**Steps:**
1. Switch layouts while banner is displayed
2. Switch layouts during snippet analysis
3. Type 100+ characters switching layouts frequently
4. Test globe button on all layouts (switches to system keyboard)
5. Test in password field (should work but not trigger snippets)
6. Test with VoiceOver enabled (accessibility)

**Expected Results:**
- No crashes in edge cases
- Snippet buffer handles mixed layout input
- Password fields work correctly
- System keyboard switcher works on all layouts
- Keyboard remains stable during extended use

**Status:** [ ] Pass [ ] Fail

**Notes:**
_____________________________________________

---

## Summary

### Overall Results
- Total Tests: 10
- Passed: ___
- Failed: ___
- Blocked: ___

### Critical Issues Found
_____________________________________________
_____________________________________________

### Minor Issues Found
_____________________________________________
_____________________________________________

### Acceptance Criteria Validation

| AC # | Requirement | Status | Notes |
|------|-------------|--------|-------|
| 1 | "123" button switches to number/symbol layout | [ ] Pass [ ] Fail | |
| 2 | Number layout displays correct keys | [ ] Pass [ ] Fail | |
| 3 | "#+=" button switches to extended symbols | [ ] Pass [ ] Fail | |
| 4 | Extended symbols layout shows correct keys | [ ] Pass [ ] Fail | |
| 5 | "ABC" button returns to letter layout | [ ] Pass [ ] Fail | |
| 6 | Shift key works appropriately | [ ] Pass [ ] Fail | N/A on number/symbol |
| 7 | Layout state persists during typing | [ ] Pass [ ] Fail | |
| 8 | All layouts maintain consistent visual style | [ ] Pass [ ] Fail | |
| 9 | Backspace, space, return work on all layouts | [ ] Pass [ ] Fail | |

### Recommendations
_____________________________________________
_____________________________________________

### Ready for Review?
[ ] Yes - All tests passed
[ ] No - Issues need fixing

---

**Tested By:** _____________
**Date:** _____________
**Device/Simulator:** _____________
**iOS Version:** _____________

