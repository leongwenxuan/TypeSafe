# Diagnostic Fixes Applied

## Issues Fixed

### ✅ Issue 1: Better Error Logging
Added comprehensive logging to identify why backend isn't being called.

### ✅ Issue 2: Backend URL Check
Added validation to detect if you're still using the placeholder URL.

### ✅ Issue 3: Banner Position Fixed
Banner now appears **ABOVE** the keyboard, not covering it!

---

## How to Fix "Unable to analyze" Error

### Step 1: Update Backend URL ⚠️ CRITICAL

**File:** `TypeSafeKeyboard/KeyboardAPIService.swift` line 22

**Change this:**
```swift
private let baseURL = "https://your-backend-url.com"
```

**To your actual backend:**
```swift
private let baseURL = "https://api.yourapp.com"  // Your real backend!
```

Or if testing locally:
```swift
private let baseURL = "http://192.168.1.100:5000"  // Your Mac's IP address
```

**Important:** 
- Don't use `localhost` or `127.0.0.1` (won't work from iPhone to Mac)
- Use your Mac's actual IP address for local testing
- Get your Mac's IP: System Settings → Network → WiFi → Details

### Step 2: Rebuild & Test

After updating the URL:
```
1. Cmd+B to rebuild
2. Run on device
3. Take a screenshot
4. Watch Console.app logs
```

---

## Check Console Logs

Open **Console.app** → Select your iPhone → Filter: `TypeSafeKeyboard`

### If you see this:
```
🔴 ERROR: Backend URL is still placeholder!
   Please update baseURL in KeyboardAPIService.swift
```
→ **You forgot to update the URL!** Go to Step 1 above.

### If you see this:
```
🟡 KeyboardAPIService: Sending to backend API...
   Backend URL: https://your-backend-url.com
   Endpoint: https://your-backend-url.com/scan-image
🔴 ERROR: Backend URL is still placeholder!
```
→ **Update the baseURL in KeyboardAPIService.swift**

### If you see this:
```
🟡 KeyboardAPIService: Sending to backend API...
   Backend URL: https://api.yourapp.com
   Endpoint: https://api.yourapp.com/scan-image
   OCR Text: Click here to verify your account...
🟢 KeyboardAPIService: Image converted to base64 (45823 chars)
🟢 KeyboardAPIService: URL created successfully
🔴 KeyboardAPIService: Network error - [error details]
```
→ **Backend is unreachable**
- Check backend is running
- Check URL is correct
- Check iPhone can reach backend (same WiFi network for local)

### If you see this:
```
🟢 KeyboardAPIService: Success! Risk: high, Confidence: 0.92
🟢 KeyboardViewController: API SUCCESS!
🟢 KeyboardViewController: Showing result banner
```
→ **Everything works!** ✅

---

## Banner Position

### Before (Covering keyboard):
```
┌─────────────────┐
│   [Banner]      │ ← Covering keys!
│  Q W E R T Y    │
│   A S D F G H   │
└─────────────────┘
```

### After (Above keyboard):
```
┌─────────────────┐
│   [Banner]      │ ← Floating above!
├─────────────────┤
│  Q W E R T Y    │
│   A S D F G H   │
└─────────────────┘
```

The banner now appears **above** the keyboard, not blocking any keys!

---

## Testing Checklist

### ✅ Step 1: Update Backend URL
```
File: TypeSafeKeyboard/KeyboardAPIService.swift
Line: 22
Action: Change "your-backend-url.com" to your real backend
```

### ✅ Step 2: Verify Backend Running
```
# Test with curl (replace with your URL):
curl -X POST https://your-backend.com/scan-image \
  -H "Content-Type: application/json" \
  -d '{"ocrText":"test","image":"","sessionId":"test"}'

# Should return JSON with risk_level, confidence, etc.
```

### ✅ Step 3: Build & Run
```
1. Cmd+B
2. Run on device
3. Open Console.app
```

### ✅ Step 4: Take Screenshot
```
1. Open Messages
2. Switch to TypeSafe keyboard
3. Take screenshot (Volume Up + Power)
4. Watch Console.app logs
```

### ✅ Step 5: Verify Banner Position
```
Banner should appear:
- ABOVE the keyboard
- Not covering any keys
- Easy to tap dismiss (X)
- Auto-dismisses after 10 seconds
```

---

## Local Backend Testing

If testing with a backend on your Mac:

### 1. Find Your Mac's IP Address
```
System Settings → Network → WiFi → Details
Look for "IP Address": 192.168.1.XXX
```

### 2. Update KeyboardAPIService.swift
```swift
private let baseURL = "http://192.168.1.XXX:5000"  // Your Mac's IP
```

### 3. Make Sure Backend Accepts External Connections
```python
# Python Flask example:
app.run(host='0.0.0.0', port=5000)  # Not just localhost!
```

### 4. Make Sure iPhone on Same WiFi
```
iPhone Settings → WiFi → Same network as Mac
```

---

## Expected Backend API

Your backend must respond to:

**Endpoint:** `POST /scan-image`

**Request:**
```json
{
  "ocrText": "extracted text from screenshot",
  "image": "base64_encoded_jpeg_data",
  "sessionId": "uuid-string"
}
```

**Response (SUCCESS - 200 OK):**
```json
{
  "risk_level": "high",
  "confidence": 0.92,
  "category": "Phishing",
  "explanation": "Contains suspicious verification link"
}
```

**Valid risk_level values:** `"high"`, `"medium"`, `"low"`

---

## Common Errors & Solutions

### Error: "Unable to analyze screenshot"

**Cause 1:** Backend URL still placeholder
→ Update `baseURL` in `KeyboardAPIService.swift`

**Cause 2:** Backend not running
→ Start your backend server

**Cause 3:** iPhone can't reach backend
→ Check WiFi connection
→ Use Mac's IP address, not localhost

**Cause 4:** Backend returns wrong format
→ Check response has `risk_level`, `confidence`, `category`, `explanation`

### Error: Banner covering keyboard

**Fixed!** ✅ Banner now positioned above keyboard.

If still covering:
1. Rebuild app (Cmd+B)
2. Delete app from iPhone
3. Reinstall

---

## Summary of Changes

### Files Modified:
1. ✅ `KeyboardAPIService.swift` - Better logging + URL validation
2. ✅ `KeyboardViewController.swift` - Banner position fixed

### What to Do:
1. Update backend URL in `KeyboardAPIService.swift` line 22
2. Rebuild and run
3. Watch Console.app logs
4. Should work! 🎉

---

## Still Not Working?

Share these logs from Console.app:
1. All lines starting with `🔴` (errors)
2. The section showing backend URL
3. Any network error details

This will help diagnose the exact issue!

