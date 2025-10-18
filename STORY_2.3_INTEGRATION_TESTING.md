# Story 2.3: Backend API Integration - Manual Testing Guide

## Status
✅ **Implementation Complete** - Tasks 1-8 finished  
⚠️ **Manual Testing Required** - Task 9 needs user verification

## What Was Implemented

### New Components Created
1. **Session Management** (`SessionManager.swift`)
   - Generates and persists anonymous UUID session IDs
   - Uses App Group UserDefaults for cross-launch persistence
   
2. **Network Client** (`NetworkClient.swift`)
   - Protocol-based HTTP client with 2.5s timeout
   - Comprehensive error handling (timeout, network, HTTP status codes)
   
3. **Data Models** (`AnalyzeTextModels.swift`)
   - `AnalyzeTextRequest` and `AnalyzeTextResponse` structs
   - Codable for JSON serialization
   
4. **API Service** (`APIService.swift`)
   - High-level API wrapper for backend communication
   - Dispatches callbacks on main thread
   - Graceful error handling with logging
   
5. **Keyboard Integration** (`KeyboardViewController.swift`)
   - Integrated API calls when snippet triggers fire
   - Non-blocking async execution
   - Silent failure strategy (no user disruption)

### Unit Tests Created
- **SessionManagerTests**: 10 tests
- **NetworkClientTests**: 12 tests with MockURLProtocol
- **APIServiceTests**: 11 tests with mocked dependencies

**Total Code Written**: ~1,290 lines (implementation + tests)

---

## Manual Testing Checklist

### Prerequisites

Before testing, you need to:

1. ✅ **Add new files to Xcode project**
   - Open `TypeSafe.xcodeproj` in Xcode
   - Right-click on `TypeSafeKeyboard` group → Add Files
   - Select all files in `TypeSafeKeyboard/Networking/` and `TypeSafeKeyboard/Models/`
   - Right-click on `TypeSafeTests` group → Add Files
   - Select all test files in `TypeSafeTests/`
   
2. ✅ **Configure Backend URL**
   - Open `TypeSafeKeyboard/Networking/APIService.swift`
   - Line 33: Change `baseURL` from placeholder to actual backend URL
   - For local testing: `"http://localhost:8000"`
   - For deployed backend: Use your actual backend URL

3. ✅ **Ensure Backend is Running**
   - Backend must be deployed and accessible (Story 1.6)
   - Test backend is responding: `curl http://localhost:8000/health`

4. ✅ **Enable Full Access**
   - Install keyboard on device/simulator
   - Go to Settings → General → Keyboard → Keyboards → TypeSafe Keyboard
   - Enable "Allow Full Access" (required for network calls)

---

### Test Scenarios

#### Test 1: Basic API Call
**Objective**: Verify keyboard sends API requests and receives responses

**Steps**:
1. Open Notes app or any text field
2. Switch to TypeSafe keyboard
3. Type: "Hello world test message"
4. Wait for space or punctuation to trigger snippet analysis

**Expected**:
- Xcode console shows:
  ```
  KeyboardViewController: Analysis triggered!
  APIService: Sending request to [your-backend-url]/analyze-text
  APIService: Received response
    - Risk level: [low/medium/high]
    - Confidence: [0.0-1.0]
  ```

**Pass Criteria**: ✅ API request logged, response received with all fields

---

#### Test 2: Session Persistence
**Objective**: Verify session ID persists across keyboard dismissals

**Steps**:
1. Type text to trigger API call, note the `session_id` in logs
2. Dismiss keyboard (switch apps or close keyboard)
3. Reopen keyboard and type again
4. Check `session_id` in new logs

**Expected**:
- Both API calls use the **same** `session_id`

**Pass Criteria**: ✅ Session ID remains consistent across keyboard sessions

---

#### Test 3: Timeout Handling
**Objective**: Verify 2.5s timeout works without crashing

