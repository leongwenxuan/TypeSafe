# User Country Detection for Foreign Number Scam Detection

## Feature Implemented ✅

Automatically detect user's country and flag **foreign phone numbers** as **HIGH RISK** scams!

## How It Works

```
1. iOS detects user's locale automatically (e.g., "US", "SG", "GB")
2. Stores in app settings
3. Shares with keyboard via App Group
4. Keyboard sends country code with every screenshot scan
5. Backend (Gemini AI) analyzes phone numbers:
   - Local number → Normal analysis
   - Foreign number → HIGH RISK! ⚠️
```

## Files Modified

### iOS App:
1. ✅ `AppSettings.swift` - Added `userCountryCode` property
2. ✅ `KeyboardAPIService.swift` - Reads country from settings, sends to backend

### Backend:
3. ✅ `main.py` - Accepts `user_country` parameter  
4. ✅ `gemini_service.py` - Uses country in AI prompt for phone number analysis

## What Gets Sent to Backend

### Before:
```
POST /scan-image
- session_id: "..."
- ocr_text: "+44 123 456 789 Click here!"
- image: [JPEG data]
```

### After:
```
POST /scan-image
- session_id: "..."
- ocr_text: "+44 123 456 789 Click here!"
- image: [JPEG data]
- user_country: "SG"  ← NEW!
```

## AI Prompt Enhancement

The AI now receives this context:

```
IMPORTANT: User is from SG. If you detect phone numbers from 
DIFFERENT countries in the text/image, this is HIGHLY SUSPICIOUS 
and should be marked as HIGH RISK (scammers often use foreign numbers). 
Local numbers from SG are acceptable.
```

## Example Scenarios

### Scenario 1: User in Singapore, sees UK number
```
User country: SG
Screenshot contains: "+44 7700 900123"
AI Decision: HIGH RISK ⚠️
Reason: Foreign number (UK +44) calling Singapore user
```

### Scenario 2: User in US, sees US number
```
User country: US
Screenshot contains: "+1 (555) 123-4567"
AI Decision: Normal analysis (not auto-flagged)
Reason: Local number matches user country
```

### Scenario 3: User in UK, sees Nigeria number
```
User country: GB
Screenshot contains: "+234 123 456 7890"
AI Decision: HIGH RISK ⚠️
Reason: Foreign number (Nigeria +234) calling UK user
```

## How Country is Detected

```swift
// Automatic detection from iOS:
Locale.current.region?.identifier  // Returns "US", "SG", "GB", etc.
```

### Supported Country Codes:
- All ISO 3166-1 alpha-2 codes
- Examples: US, GB, SG, AU, CA, IN, MY, PH, etc.

### Fallback:
If detection fails → defaults to "US"

## Testing

### Test 1: Verify Country Detection
```
1. Open TypeSafe app
2. Check Console.app
3. Look for: "User country: [YOUR_COUNTRY]"
```

### Test 2: Foreign Number Screenshot
```
1. Screenshot a message with foreign number
   Example: "+44 123 456" (if you're not in UK)
2. Wait 5-10 seconds
3. Should see: ⚠️ HIGH RISK banner
```

### Test 3: Local Number Screenshot
```
1. Screenshot a message with local number
2. Should get normal risk analysis (not auto-flagged)
```

## Backend Logs

Watch for:
```
scan_image: session_id=... user_country=SG request_id=...
Gemini analysis succeeded: risk_level=high request_id=...
```

## User Privacy

**What's collected:**
- Country code only (e.g., "SG")

**What's NOT collected:**
- Exact location
- GPS coordinates
- City/address
- Phone number
- Personal identifiable information

**Why it's safe:**
- ISO country code is not PII
- Improves scam detection accuracy
- Stored locally, only sent during analysis
- Helps protect users from foreign scam calls

## Settings (Future Enhancement)

Could add to Settings page:
```
[ ] Detect foreign numbers as scams
    Your country: Singapore (SG)
    [Change Country]
```

Currently it's automatic!

## Summary

✅ **Automatic country detection** - No user input needed  
✅ **Foreign number flagging** - AI knows what's suspicious  
✅ **Privacy-safe** - Only country code, no PII  
✅ **Improved accuracy** - Context-aware scam detection  

**Now foreign scammers will be caught!** 🎯