**Steps**:
1. Modify backend to delay response by 3 seconds (or use network throttling)
2. Type text to trigger API call
3. Wait and observe

**Expected**:
- Console shows: `NetworkClient: Request timed out after 2.5s`
- Keyboard continues functioning normally (no crash)

**Pass Criteria**: ✅ Timeout after 2.5s, keyboard remains functional

---

#### Test 4: Network Error Handling
**Objective**: Verify graceful failure when network unavailable

**Steps**:
1. Enable Airplane Mode or disable WiFi
2. Type text to trigger API call

**Expected**:
- Console shows: `NetworkClient: Network error: [error description]`
- **No error alert shown to user**
- Keyboard continues functioning normally

**Pass Criteria**: ✅ Silent failure, no user disruption, keyboard works

---

#### Test 5: Secure Field Protection
**Objective**: Verify NO API calls made in password fields

**Steps**:
1. Open Safari or any app with password field
2. Tap into a password field (should show as secure with dots)
3. Type text using TypeSafe keyboard

**Expected**:
- Console shows: **NO** "Analysis triggered!" messages
- **NO** API calls made (privacy maintained)

**Pass Criteria**: ✅ No API calls in secure fields

---

#### Test 6: High-Volume Typing
**Objective**: Verify keyboard handles multiple rapid API calls

**Steps**:
1. Type rapidly for 500+ characters
2. Observe console logs and keyboard responsiveness

**Expected**:
- Multiple API calls triggered (every 50 chars or on punctuation)
- Keyboard remains responsive (no lag or freezing)
- No memory warnings in Xcode

**Pass Criteria**: ✅ Multiple API calls handled smoothly, no performance degradation

---

#### Test 7: Response Parsing
**Objective**: Verify all response fields parsed correctly

**Steps**:
1. Send different text snippets that trigger different risk levels
2. Check console logs for parsed response

**Expected**:
- All fields present in logs:
  - `risk_level`: "low" | "medium" | "high"
  - `confidence`: 0.0 to 1.0
  - `category`: string
  - `explanation`: string

**Pass Criteria**: ✅ All response fields parsed and logged correctly

---

## Known Limitations (Expected in MVP)

- ❌ **No user-facing UI for results** (Story 2.4 will add banner display)
- ❌ **App bundle ID is "unknown"** (Future story will detect actual app)
- ❌ **Backend URL is hardcoded** (Future story will make configurable)
- ❌ **No API key authentication yet** (Future story)
- ❌ **No Full Access permission prompt** (Future story will add messaging)

---

## Troubleshooting

### Issue: No API calls appearing in logs
**Solution**:
- Verify Full Access is enabled in iOS Settings
- Check backend URL is correct in `APIService.swift`
- Ensure backend is running and accessible

### Issue: "Invalid URL" error
**Solution**:
- Verify backend URL format is correct (must include http:// or https://)
- Check for typos in URL

### Issue: Timeout errors constantly
**Solution**:
- Check backend is responding within 2s
- Test backend directly: `curl [backend-url]/analyze-text`
- Ensure network connection is stable

### Issue: Files not found in Xcode
**Solution**:
- New Swift files must be manually added to Xcode project
- Follow "Add new files to Xcode project" in Prerequisites section

---

## Next Steps After Testing

Once manual testing is complete:

1. ✅ Mark Task 9 as complete in story file
2. ✅ Update story status to "Done"
3. ➡️ Proceed to **Story 2.4**: Risk Banner Display (UI implementation)

---

## Summary

**Implementation Status**: ✅ Complete (Tasks 1-8)  
**Testing Status**: ⏳ Awaiting manual verification (Task 9)  
**Lines of Code**: 1,290 lines (implementation + comprehensive tests)  
**Test Coverage**: 33 unit tests covering all core functionality

The networking infrastructure is fully implemented with protocol-based design for testability, comprehensive error handling, and async execution. Manual testing is required to verify end-to-end integration with the live backend.

